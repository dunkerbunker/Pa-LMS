#!/usr/bin/env bash
# Stop the local production-like stack while preserving its local data volumes.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$DOCKER_DIR/.." && pwd)"
docker compose \
	--env-file "$DOCKER_DIR/.env.local" \
	-f "$DOCKER_DIR/docker-compose.production.yml" \
	--project-directory "$REPO_DIR" \
	down
