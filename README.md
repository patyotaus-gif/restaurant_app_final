# restaurant_app_final

Restaurant App POS now ships with a modular plugin architecture and multi-level
feature flag system to tailor deployments per tenant, store and terminal.

## Plugin Architecture

Plugins represent optional modules (e.g. Kitchen Display or Loyalty) that can be
enabled or disabled on a per-store basis. The `PluginRegistry` registers all
available modules at start up and the `PluginProvider` keeps plugin state in
sync with Firestore.

- Configure plugins under **Admin → Stores & Branches**.
- Toggle individual modules per store. Changes persist immediately via the
  `pluginOverrides` map stored on each `stores/{storeId}` document.

## Feature Flags

Feature flags allow runtime activation of experiments or gradual rollouts across
three scopes:

1. **Tenant** – defaults for all stores.
2. **Store** – overrides for a specific store.
3. **Terminal** – the highest precedence overrides per device/terminal.

Flag data is stored in `featureFlags/{tenantId}` documents and streamed into the
app through `FeatureFlagProvider`. You can manage flags from the Stores admin
panel:

1. Select a store to inspect effective flags.
2. Optionally set a terminal identifier for the current device.
3. Choose a scope, flag key, and state to persist.

## Local Development

This is a Flutter project; follow the standard Flutter workflow for local
development:

```bash
flutter pub get
flutter run
```

For more Flutter resources see the [Flutter documentation](https://docs.flutter.dev/).

### Dev automation shortcuts

The repository ships with both a `Makefile` and `Taskfile.yml` so common flows are
one command away. Use whichever tool you prefer:

```bash
make setup   # flutter pub get, melos bootstrap, npm ci (functions/)
make qa      # analyze + Flutter tests + Cloud Functions Vitest suite
make watch   # launch the dev flavor in debug mode
make format-check

task setup   # same as make setup
task qa      # runs analyzer, Flutter tests, and Vitest
task format:check
```

Every command works from the repository root and keeps the Flutter app and
Firebase Functions in sync during local development.

## Environment Flavors

The application ships with dedicated **dev**, **stg**, and **prod** flavors on both Android and iOS. Each flavor has its own `google-services.json` / `GoogleService-Info.plist` placeholder and a Dart entry point under `lib/` so configuration stays isolated per backend environment.

### Quick commands

| Environment | Debug run | Android release build | iOS release build |
| --- | --- | --- | --- |
| Dev | `flutter run --flavor dev --target lib/main_dev.dart` | `flutter build apk --flavor dev --target lib/main_dev.dart` | `flutter build ipa --flavor dev --target lib/main_dev.dart` |
| Staging | `flutter run --flavor stg --target lib/main_stg.dart` | `flutter build apk --flavor stg --target lib/main_stg.dart` | `flutter build ipa --flavor stg --target lib/main_stg.dart` |
| Production | `flutter run --flavor prod --target lib/main_prod.dart` | `flutter build apk --flavor prod --target lib/main_prod.dart` | `flutter build ipa --flavor prod --target lib/main_prod.dart` |

> Tip: add a `key.properties` file at the Android root to sign release builds automatically, and drop the real Firebase config files into each flavor directory before shipping.

## Monorepo Structure

The application now adopts a [Melos](https://melos.invertase.dev/) workspace to
scale modular development across multiple Dart and Flutter packages.

- `melos.yaml` defines the workspace and shared scripts.
- `packages/restaurant_models` hosts the shared domain models and Firebase data
  mappers that can be reused by future apps or services.
- The root app consumes the local package via a path dependency declared in
  `pubspec.yaml`.

Common workspace commands:

```bash
melos bootstrap   # Fetch dependencies for all packages
melos run analyze # Analyze every package with the shared lint rules
melos run test    # Run the Flutter test suite (if Flutter is available)
```

## Testing

The Firebase Functions integration tests live in the `functions` workspace. Running
`npm test` from that directory will execute the Vitest suite against any available
unit-level mocks. To exercise the Firestore-dependent integration coverage, start
the Firebase emulators and run:

```bash
cd functions
npm run test:emulator
```

Without the emulator the integration suite is skipped during `npm test`.

## Deployment workflow

Before running `firebase deploy` execute the preflight script to make sure the
workspace is healthy:

```bash
./tool/preflight_deploy.sh
```

The script runs Flutter format/analyze/test (when Flutter is available), validates
the Melos workspace, and lints/tests the Cloud Functions package to surface
regressions before the deployment command executes. The script is also wired into
`firebase.json` as a `predeploy` hook so `firebase deploy --only functions` will
run it automatically.

### Automated dependency audits

GitHub Actions runs a dedicated **Dependency Audit** workflow on pull requests,
`main` branch pushes, and every Monday. It executes `flutter pub outdated` across
the Flutter workspace and `npm audit --omit=dev --audit-level=high` for the
Firebase Functions package to highlight vulnerable or stale dependencies before
they reach production.

### Canary rollouts & rollbacks with feature flags

Release channels provide a way to direct a subset of stores or terminals to a
different backend environment or flag configuration. To promote a `canary`
channel, set the target environment and any overrides using the
`FeatureFlagProvider.configureReleaseChannel` helper. For example:

```dart
await featureFlagProvider.configureReleaseChannel(
  channel: 'canary',
  environment: ReleaseEnvironment.staging,
  flagOverrides: {
    'newMenuFlow': true,
  },
);
```

Point the pilot stores at the `canary` release channel from the admin panel. If a
rollback is required, clear the channel overrides in a single call:

```dart
await featureFlagProvider.configureReleaseChannel(
  channel: 'canary',
  clear: true,
);
```

## Secrets & backend environment variables

Cloud Functions rely on a mix of environment variables and Google Secret Manager
entries for third-party integrations such as SendGrid and the synthetic monitor.
The `functions/.env.example` template lists every variable consumed via
`process.env`. Follow the [Firebase Functions README](functions/README.md) to:

- create a local `.env` file for emulator runs,
- publish non-sensitive values with `firebase deploy --env-vars-file`, and
- register secrets (`SENDGRID_API_KEY`, `SYNTHETIC_MONITOR_BEARER_TOKEN`, etc.)
  with `firebase functions:secrets:set`.

Without these values the scheduled monitor, backup exports, and email delivery
will fail fast during deployment.

With the channel cleared, affected stores fall back to the default production
flags without shipping a new build.

## QA Emulator Fixtures

Spin up the Firebase emulator suite and populate it with curated demo data in a
single command:

```bash
npm --prefix functions run seed:emulator
```

By default the script targets `localhost:8080` with the `demo-test` project ID.
Override `FIRESTORE_EMULATOR_HOST`, `PROJECT_ID` or set `RESET=true` to wipe the
existing collections before seeding.

## Typed Firestore accessors

The app now exposes strongly-typed Firestore collections via
`lib/services/firestore_converters.dart`. Providers such as the menu cache,
retail POS and store service consume these converters to remove manual JSON
mapping and catch schema drift at compile time.

## Build & performance telemetry

Frame build/raster metrics are sampled at runtime and streamed to BigQuery via
the callable Cloud Function `ingestBuildMetric`. Configure the destination table
with the `BUILD_METRICS_DATASET` and `BUILD_METRICS_TABLE` environment variables
when deploying Cloud Functions.

## Git hooks

Install the project hooks to automatically format, analyze and run targeted
tests on staged Dart files before every commit:

```bash
./tool/install_git_hooks.sh
```

The hook formats staged Dart files, runs `dart analyze` for the impacted
packages, and executes the relevant `flutter test`/`dart test` targets.
