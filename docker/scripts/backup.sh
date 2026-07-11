#!/usr/bin/env bash
# Safe to schedule now: exits successfully until BACKUPS_ENABLED=true.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$DOCKER_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$DOCKER_DIR/.env.production}"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$DOCKER_DIR/docker-compose.production.yml" --project-directory "$REPO_DIR")

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"
if [ "${BACKUPS_ENABLED:-false}" != "true" ]; then
	echo "Backups are disabled. Set BACKUPS_ENABLED=true only after Spaces credentials and lifecycle policy are configured."
	exit 0
fi

"${COMPOSE[@]}" run --rm -e SITE_OPERATION=backup site-ops
"${COMPOSE[@]}" run --rm backup-uploader
