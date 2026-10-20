# Lock-Watcher - macOS Surveillance Application

## Overview

- **Type**: macOS menu bar surveillance application
- **Stack**: Swift 6.4, SwiftUI with AppKit integration
- **Architecture**: MVVM + Coordinator pattern with Listener/Notifier patterns
- **Company**: Agnidia (com.igrsoft)

This AGENTS.md is the authoritative source for repository development guidelines.

---

## Universal Development Rules

### Code Quality (MUST)

- **MUST** use Swift 6 strict concurrency mode
- **MUST** use `@MainActor` for all UI-related code (Coordinator, ViewModels, Views)
- **MUST** ensure all data models conform to `Sendable` (ThiefDto, AppSettings, DatabaseDto)
- **MUST** run SwiftFormat before committing: `swiftformat .`
- **MUST NOT** commit secrets, API keys, or credentials
- **MUST NOT** log sensitive data (session IDs, user credentials, location data)

### Best Practices (SHOULD)

- **SHOULD** follow Manager pattern for business logic (ThiefManager, TriggerManager)
- **SHOULD** follow Listener pattern for event detection (WakeUpListener, USBListener)
- **SHOULD** follow Notifier pattern for output channels (iCloudNotifier, DropboxNotifier)
- **SHOULD** use protocol-based design for testability (BaseListenerProtocol, NotifierProtocol)
- **SHOULD** write tests for all new managers and listeners
- **SHOULD** use `@unchecked Sendable` for managers with internal synchronization

### Anti-Patterns (MUST NOT)

- **MUST NOT** use Singleton pattern - use dependency injection instead
- **MUST NOT** suppress Swift warnings without documented justification
- **MUST NOT** bypass macOS permission requirements (Camera, Location, Notifications)
- **MUST NOT** implement backward compatibility - remove legacy APIs completely when modernizing
- **MUST NOT** hardcode bundle identifiers - use xcconfig

---

## Core Commands

### Development

```bash
# Build MAS version
xcodebuild -project Lock-Watcher.xcodeproj -scheme Lock-Watcher -configuration Debug build

# Build Non-MAS version
xcodebuild -project Lock-Watcher.xcodeproj -scheme Lock-Watcher-non-mas -configuration Debug build

# Format code
swiftformat .

# Run tests
xcodebuild test -project Lock-Watcher.xcodeproj -scheme Lock-Watcher -destination 'platform=macOS'

# Reset app permissions (development)
tccutil reset All com.igrsoft.Lock-Watcher
```

### Quality Gates (run before PR)

```bash
swiftformat . && xcodebuild test -project Lock-Watcher.xcodeproj -scheme Lock-Watcher -destination 'platform=macOS'
```

---

## Project Structure

### Source Code

- **`Source/Application/`** - App entry point (@main, AppDelegate)
- **`Source/Coordinator/`** - Navigation coordination (MainCoordinator)
- **`Source/Managers/`** - Core business logic
  - TriggerManager - Listener orchestration
  - ThiefManager - Capture orchestration
  - DatabaseManager - Encrypted storage
  - AuthentificationManager - Password/biometric auth
- **`Source/Listeners/`** - Event trigger listeners
  - WakeUpListener, PowerListener, USBListener, LoginListener
  - DisplayListener, GeofenceListener, LockedInputListener (fire only while locked, via LockGraceGate)
  - WrongPasswordListener (Non-MAS only)
- **`Source/Notifiers/`** - Output channels
  - ICloudNotifier, DropboxNotifier, NotificationNotifier
  - MailNotifier (Non-MAS only)
- **`Source/Views/`** - SwiftUI interface (Settings, Main, FirstLaunch)
- **`Source/Models/`** - Data structures (ThiefDto, AppSettings)

### XPC Services

- **`XPCAuthentication/`** - Biometric auth (Swift)
- **`XPCMail/`** - Email delivery (Obj-C, Non-MAS only)
- **`XPCPower/`** - Power management

