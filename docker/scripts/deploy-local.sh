#!/usr/bin/env bash
# Run the same pinned-image, migration, and health-check deployment flow locally.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export ENV_FILE="$SCRIPT_DIR/../.env.local"
exec "$SCRIPT_DIR/deploy.sh"
