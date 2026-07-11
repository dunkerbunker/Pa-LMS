#!/usr/bin/env bash
# Roll back application containers only. Database migrations are never reversed
# automatically because schema/data rollback needs a release-specific plan.
set -Eeuo pipefail

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <previous-app-image-tag>" >&2
	exit 64
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$DOCKER_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$DOCKER_DIR/.env.production}"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$DOCKER_DIR/docker-compose.production.yml" --project-directory "$REPO_DIR")

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }

"${COMPOSE[@]}" run --rm -e SITE_OPERATION=maintenance-on site-ops
APP_IMAGE_TAG="$1" "${COMPOSE[@]}" up -d --force-recreate backend websocket queue-short queue-long scheduler frontend caddy
"${COMPOSE[@]}" run --rm -e SITE_OPERATION=maintenance-off site-ops
echo "Application containers rolled back to tag $1. Verify database compatibility before resuming writes."
