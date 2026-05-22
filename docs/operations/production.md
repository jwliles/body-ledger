# Production Operations

Body Ledger is developed and committed from the local PC. The DigitalOcean
droplet is a deployment target only.

## Source Control Boundary

- Do Git history cleanup, commits, and GitHub pushes on the PC clone.
- Do not use the droplet for repository history cleanup.
- Do not commit server-local secrets, Cloudflare notes, Rails credentials keys,
  `.env.production`, or generated OTP QR files.
- `cloudflare.txt` is ignored and should remain local-only.

If a secret file is committed, purge it from history on the PC clone and rotate
the exposed secret:

```sh
git filter-repo --force --path cloudflare.txt --invert-paths
git push --force-with-lease origin main
```

## Rails API Environment

The production API needs the same database password in every execution context:
manual Rails commands, rake tasks, and the long-running API service. Keep it in a
root-only env file on the droplet:

```sh
cd /root/body-ledger/server/health_tracker_api
install -m 600 /dev/null .env.production
```

Example `.env.production` shape:

```sh
RAILS_ENV='production'
HEALTH_TRACKER_API_DATABASE_PASSWORD='replace-with-production-db-password'
ALLOWED_ORIGINS='https://bodyledger.org,http://bodyledger.org'
```

Before one-off Rails commands:

```sh
set -a
source .env.production
set +a
```

Check DB connectivity without printing the password:

```sh
PGPASSWORD="$HEALTH_TRACKER_API_DATABASE_PASSWORD" \
psql -h 127.0.0.1 -U health_tracker_api -d health_tracker_api_production \
-c 'select current_user, current_database();'
```

## API Service

The API should run under systemd and source `.env.production`. Avoid loose
manual Ruby/Puma processes because they can keep stale environment variables.

Expected service shape:

```ini
[Unit]
Description=Body Ledger API (Rails)
After=network.target postgresql.service

[Service]
Type=simple
WorkingDirectory=/root/body-ledger/server/health_tracker_api
EnvironmentFile=/root/body-ledger/server/health_tracker_api/.env.production
Environment=RAILS_LOG_TO_STDOUT=1
Environment=RAILS_SERVE_STATIC_FILES=1
ExecStart=/root/.rbenv/shims/bundle exec rails server -b 127.0.0.1 -p 3000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Common checks:

```sh
systemctl status bodyledger-api --no-pager
journalctl -u bodyledger-api -n 80 --no-pager
curl -i -H 'Host: api.bodyledger.org' http://127.0.0.1:3000/up
curl -i https://api.bodyledger.org/up
```

If Rails reports pending migrations:

```sh
cd /root/body-ledger/server/health_tracker_api
set -a
source .env.production
set +a
bin/rails db:migrate
systemctl restart bodyledger-api
```

## Web Service

The public UI is `https://bodyledger.org`. Client-side API configuration is
baked into the Next.js build, so build with:

```sh
cd /root/body-ledger/web
NEXT_PUBLIC_API_URL=https://api.bodyledger.org npm run build
systemctl restart bodyledger-web
```

CORS should allow the UI origin:

```sh
curl -i https://api.bodyledger.org/api/v1/reports \
  -H 'Origin: https://bodyledger.org'
```

An unauthenticated protected route returning `401` with
`access-control-allow-origin: https://bodyledger.org` means the API and CORS are
reachable; the browser then needs a valid device token from login.
