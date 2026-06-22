# Riza — macOS / iOS build setup

This is the setup guide for building **Riza** (`com.fabtechonline.riza`) on a Mac
to run on iPhone. It's written so a coding agent (Antigravity, Claude Code, etc.)
or a person can follow it after a fresh `git clone`.

> The project was developed on Windows (Android builds). iOS support is already
> scaffolded and committed: bundle id `com.fabtechonline.riza`, display name
> **Riza**, app icon + native splash generated, deployment target **iOS 15.5**
> (required by `google_mlkit_face_detection`, `camera`, `mobile_scanner`).

## 1. Toolchain (one-time)

```bash
# Xcode from the App Store, then:
sudo xcodebuild -license accept
xcode-select --install

# Homebrew (https://brew.sh) if missing, then:
brew install --cask flutter
brew install cocoapods
flutter doctor          # resolve any reported issues
```

## 2. The one file that isn't in git: `env.json`

The app reads `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` at build time via
`--dart-define-from-file=env.json`. **`env.json` is gitignored** (so are
`FamilyTreeDetails.txt` / `RizaDetails.txt`, which hold the real values).

Create `env.json` in the project root, shaped like `env.example.json`:

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

Copy the real values from `FamilyTreeDetails.txt` (transfer that file to the Mac
manually — AirDrop/USB, never via git). Only the **publishable** key belongs in
the client; the secret key is server-side only (Supabase Edge Function secrets).

## 3. Build & run on iPhone

```bash
flutter pub get
cd ios && pod install && cd ..     # first run downloads large ML Kit pods
open ios/Runner.xcworkspace        # NOT Runner.xcodeproj
```

In Xcode: **Runner** target → **Signing & Capabilities** → set your **Team**
(Apple ID). Then run from Xcode (▶) or:

```bash
flutter run -d <iphone> --dart-define-from-file=env.json
```

On the device, first launch: trust the dev profile under
**Settings → General → VPN & Device Management**.

## Notes / gotchas

- A **free Apple ID** runs Riza on your own device (7-day signing cert).
  **TestFlight / App Store** needs the Apple Developer Program ($99/yr).
- On **Apple Silicon**, the ML Kit / TFLite pods occasionally need a tweak. If
  `pod install` or the Xcode build fails there, common fixes:
  - `sudo gem install ffi` then retry, or run `arch -x86_64 pod install`.
  - Ensure CocoaPods is current (`brew upgrade cocoapods`).
  - Delete `ios/Pods` + `ios/Podfile.lock` and re-run `pod install`.
- If `pod install` complains about the deployment target, it's pinned to 15.5 in
  `ios/Podfile` (post_install) and the Xcode project — don't lower it.
- Regenerating branding (if the logo changes): masters live in
  `assets/branding/`; run `dart run flutter_launcher_icons` and
  `dart run flutter_native_splash:create`.

## Project facts (for context)

- Flutter + Riverpod; Supabase backend (Auth/Postgres/Storage/Realtime/Edge
  Functions/RLS). Auth = password OR 6-digit email OTP.
- Platforms in repo: Android, iOS, web, Windows. Android is the primary tested
  target (release APK builds clean); iOS is new and validated only on a Mac.
- GitHub repo is `https://github.com/fabtechonline/familytree.git` (named
  `familytree`; the app is branded **Riza**).
