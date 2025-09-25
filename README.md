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