# Lock-Watcher

**macOS Surveillance Application for Security Monitoring**

Turn your Mac into a powerful surveillance system with Lock-Watcher. Detect and capture unauthorized access attempts discreetly, receiving high-quality photos or 1–5 second silent videos from your built-in or external camera and securely storing them locally or in the cloud.

## Company Information

**Company Name**: Agnidia
**Domain**: com.igrsoft
**Contact**: support@igrsoft.com

## Project Information

**Project Name**: Lock-Watcher
**Bundle Identifier**: com.igrsoft.Lock-Watcher
**Current Version**: 1.7.1 (Build 1702)

### Project Description

Lock-Watcher transforms your Mac into a stealthy security guardian. It monitors various system triggers - wake-up events, login attempts, power changes, USB connections, and wrong password entries - to detect potential unauthorized access. When triggered, it captures high-quality photos along with location, IP address, and network trace-route information, storing everything securely for later review.

## Features

- **Camera Selection** - Choose between built-in or external cameras for surveillance
- **Photo or Video Output** - Capture either high-quality photos or 1–5 second silent videos
- **Output Size Control** - Adjustable image and video size (Original, 1/2, 1/4) to optimize storage
- **JPEG Quality Settings** - Fine-tune photo compression for quality vs. storage balance
- **File Retention Control** - Keep local captures for 1 year, 1 month, 1 week, or remove after upload
- **Easy Configuration** - Simple setup for triggers and storage locations

### Security Triggers

- **On WakeUp** - Captures when Mac exits sleep mode
- **On Login** - Captures on user login events
- **On Battery Power Switch** - Captures when switching between AC and battery (laptops)
- **On USB Mount** - Captures when a removable or external drive is connected (disk images, network shares and internal volumes are ignored)
- **On Display Attach** - Captures when a display is connected while the Mac is locked
- **On Location Change** - Captures once when the Mac moves 500 m or more while locked
- **On Locked Input** - Captures on keyboard or mouse input while the Mac is locked
- **On Wrong Password** - Captures on failed login attempts (Non-MAS only)

### Snapshot Information

Each capture includes:
- Device location (GPS coordinates)
- Network IP address
- Network trace-route analysis
- Timestamp with date formatting

### Storage Options

- **Local Database** - Encrypted storage on your Mac
- **iCloud** - Sync to iCloud Drive
- **Dropbox** - Cloud backup via Dropbox
- **Mail** - Email delivery (Non-MAS only)

### Additional Features

- **Organized Files** - Date-formatted naming for easy retrieval
- **Customizable Menubar** - Icon indicator and notifications on triggers
- **Password Protection** - Secure access to snapshots and settings
- **Biometric Authentication** - Apple Watch and Touch ID keyboard support

## Technology Stack

- **Language**: Swift 6.4
- **UI Framework**: SwiftUI with AppKit integration
- **Minimum Platform**: macOS 14.1+
- **Architecture**: MVVM + Coordinator pattern
- **Concurrency**: Swift 6 strict concurrency
- **Storage**: EasyStash (encrypted local storage)
- **Cloud**: iCloud (CloudKit), Dropbox SDK
- **Camera**: CameraSnap library (photo or H.264 video capture)
- **Auto-Launch**: LaunchAtLogin
- **Privacy Manifest**: PrivacyInfo.xcprivacy with required API reason codes

## Requirements

- **macOS**: 14.1 or later
- **Hardware**: Mac with built-in or external camera
- **Xcode**: 27+ (for development)
- **Swift**: 6.4

## Project Structure

```
Lock-Watcher/
├── Source/                    # Main application source
│   ├── Application/           # App entry point and delegate
│   ├── Coordinator/           # Navigation coordination
│   ├── Managers/              # Core business logic
│   ├── Listeners/             # Event trigger listeners
│   ├── Notifiers/             # Output channel notifiers
│   ├── Views/                 # SwiftUI interface
│   ├── Models/                # Data structures
│   ├── Extensions/            # Swift extensions
│   ├── Utils/                 # Utility functions
│   └── Logger/                # Logging infrastructure
├── XPCServices/               # Privileged helper services
│   ├── XPCAuthentication/     # Biometric authentication
│   ├── XPCMail/               # Email delivery (Non-MAS)
│   └── XPCPower/              # Power management
├── Tests/                     # Unit tests
├── UITests/                   # UI automation tests
├── Resources/                 # Assets and configuration
└── Configurations/            # Build configs (MAS/Non-MAS)
```

## Getting Started

### 1. Clone Repository

```bash
git clone <repository-url>
cd Lock-Watcher
```

### 2. Open in Xcode

```bash
open Lock-Watcher.xcodeproj
```

### 3. Build and Run

Select the appropriate scheme:
- **Lock-Watcher** - Mac App Store build
- **Lock-Watcher-non-mas** - Direct distribution build

Press `Cmd+R` to build and run.

## Building

### MAS (Mac App Store) Build

```bash
xcodebuild -project Lock-Watcher.xcodeproj \
           -scheme Lock-Watcher \
           -configuration Release \
           build
```

### Non-MAS (Direct Distribution) Build

```bash
xcodebuild -project Lock-Watcher.xcodeproj \
           -scheme Lock-Watcher-non-mas \
           -configuration Release \
           build
```

## Testing

### Run Unit Tests

```bash
xcodebuild test \
    -project Lock-Watcher.xcodeproj \
    -scheme Lock-Watcher \
    -destination 'platform=macOS'
```

### Run UI Tests

```bash
xcodebuild test \
    -project Lock-Watcher.xcodeproj \
    -scheme Lock-Watcher \
    -destination 'platform=macOS' \
    -only-testing:Lock-WatcherUITests
```

## Development

### Code Style

Project uses **SwiftFormat** for consistent code formatting:

```bash
swiftformat .
```

Configuration in `.swiftformat` file.

### Reset App Permissions

For development testing, reset all permissions:

```bash
tccutil reset All com.igrsoft.Lock-Watcher
```

### Build Configurations

| Config | Bundle ID | Features |
|--------|-----------|----------|
| MAS | com.igrsoft.Lock-Watcher | App Store compliant |
| Non-MAS | com.igrsoft.Lock-Watcher-nonmas | Full features (Mail, WrongPassword) |

## Privacy & Security

Lock-Watcher prioritizes your privacy and security:

- **No Third-Party Services**: Data is never sent to external analytics or tracking services
- **Local Storage**: All captures stored locally or in your own cloud accounts
- **Encrypted Storage**: Local database uses encryption
- **Biometric Protection**: Optional Touch ID/Apple Watch authentication
- **Minimal Permissions**: Only requests necessary system permissions

## Contributing

### Before Committing

1. **Format code**: Run `swiftformat .`
2. **Run tests**: Ensure all tests pass
3. **Update docs**: If adding features

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new trigger type
fix: resolve camera capture issue
chore: update dependencies
docs: improve README
```

## Documentation

- [AGENTS.md](AGENTS.md) - AI development guidelines and agent configuration

## License

Copyright 2025 IGR Soft. All rights reserved.

See [LICENSE](LICENSE) file for details.

## Download

Available on the [Mac App Store](https://apps.apple.com/app/lock-watcher/id1583462846)

## Contact

For issues or questions:
- Create an issue in this repository
- Contact: support@igrsoft.com

---

**Made with care by Agnidia**
