# Firebase Functions

This workspace hosts the backend automation for the Restaurant App POS. In
addition to installing the Node dependencies (`npm ci`), a handful of runtime
secrets and environment variables must be configured before deploying to a real
Firebase project.

## 1. Install dependencies

```bash
npm --prefix functions ci
```

## 2. Create an environment file

Copy the provided template and fill in the values for your environment. Secrets
(such as API keys) should never be committed to version control.

```bash
cp functions/.env.example functions/.env
# Edit functions/.env to add project specific values
```

The template documents every variable that `process.env` expects. Required
values include:

- `SENDGRID_API_KEY` – SendGrid credential used by transactional emails
- `SYNTHETIC_MONITOR_TARGET` – URL probed by the synthetic monitor cron job
- Optional `SYNTHETIC_MONITOR_BEARER_TOKEN` if the endpoint requires auth
- Storage/BQ identifiers (`BACKUP_BUCKET`, `BIGQUERY_*`, `BUILD_METRICS_*`)

## 3. Load variables locally

The Firebase emulator reads environment variables from the current shell. Source
the `.env` file before running the emulator or Vitest suite:

```bash
export $(grep -v '^#' functions/.env | xargs)
npm --prefix functions run serve
```

On macOS you may need to replace `export $(...)` with `set -a; source
functions/.env; set +a` to ensure variables with spaces are loaded correctly.

## 4. Store secrets in Firebase

Firebase Functions (2nd gen) supports both plain environment variables and
Secret Manager entries. We recommend pushing non-sensitive values with the
`--env-vars-file` flag and storing sensitive credentials as secrets.

```bash
# Push non-sensitive values (bucket names, dataset IDs, schedules)
firebase deploy \
  --only functions \
  --project <project-id> \
  --env-vars-file functions/.env \
  --config firebase.json
```

For secrets like `SENDGRID_API_KEY` and `SYNTHETIC_MONITOR_BEARER_TOKEN` use the
Secret Manager integration. The template comments mark these entries.

```bash
firebase functions:secrets:set SENDGRID_API_KEY --project <project-id> < <( \
  grep '^SENDGRID_API_KEY=' functions/.env | cut -d'=' -f2-
)

firebase functions:secrets:set SYNTHETIC_MONITOR_BEARER_TOKEN --project <project-id> < <( \
  grep '^SYNTHETIC_MONITOR_BEARER_TOKEN=' functions/.env | cut -d'=' -f2-
)
```

Secrets can be audited with `firebase functions:secrets:list` and rotated by
running the same command with a new value. The next deployment automatically
links the latest secret version to every function.

## 5. Verify deployment

After deploying, inspect the configuration from the Firebase console or with
`firebase functions:config:get`. Scheduled monitors and email delivery will fail
fast with descriptive logs if required secrets are missing.