### Resources

- **`Resources/`** - Assets, Info.plist, entitlements, privacy manifest
- **`Configurations/`** - Build configs (MAS: `Configurations/app/`, Non-MAS: `Configurations/app-nomas/`)

---

## Quick Find Commands

### Code Navigation

```bash
# Find managers
rg -n "class.*Manager" Source/Managers

# Find listeners
rg -n "class.*Listener" Source/Listeners

# Find notifiers
rg -n "class.*Notifier" Source/Notifiers

# Find @MainActor usage
rg -n "@MainActor" Source/

# Find Sendable conformance
rg -n "Sendable" Source/
```

---

## Build Configurations

### MAS vs Non-MAS

| Feature | MAS | Non-MAS |
|---------|-----|---------|
| Bundle ID | com.igrsoft.Lock-Watcher | com.igrsoft.Lock-Watcher-nonmas |
| Scheme | Lock-Watcher | Lock-Watcher-non-mas |
| Wrong Password Listener | No | Yes |
| Mail Notifier | No | Yes |
| XPCMail Service | No | Yes |

### Conditional Compilation

```swift
#if MAS
    // Mac App Store compliant code
#else
    // Non-MAS build - full features
#endif
```

---

## Security Guidelines

### Permissions (CRITICAL)

- **Camera**: Required for photo or video capture - handle denial gracefully (no microphone entitlement exists)
- **Location**: Required for GPS metadata - check before each use
- **Notifications**: Required for alerts and upgrade notice - provide clear guidance if denied

### Secrets Management

- **NEVER** commit tokens, API keys, or credentials
- **NEVER** log sensitive data (use Logger with privacy levels)
- Use Keychain for credential storage (via AuthentificationManager)
- Configuration via `.xcconfig` files

### Safe Operations

- Review bash commands before execution
- Confirm before: `git push --force`, `rm -rf`, any destructive operation

---

## Git Workflow

- Branch from `develop` for features: `feature/<description>`
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`
- PRs require: passing tests, SwiftFormat, type checks
- Squash commits on merge
- Delete branches after merge

---

## Required Skills & Recommended Agents

### Critical Skills (Use Proactively)

| Skill | Usage |
|-------|-------|
| `apple-developer:skills` | Swift 6 language reference, SwiftUI/AppKit framework docs, concurrency patterns. **Use for all Swift syntax, API, and concurrency questions.** |

### Recommended Agents

| Task | Agent | When to Use |
|------|-------|-------------|
| macOS development | `macos-developer` | AppKit, menu bar apps, XPC services, system integration |
| General Apple development | `apple-developer` | Entry point for all Apple ecosystem work |
| Swift 6 concurrency | `swift-pro` | Swift 6+ with data race safety, actors, Sendable |
| Security reviews | `security-auditor` | Security reviews for surveillance functionality |
| Test automation | `test-automator` | Test automation for managers and listeners |

### Recommended Commands

| Command | Purpose |
|---------|---------|
| `/apple-developer:code-review` | Comprehensive code review |
| `/apple-developer:analyze-error` | Analyze and resolve errors |
| `/apple-developer:code-refactor` | Refactor using SOLID principles |
| `/apple-developer:dooc` | Generate DocC documentation |

---

## Platform Notes

| Setting | Value |
|---------|-------|
| Platform | macOS 14.1+ |
| Localization | English (en), Ukrainian (uk) |
| Storage | EasyStash (encrypted local storage) |
| Cloud | iCloud (CloudKit), Dropbox SDK |
| Camera | CameraSnap library (0.3.1+, photo or H.264 video) |
| Privacy Manifest | PrivacyInfo.xcprivacy (NSPrivacyAccessedAPICategoryFileTimestamp C617.1, NSPrivacyAccessedAPICategoryUserDefaults CA92.1) |
| Auto-Launch | LaunchAtLogin |
