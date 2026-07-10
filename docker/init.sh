#!/bin/bash
set -e

SITE_NAME="lms.localhost"
DEFAULT_LMS_APP_NAME="Pa's Academy"
LMS_APP_NAME="${LMS_APP_NAME:-$DEFAULT_LMS_APP_NAME}"

ensure_app_in_apps_txt() {
    local app="$1"
    if [ -f "sites/apps.txt" ]; then
        sed -i 's/paymentslms/payments\nlms/g' sites/apps.txt
    fi
    if ! grep -qx "$app" sites/apps.txt; then
        if [ -s "sites/apps.txt" ] && [ -n "$(tail -c 1 sites/apps.txt)" ]; then
            printf "\n" >> sites/apps.txt
        fi
        printf "%s\n" "$app" >> sites/apps.txt
    fi
}

ensure_payments_app() {
    if [ ! -d "apps/payments" ]; then
        bench get-app payments
    fi
    ensure_app_in_apps_txt payments
}

ensure_lms_app() {
    if [ -d "apps/lms" ]; then
        ensure_app_in_apps_txt lms
        return
    fi

    if [ -f /workspace/pyproject.toml ] && [ -d /workspace/lms ]; then
        ln -s /workspace apps/lms
        ./env/bin/pip install -e /workspace
        ensure_app_in_apps_txt lms
    else
        bench get-app lms
    fi
}

ensure_lms_assets_link() {
    local target=""

    if [ -d "apps/lms/lms/public" ]; then
        target="$(readlink -f apps/lms/lms/public)"
    elif [ -d "/workspace/lms/public" ]; then
        target="/workspace/lms/public"
    fi

    if [ -z "$target" ]; then
        return
    fi

    mkdir -p sites/assets

    if [ -L "sites/assets/lms" ]; then
        if [ "$(readlink -f sites/assets/lms)" != "$target" ]; then
            rm sites/assets/lms
            ln -s "$target" sites/assets/lms
        fi
    elif [ ! -e "sites/assets/lms" ]; then
        ln -s "$target" sites/assets/lms
    fi
}

set_private_lms_config() {
    bench --site "$SITE_NAME" set-config developer_mode 1
    bench --site "$SITE_NAME" set-config private_lms 1
    bench --site "$SITE_NAME" set-config lms_app_name "$LMS_APP_NAME"
    bench --site "$SITE_NAME" set-config allow_guest_access 0
    bench --site "$SITE_NAME" set-config disable_signup 1
    bench --site "$SITE_NAME" set-config website_signup_disabled 1
    bench --site "$SITE_NAME" set-config lms_invite_expiry_days 7
    bench --site "$SITE_NAME" clear-cache
}

install_app_if_missing() {
    local app="$1"
    if ! bench --site "$SITE_NAME" list-apps | grep -qx "$app"; then
        bench --site "$SITE_NAME" install-app "$app"
    fi
}

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, ensuring apps and config"
    cd frappe-bench
    ensure_payments_app
    ensure_lms_app
    if [ ! -d "sites/$SITE_NAME" ]; then
        bench new-site "$SITE_NAME" \
        --force \
        --mariadb-root-password 123 \
        --admin-password admin \
        --no-mariadb-socket
    fi
    install_app_if_missing payments
    install_app_if_missing lms
    ensure_lms_assets_link
    bench --site "$SITE_NAME" migrate
    ensure_lms_assets_link
    set_private_lms_config
    bench use "$SITE_NAME"
    bench start
    exit 0
else
    echo "Creating new bench..."
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

ensure_payments_app
ensure_lms_app

bench new-site "$SITE_NAME" \
--force \
--mariadb-root-password 123 \
--admin-password admin \
--no-mariadb-socket

install_app_if_missing payments
install_app_if_missing lms
ensure_lms_assets_link
set_private_lms_config
bench use "$SITE_NAME"

bench start
