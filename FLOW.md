# Screenshot capture flow

Real captures from the iOS Simulator via an integration-test driver (no mockups).

## Steps

1. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17 Pro"
   open -a Simulator
   ```
2. Scaffold the iOS platform folder (lib-only project) and get dependencies:
   ```bash
   flutter create . --platforms=ios --project-name flutter_app_monitoring
   flutter pub get
   ```
3. Drive the screenshot test:
   ```bash
   flutter drive \
     --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart \
     -d "DEF7D24B-5FE8-4569-9891-EFBE66C4F567"
   ```
4. Build the demo GIF from the PNGs:
   ```bash
   cd screenshots
   ffmpeg -y -framerate 1 -pattern_type glob -i '*.png' \
     -vf "scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     -loop 0 demo.gif
   ```

PNGs + `demo.gif` are written to `screenshots/` and embedded in `README.md`.

## How it works

- `test_driver/integration_test.dart` - `integrationDriver(onScreenshot:)` writes each PNG to `screenshots/<name>.png`.
- `integration_test/screenshot_test.dart` - pumps the real `DashboardScreen` directly inside a `ProviderScope` so the test never touches `Firebase.initializeApp` or `SentryFlutter.init`. A test-only `_SeededMonitoringClient` overrides `init()` to skip those heavy SDKs and instead seeds the `UptimeProber` with four endpoints, backed by a fake Dio `HttpClientAdapter` (`_FakeAdapter`) that returns canned statuses - the `payments` endpoint returns 503 so the live `StreamBuilder` renders a real DOWN row next to the healthy ones. The test calls `binding.convertFlutterSurfaceToImage()` + `binding.takeScreenshot('NN-name')` at each key view, using fixed `pump(Duration)` so the live probe stream and frame counters settle without hanging.
