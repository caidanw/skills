# Distribution: Signing, Notarization, Sandbox, Sparkle

What you'll find here: the end-to-end path from a built `.app` bundle to something users can run on a fresh macOS install without Gatekeeper blocking it. Covers the two distribution tracks (Mac App Store vs direct), code signing identities, entitlements, the hardened runtime, notarization with `notarytool`, stapling, Sparkle for auto-updates on direct builds, a minimal CI release pipeline, and the pitfalls that burn an afternoon the first time.

## Table of contents

- [The big picture](#the-big-picture)
- [Distribution paths](#distribution-paths)
- [Code signing basics](#code-signing-basics)
- [Entitlements](#entitlements)
- [Hardened runtime](#hardened-runtime)
- [Notarization with notarytool](#notarization-with-notarytool)
- [Verification commands](#verification-commands)
- [Sparkle auto-updates](#sparkle-auto-updates)
- [Sparkle 2 and sandboxing](#sparkle-2-and-sandboxing)
- [Mac App Store specifics](#mac-app-store-specifics)
- [The Xcode build-phase trap](#the-xcode-build-phase-trap)
- [A CI-friendly release script](#a-ci-friendly-release-script)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## The big picture

On modern macOS any app a user downloads must be **code-signed with a Developer ID certificate AND notarized by Apple**, or Gatekeeper blocks first launch on a fresh system. "Works on my Mac" means nothing — your Mac already trusts you; your users' Macs do not.

Most apps also enable the **App Sandbox**. It is mandatory for Mac App Store submissions and optional (but encouraged) for direct distribution. The sandbox constrains filesystem, network, and IPC access to what the app declares via entitlements.

For auto-updates, direct-distributed apps use **Sparkle**, the de-facto standard framework. Mac App Store apps do not ship their own updater — Apple pushes updates through App Store Connect.

Four gatekeepers, in order: `codesign` → hardened runtime → `notarytool` → `stapler staple`. Skip any one and the app either fails to notarize, fails to launch offline, or gets quarantined on first open.

## Distribution paths

| Path | Pros | Cons | Who fits |
| --- | --- | --- | --- |
| Mac App Store | Easy updates, payment/IAP, trust badge, family sharing | Review process, sandbox mandatory, 15-30% revenue cut, no kernel extensions, limited entitlements | Consumer apps, simple utilities, paid-upfront apps |
| Direct download (DMG + Sparkle) | Full control, no review, flexible entitlements, ship on your schedule | You own signing, notarization, update infrastructure, and crash reporting | Developer tools, pro apps, anything needing non-App-Store-friendly entitlements |
| Homebrew Cask | Reaches power users with one command | Needs a direct-download URL underneath; not a first-class channel; cask maintainers control the formula | Secondary channel alongside a DMG |
| TestFlight (beta) | First-class internal/external beta, crash reports, invite management | Uses App Store review, sandbox mandatory, capped at 10k external testers | Pre-release testing for App Store apps |

Direct download and Mac App Store are not exclusive if the codebase supports both, but the entitlements, bundle ID, and update mechanism differ enough that most teams pick one and stick with it.

## Code signing basics

You need an Apple Developer Program membership, a signing identity (certificate + private key in the login Keychain), and — for App Store submissions only — a provisioning profile. Direct distribution does **not** require a provisioning profile for Mac apps.

Identity types you will see in Xcode's "Signing & Capabilities" and in `security find-identity`:

| Identity | Purpose |
| --- | --- |
| Apple Development / Mac Developer | Local development builds only |
| Developer ID Application | Signing apps for direct distribution outside the App Store |
| Developer ID Installer | Signing `.pkg` installers for direct distribution |
| Apple Distribution | Signing apps for Mac App Store submission |
| Mac Installer Distribution | Signing `.pkg` payloads uploaded to App Store Connect |

Signing a single-binary `.app` bundle from the command line:

```bash
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
         --options runtime \
         --timestamp \
         --entitlements YourApp.entitlements \
         YourApp.app
```

Flags that matter:

- `--options runtime` enables the **hardened runtime**. Required for notarization; `notarytool` rejects submissions without it.
- `--timestamp` embeds a secure timestamp from Apple's timestamp server. Also required for notarization.
- `--entitlements` attaches the app's entitlement plist. See the next section.
- `--deep` (not shown) recursively signs nested frameworks, helpers, and XPC services with the parent's identity. **Avoid for complex apps** — it's wrong when a helper needs different entitlements. Sign nested components explicitly in reverse dependency order instead.

A correct manual sign order for a non-trivial app with a framework and helper:

```bash
# Frameworks (leaves of the dependency tree)
codesign --sign "$IDENTITY" --options runtime --timestamp \
         YourApp.app/Contents/Frameworks/Sparkle.framework

# XPC / helper tools with their own entitlements
codesign --sign "$IDENTITY" --options runtime --timestamp \
         --entitlements Helper.entitlements \
         YourApp.app/Contents/MacOS/YourHelper

# Main bundle last, with app-level entitlements
codesign --sign "$IDENTITY" --options runtime --timestamp \
         --entitlements YourApp.entitlements \
         YourApp.app
```

## Entitlements

Entitlements are a plist embedded in the signed binary that declares what the app is allowed to do. The kernel and frameworks read them at runtime to gate access to resources. Mac App Store Review also reads them to decide whether the app is even eligible.

Common keys:

| Key | Meaning |
| --- | --- |
| `com.apple.security.app-sandbox` | Enable App Sandbox (required for App Store) |
| `com.apple.security.network.client` | Outbound network connections |
| `com.apple.security.network.server` | Listen for inbound network connections |
| `com.apple.security.files.user-selected.read-write` | Read/write files the user explicitly picks via `NSOpenPanel`/`NSSavePanel` |
| `com.apple.security.files.user-selected.read-only` | Read-only version of the above |
| `com.apple.security.files.downloads.read-write` | Access to `~/Downloads` |
| `com.apple.security.files.bookmarks.app-scope` | Persist security-scoped bookmarks across launches |
| `com.apple.security.device.camera` | Camera access |
| `com.apple.security.device.microphone` | Microphone access |
| `com.apple.security.application-groups` | Participate in an App Group (shared container with helpers and extensions) |
| `com.apple.security.cs.disable-library-validation` | Load third-party frameworks not signed by the same team. Rare — tightens security when disabled |
| `com.apple.security.cs.allow-jit` | Allow JIT compilation (browser engines, language runtimes, emulators) |
| `com.apple.security.cs.allow-unsigned-executable-memory` | Allow executable memory without signing. Even rarer |
| `com.apple.security.cs.allow-dyld-environment-variables` | Honor `DYLD_*` env vars (debugging helpers) |

A minimal `YourApp.entitlements` for a sandboxed direct-distributed app:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

Add only what you need. Every entitlement is a promise to App Review and a potential reason for rejection. Camera, microphone, and full-disk access also require a matching `NS*UsageDescription` string in `Info.plist` or the OS terminates the app at first use.

## Hardened runtime

The hardened runtime is a set of process-level protections — restrictions on library loading, code injection, debugger attachment, and writable+executable memory. Enabled by `codesign --options runtime` and **required for notarization**.

The `com.apple.security.cs.*` entitlements listed above are escape hatches: each selectively disables one protection when a legitimate app (browser, emulator, plugin host) needs it. Ship without any `cs.*` entitlements and add them one at a time only when a concrete runtime failure forces your hand.

## Notarization with notarytool

`notarytool` (shipped with Xcode) replaced the deprecated `altool` notarization workflow years ago and is the only supported command in 2025+. The workflow:

```bash
# 1. Archive the signed .app. `ditto -c -k --keepParent` is the only
#    zip variant Apple reliably accepts; don't reach for /usr/bin/zip.
ditto -c -k --keepParent YourApp.app YourApp.zip

# 2. Submit for notarization and wait for the result.
xcrun notarytool submit YourApp.zip \
    --apple-id "you@example.com" \
    --team-id "TEAMID" \
    --password "app-specific-password" \
    --wait

# 3. Staple the notarization ticket to the .app so Gatekeeper can
#    verify it offline (first launch on a machine with no network).
xcrun stapler staple YourApp.app
```

The `--password` is an **app-specific password** generated at appleid.apple.com, not your Apple ID password. For CI, prefer an App Store Connect API key (`--key`, `--key-id`, `--issuer`) so credentials are not tied to a personal account.

Store credentials once in a Keychain profile and reference them by name afterwards:

```bash
xcrun notarytool store-credentials "MyAppNotary" \
    --apple-id "you@example.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"

xcrun notarytool submit YourApp.zip --keychain-profile "MyAppNotary" --wait
```

Notarization typically takes 2-30 minutes; Apple's queue latency is unpredictable, so assume the worst case for release timing. If submission fails, fetch the log:

```bash
xcrun notarytool log <submission-id> --keychain-profile "MyAppNotary"
```

The log contains machine-readable reasons — missing hardened runtime, unsigned nested binary, invalid entitlement — with enough detail to fix and resubmit.

Stapling is separate from notarization. A notarized-but-unstapled app runs online (Gatekeeper queries Apple at first launch) but fails on an offline fresh install — airplane mode during onboarding is enough to break it. Always staple before packaging.

## Verification commands

Useful when debugging signing and notarization issues:

```bash
# Show signing details: identity, entitlements, timestamp, hardened runtime
codesign -dvvv YourApp.app

# Strict signature verification (recurses into nested code)
codesign --verify --strict --deep --verbose=4 YourApp.app

# What Gatekeeper thinks on the current machine
spctl --assess --type execute --verbose YourApp.app

# Did stapling succeed — the ticket is present on disk
xcrun stapler validate YourApp.app

# Dump embedded entitlements as XML
codesign -d --entitlements :- YourApp.app
```

Run all four on a fresh build before every release. Anything that passes `codesign --verify` but fails `spctl --assess` usually means notarization or stapling did not complete.

## Sparkle auto-updates

[Sparkle](https://sparkle-project.org/) is the canonical auto-update framework for direct-distributed macOS apps. Install via Swift Package Manager from `https://github.com/sparkle-project/Sparkle`. The moving parts:

- **Appcast XML feed** — an RSS-like document listing available versions, hosted at a stable HTTPS URL. Sparkle polls it on a schedule.
- **EdDSA signing key pair** — generated once with Sparkle's `generate_keys` tool. The **private key stays offline** and signs each release archive. Lose it and you cannot ship updates to existing installs.
- **Public key embedded in Info.plist** — Sparkle uses it to verify the EdDSA signature before applying an update.
- **`SPUStandardUpdaterController`** — instantiate once at app launch and hook it up to a "Check for Updates..." menu item.

Minimal `Info.plist` entries for Sparkle:

```xml
<key>SUFeedURL</key>
<string>https://example.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>BASE64_ENCODED_PUBLIC_KEY</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
```

Minimal `appcast.xml` skeleton:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>YourApp Updates</title>
        <item>
            <title>Version 1.2.0</title>
            <pubDate>Mon, 01 Apr 2026 10:00:00 +0000</pubDate>
            <sparkle:version>1200</sparkle:version>
            <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="https://example.com/downloads/YourApp-1.2.0.dmg"
                length="12345678"
                type="application/octet-stream"
                sparkle:edSignature="BASE64_ENCODED_SIGNATURE"/>
        </item>
    </channel>
</rss>
```

Sign each release archive with Sparkle's `sign_update` tool before publishing and copy the resulting signature into the `sparkle:edSignature` attribute. Without it, Sparkle refuses to install the update.

For the gritty details (channels, phased rollouts, delta updates, localized release notes, migrating from Sparkle 1), read Sparkle's own documentation. Peter Steinberger's ["Code Signing and Notarization: Sparkle and Tears"](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears) is the best war-story writeup of the edge cases.

## Sparkle 2 and sandboxing

Sparkle 2 supports sandboxed apps via an XPC helper bundled inside the main app. The helper runs outside the sandbox (or in a looser one) so it can replace the running app on disk. Extra entitlements are required on both the helper and the main app — temporary exception entitlements for mach lookup and a matching App Group to share installation state.

Details shift between Sparkle 2.x point releases. Do not copy entitlement snippets from stale blog posts; read [Sparkle's "Sandboxing with Sparkle" guide](https://sparkle-project.org/documentation/sandboxing/) for the current requirements. General XPC helper patterns (lifecycle, mach service registration, message passing) live in `system-integration.md`.

### Sparkle + sandbox: real-world gotchas (Steinberger)

From [Peter Steinberger's "Code Signing and Notarization: Sparkle and Tears"](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears) — the best war-story source for what actually breaks:

**XPC mach-lookup entitlements.** Sandboxed apps must declare mach-lookup exceptions for Sparkle's two XPC services. Both suffixes are required — missing either causes silent authorization failure:

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.yourcompany.yourapp-spks</string>
    <string>com.yourcompany.yourapp-spki</string>
</array>
```

`-spks` = InstallerLauncher.xpc. `-spki` = Installer.xpc. Never rename Sparkle's internal bundle IDs (`org.sparkle-project.*`) — those are framework-internal. The mach-lookup strings use your app's prefix for communication routing only.

**Signing order matters.** Sign XPC services first, frameworks second, app last. Never `--deep`:

```bash
# 1. XPC services (with entitlements preserved for Sparkle 2.6+)
codesign -f -s "$IDENTITY" -o runtime \
    "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign -f -s "$IDENTITY" -o runtime --preserve-metadata=entitlements \
    "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"

# 2. Framework
codesign -f -s "$IDENTITY" -o runtime \
    "$APP/Contents/Frameworks/Sparkle.framework"

# 3. Main app (NO --deep)
codesign -f -s "$IDENTITY" -o runtime --entitlements YourApp.entitlements \
    "$APP"
```

**Info.plist flags for sandboxed Sparkle:**

```xml
<key>SUEnableInstallerLauncherService</key>
<true/>
<!-- Only set if the app LACKS com.apple.security.network.client: -->
<key>SUEnableDownloaderService</key>
<true/>
```

**Build number gotcha.** Sparkle compares `CFBundleVersion` (build number), not `CFBundleShortVersionString`. If your appcast generator defaults build numbers to "1", users see "You're up to date!" despite new versions. Validate build numbers increment in CI:

```bash
BUILD=$(plutil -extract CFBundleVersion raw Info.plist)
```

## Mac App Store specifics

Brief notes on what changes when you ship through the App Store:

- **App Sandbox is mandatory.** No exceptions. If you need something the sandbox forbids, the App Store is not your distribution channel.
- **Use Apple Distribution signing**, not Developer ID Application. Xcode will pick the right identity if "Automatically manage signing" is enabled for the Release configuration and the team has an active App Store agreement.
- **Upload via Transporter** (Apple's standalone app), Xcode's Organizer, or `xcrun altool --upload-app` / `xcrun notarytool` variants. Transporter is the most reliable for CI.
- **`NSAppTransportSecurity` exceptions require justification** in App Review Notes. Expect reviewers to ask why a specific domain needs cleartext traffic.
- **Review rejections are common on first submission.** Read the HIG, check metadata screenshots at the exact required sizes, and never submit a build that crashes on launch — App Review always launches the app once.
- **Receipt validation** — `Bundle.main.appStoreReceiptURL` points at a signed receipt. Validate it locally (or via Apple's server API) for piracy detection and feature gating.
- **No auto-updater framework.** Apple pushes updates through the App Store. Do not bundle Sparkle in an App Store build; it will be rejected.

## The Xcode build-phase trap

Xcode's "Signing & Capabilities" tab signs builds with your Apple Development identity by default. That identity works for local runs, debugging, and TestFlight uploads — but it does **not** produce a distributable artifact. A `.app` signed with Apple Development will fail notarization and will not launch on machines that have never seen your developer account.

For release builds, use **Product → Archive** in Xcode followed by **Distribute App** in the Organizer, or drive the same pipeline from the command line:

```bash
xcodebuild archive \
    -scheme YourApp \
    -configuration Release \
    -archivePath build/YourApp.xcarchive

xcodebuild -exportArchive \
    -archivePath build/YourApp.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` specifies the distribution method (`developer-id` for direct, `app-store-connect` for the App Store), the signing identity, and whether to notarize inline. Keep the file in version control next to the scheme so CI and local releases use the same options.

## A CI-friendly release script

Order of operations for a direct-distribution release. Treat it as pseudocode — wire up real paths, error handling, and secret management for your CI environment:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="YourApp"
SCHEME="YourApp"
ARCHIVE="build/${APP_NAME}.xcarchive"
EXPORT_DIR="build/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
DMG_PATH="build/${APP_NAME}.dmg"

xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist ExportOptions.plist

ditto -c -k --keepParent "$APP_PATH" "${EXPORT_DIR}/${APP_NAME}.zip"

xcrun notarytool submit "${EXPORT_DIR}/${APP_NAME}.zip" \
    --keychain-profile "MyAppNotary" \
    --wait

xcrun stapler staple "$APP_PATH"

create-dmg --volname "$APP_NAME" "$DMG_PATH" "$APP_PATH"
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
         --timestamp "$DMG_PATH"

# Upload DMG to your CDN / release host, then update appcast.xml with
# the new version, enclosure URL, size, and EdDSA signature.
```

Sign the DMG itself after building it — a signed DMG avoids a second Gatekeeper prompt when users mount it. You can also notarize the DMG (submit it to `notarytool` the same way as the zip) for a belt-and-suspenders setup, though a stapled app inside an unsigned DMG also works.

## Common pitfalls

- **Forgetting `--options runtime`**. Notarization rejects the submission. The cert is fine; the runtime flag is missing.
- **Using the wrong identity**. Signing with Apple Development instead of Developer ID Application is the most common cause of "app is damaged and can't be opened" on a user's machine.
- **Losing the Sparkle EdDSA private key**. No recovery path. Existing installs refuse to update to anything signed with a new key. Back it up to a password manager and a second offline location the day you generate it.
- **`codesign --deep` corrupting nested signatures**. `--deep` applies the parent's identity and entitlements to every child binary, which is wrong for helpers with their own entitlements. Sign helpers explicitly in reverse dependency order and leave `--deep` off the main bundle.
- **Notarization failing silently**. `notarytool submit` without `--wait` returns immediately with a submission ID and zero exit code, whether or not notarization later succeeds. Always pass `--wait` in CI, or poll `notarytool info` before proceeding.
- **Forgetting `stapler staple`**. The notarized app runs fine online and gets quarantined on the first offline launch. QA on a clean machine in airplane mode catches this.
- **Adding a new entitlement at release time** after the original cert was issued against a different profile. Some combinations require regenerating profiles; App Store builds may need explicit entitlement allowlisting through App Review.
- **Shipping debug symbols in the release build**. Archive-and-export always builds Release, but hand-rolled `xcodebuild` invocations sometimes leak the Debug configuration into production.
- **Not testing the signed + notarized + stapled artifact on a clean VM** before shipping. A throwaway macOS VM snapshot is the cheapest insurance against "worked on my Mac" release day.

## References

- **Rectangle** — a widely deployed open-source window manager with a public CI pipeline. Its release workflows and `scripts/` directory show a real-world signing + notarization + DMG + appcast setup worth reading end-to-end.
- **Sparkle** — [sparkle-project.org/documentation/](https://sparkle-project.org/documentation/) is the authoritative source for appcast, signing, sandboxing, and channel configuration.
- **Peter Steinberger — "Code Signing and Notarization: Sparkle and Tears"** (2025) — the most detailed writeup of what actually goes wrong during notarization and how to recover.
- **Apple — "Customizing the notarization workflow"** and **"Notarizing macOS software before distribution"** — the canonical Apple docs for `notarytool` and stapling.
- **Apple — "Hardened Runtime"** — official reference for the `com.apple.security.cs.*` entitlement family.
- `app-lifecycle.md` — for wiring Sparkle into `NSApplicationDelegate` and the "Check for Updates..." menu item.
- `system-integration.md` — for XPC helpers in general, including the Sparkle 2 updater helper.
- `anti-patterns.md` — includes the "missing sandbox or notarization" entry that this document expands on.
