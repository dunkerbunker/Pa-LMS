#!/usr/bin/env bash
set -Eeuo pipefail

: "${SITE_NAME:?SITE_NAME is required}"

site_exists() {
	test -f "sites/${SITE_NAME}/site_config.json"
}

case "${SITE_OPERATION:-help}" in
	bootstrap)
		if site_exists; then
			echo "Site ${SITE_NAME} already exists; bootstrap skipped."
			exit 0
		fi

		: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is required}"
		: "${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"
		bench new-site "$SITE_NAME" \
			--mariadb-root-password "$MARIADB_ROOT_PASSWORD" \
			--admin-password "$ADMIN_PASSWORD" \
			--db-host db \
			--db-port 3306 \
			--no-mariadb-socket \
			--install-app lms \
			--set-default
		bench --site "$SITE_NAME" set-config developer_mode 0
		bench --site "$SITE_NAME" set-config host_name "${PUBLIC_URL:?PUBLIC_URL is required}"
		bench --site "$SITE_NAME" set-config maintenance_mode 0
		;;
	maintenance-on)
		site_exists || { echo "Site ${SITE_NAME} does not exist." >&2; exit 1; }
		bench --site "$SITE_NAME" set-maintenance-mode on
		;;
	migrate)
		site_exists || { echo "Site ${SITE_NAME} does not exist." >&2; exit 1; }
		# On failure, leave the site in maintenance mode for manual verification.
		bench --site "$SITE_NAME" migrate
		bench --site "$SITE_NAME" clear-cache
		bench --site "$SITE_NAME" clear-website-cache
		;;
	maintenance-off)
		site_exists || { echo "Site ${SITE_NAME} does not exist." >&2; exit 1; }
		bench --site "$SITE_NAME" set-maintenance-mode off
		;;
	backup)
		site_exists || { echo "Site ${SITE_NAME} does not exist." >&2; exit 1; }
		bench --site "$SITE_NAME" backup --with-files
		;;
	*)
		echo "Usage: SITE_OPERATION={bootstrap|maintenance-on|migrate|maintenance-off|backup}" >&2
		exit 64
		;;
esac
