#!/usr/bin/env bash
# Deploy a new application image with controlled write downtime for migrations.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$DOCKER_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$DOCKER_DIR/.env.production}"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$DOCKER_DIR/docker-compose.production.yml" --project-directory "$REPO_DIR")

if [ ! -f "$ENV_FILE" ]; then
	echo "Missing $ENV_FILE. Copy docker/.env.production.example first." >&2
	exit 1
fi

run_ops() {
	"${COMPOSE[@]}" run --rm -e "SITE_OPERATION=$1" site-ops
}

cleanup() {
	status=$?
	if [ "$status" -ne 0 ]; then
		echo "Deployment failed. Maintenance mode is intentionally left on for safety." >&2
	fi
	exit "$status"
}
trap cleanup EXIT

# Every Frappe runtime service uses the same APP_IMAGE. Build it once through
# the backend target; building every service concurrently just exports the same
# image tag repeatedly and wastes deployment time. CI/CD can pre-build a pinned
# image and set SKIP_BUILD=true for a short maintenance window.
if [ "${SKIP_BUILD:-false}" != "true" ]; then
	"${COMPOSE[@]}" build --pull backend
fi
"${COMPOSE[@]}" up -d db redis-cache redis-queue configurator
run_ops bootstrap
run_ops configure
run_ops maintenance-on
# Site configuration is cached by already-running Frappe workers. Recreate the
# request-serving services before migrating so every process loads maintenance
# mode and cannot accept writes against a schema in transition.
"${COMPOSE[@]}" up -d --force-recreate backend websocket queue-short queue-long scheduler frontend caddy
run_ops migrate
"${COMPOSE[@]}" up -d --force-recreate backend websocket queue-short queue-long scheduler frontend caddy

# Maintenance mode deliberately returns 503. Re-enable the site before checking
# the public request path, then put it back into maintenance if that check fails.
run_ops maintenance-off

# Check the public request path through Caddy rather than reaching the backend.
# Frappe can cache site configuration briefly after maintenance mode changes, so
# the 60-second retry window is intentional.
source "$ENV_FILE"
healthcheck_url="${HEALTHCHECK_URL:-http://127.0.0.1:${HEALTHCHECK_PORT:-${HTTP_PORT:-80}}/api/method/ping}"
for attempt in $(seq 1 30); do
	if curl --fail --silent --show-error "$healthcheck_url" >/dev/null; then
		trap - EXIT
		echo "Deployment succeeded."
		exit 0
	fi
	sleep 2
done

run_ops maintenance-on
echo "Proxy health check failed; maintenance mode was restored." >&2
exit 1
