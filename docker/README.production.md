# Production deployment

`docker-compose.yml` remains a development-only environment. Production uses
`docker-compose.production.yml`, which runs Frappe web, websocket, scheduler,
workers, Redis, MariaDB, and a Caddy TLS proxy as separate containers.

## First deployment

1. Copy `.env.production.example` to `.env.production`; set a real domain,
   `PUBLIC_URL`, `LMS_PATH`, and strong credentials. Do not commit that file.
   `LMS_PATH` is the public LMS route without slashes (for example `apps/pa`
   for `https://your-domain.example/apps/pa`). It must match the reverse-proxy
   path.
2. Point DNS A/AAAA records at the server and allow inbound ports 80 and 443.
   Caddy obtains and renews the TLS certificate automatically.
3. Run `bash docker/scripts/deploy.sh` on a Linux server with Docker Compose v2.
   It builds the current repository into an app image, creates a site only when
   the persistent `sites` volume is empty, enables maintenance mode, migrates,
   recreates app services, verifies the proxied ping endpoint, then re-enables
   writes.

Named volumes preserve MariaDB (`mariadb-data`), Frappe site configuration and
uploads (`sites`), logs, Redis queue state, and Caddy certificates across normal
container replacement. Never run `docker compose down --volumes` in production.

## Updates and rollback

Set `APP_IMAGE_TAG` to an immutable release value (normally the Git commit SHA)
for each deploy. Keep prior tags locally or in a private registry. Run the deploy
script for every backend, frontend, or schema change.

`bash docker/scripts/rollback.sh <previous-tag>` rolls back app containers only.
It deliberately does not reverse database migrations or data changes; those need
a release-specific recovery plan or a tested database restore.

## DigitalOcean Spaces backups (prepared but disabled)

`BACKUPS_ENABLED=false` prevents backup creation and upload. When ready:

1. Create a private Spaces bucket and least-privilege access key.
2. Set `DO_SPACES_*` in `.env.production` and set `BACKUPS_ENABLED=true`.
3. Add a bucket lifecycle retention policy.
4. Schedule `bash docker/scripts/backup.sh` daily with a systemd timer or cron.
5. Restore into a separate environment and verify it regularly.

Until this is enabled, named volumes protect normal container recreation but not
server or disk loss.

## Local production smoke test

For a local production-like environment, copy `.env.local.example` to
`.env.local`. It uses the same pinned image and dependency revisions as
production, but its own `lms-local_*` volumes and port 8080. Its key values are:

```dotenv
SITE_NAME=lms.localhost
PUBLIC_URL=http://localhost:8080
LMS_PATH=lms
CADDY_SITE_ADDRESS=:80
HTTP_PORT=8080
HTTPS_PORT=8443
```

Then deploy and run:

```bash
./docker/scripts/deploy-local.sh
CYPRESS_baseUrl=http://localhost:8080 CYPRESS_adminPassword=admin npx cypress run --browser electron --spec cypress/e2e/production_smoke.cy.js
```

For a site behind a path prefix, pass the same `LMS_PATH` to Cypress and the
public login path. For example: `CYPRESS_lmsPath=apps/pa
CYPRESS_loginPath=apps/pa/login`.

Stop it without deleting local data:

```bash
./docker/scripts/down-local.sh
```

To deliberately reset only this local production-like database and file store:

```bash
docker compose --env-file docker/.env.local -f docker/docker-compose.production.yml --project-directory . down --volumes
```

The full Cypress suite expects test/demo data (including `frappe@example.com`).
Create that data in the isolated local test site before treating it as a release
gate.
