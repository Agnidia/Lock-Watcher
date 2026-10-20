# Lock-Watcher — Changelog

## v1.7.1 (Build 1702) — 2026-10-13

### Fixed
- Correct singular and plural formatting in localized text
- Synchronize the geofence authorization state with macOS permission changes
- Keep settings steppers aligned when their values change

---

## v1.7.0 (Build 1701) — 2026-10-12

### New
- Display attached while locked trigger (off by default)
- Location change while locked trigger: the Mac moved 500 m or more since the last unlock, using significant location changes (off by default)
- Keyboard or mouse input while locked trigger, with a delay of 0–10 s (default 10 s) set by a stepper; re-arms 30 s after a capture, so repeated attempts in one lock are captured (off by default)
- New triggers fire only while the Mac is locked

### Improved
- USB trigger classifies volumes: disk images, network shares and internal volumes no longer trigger; physical external drives still do
- Saved settings carry over on upgrade
- Ukrainian localization completed and corrected
- No new permissions, no data collected (privacy label stays Data Not Collected)

---

## v1.6.0 (Build 1601) — 2026-10-06

### New
- Output type setting: photo or a silent 1–5 s video
- Output size setting for photo and video: Original, 1/2, 1/4
- "Keep files" setting: 1 year, 1 month, 1 week (default), or None (remove after upload)
- Video delivery to iCloud, Dropbox and notifications, with a still image when a video is too large
- Notification when camera access is denied

### Improved
- Upgrade grace period: captures made before the upgrade are kept for the full "Keep files" period
- Shortening "Keep files" asks for confirmation
- Stored JPEG quality is kept on upgrade from v1.5.0
- Trace route works again with SimpleTracer 0.1.3

### Infrastructure
- Camera library switched from PhotoSnap to CameraSnap 0.3.1
- SimplePing 0.1.2, SimpleTracer 0.1.3
- Privacy manifest (PrivacyInfo.xcprivacy)

---

## v1.5.0 (Build 1501) — 2026-09-16

### New
- Snapshot quality setting (Low 25%, Medium 50%, High 75%, Original)
- Snapshot resolution setting (Full, 1/2, 1/4) to save iCloud/Dropbox storage

### Improved
- macOS 27 support
- Concurrency fix in status bar popover

### Infrastructure
- Xcode 27, Swift 6.4

---

## v1.4.0 (Build 1401) — 2026-03-28

### New
- Smooth expand/collapse animation for ExtendedDivider
- Clean button in debug mode to reset database and settings

### Improved
- Centered FirstLaunchView window positioning
- Countdown timer display fix in FirstLaunchView
- Updated app icon
- Replaced LaunchAtLogin with LaunchAtLogin-Modern for better compatibility
- Updated minimum macOS version to 14.1

### Infrastructure
- CI/CD pipeline improvements

---

## v1.2.2 (Build 1222)

- Biometric authentication support (Touch ID, Apple Watch)
- App Store compliance updates
- Swift 6 migration

## v1.2.0 (Build 1200)

- Initial public release
