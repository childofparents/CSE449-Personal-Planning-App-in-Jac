# Cadence mobile

Native Jac mobUI screens for iOS and Android, using the existing authenticated planner service.

See the root [README](../README.md#mobile-app--ios-and-android) for complete prerequisites, phone and browser launch commands, Google configuration, and verification limits.

Quick browser preview from the repository root:

```sh
jac install
jac run --platform web --port 8120 mobile
```

`main.jac` owns screens/forms; `theme.jac` mirrors the web palette. `client.jac` calls the shared server. `session.native.jac` uses SecureStore; `session.jac` is the browser variant. `components/Safe.native.jac` supplies native safe areas. Shared date/preview/transport helpers live in `shared/`.
