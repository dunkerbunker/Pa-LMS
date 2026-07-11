#!/bin/sh
set -eu

if [ "${BACKUPS_ENABLED:-false}" != "true" ]; then
	echo "Backups are disabled (BACKUPS_ENABLED is not true); nothing uploaded."
	exit 0
fi

for variable in DO_SPACES_ENDPOINT DO_SPACES_BUCKET AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY SITE_NAME; do
	eval "value=\${$variable:-}"
	if [ -z "$value" ]; then
		echo "$variable is required when backups are enabled." >&2
		exit 1
	fi
done

aws s3 sync \
	"/sites/${SITE_NAME}/private/backups" \
	"s3://${DO_SPACES_BUCKET}/${SITE_NAME}/" \
	--endpoint-url "$DO_SPACES_ENDPOINT" \
	--only-show-errors
