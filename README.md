# ☁️ Infomaniak kDrive for iOS

Welcome to the official repository for **Infomaniak kDrive**, a modern and secure cloud storage client for iOS and iPadOS. 👋

<a href="https://apps.apple.com/app/infomaniak-kdrive/id1482778676"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1630886400"></a>

[![Tuist badge](https://img.shields.io/badge/Powered%20by-Tuist-blue)](https://tuist.io)
[![CI workflow](https://github.com/Infomaniak/ios-kDrive/actions/workflows/ci.yml/badge.svg)](https://github.com/Infomaniak/ios-kDrive/actions/workflows/ci.yml)

## 📖 About Infomaniak kDrive

Infomaniak kDrive is part of the <a href="https://www.infomaniak.com/">Infomaniak</a> ecosystem, providing a privacy-focused 🔒, Swiss-based 🇨🇭 cloud storage solution with a beautiful native iOS experience. Built with Swift and UIKit/SwiftUI, this app offers a fast, secure, and user-friendly way to store, synchronize, share, and collaborate on your files.

### Key Features

- **☁️ All the space you need**: Always have access to all your photos, videos and documents. kDrive can store up to 106 TB of data.
- **🌐 A collaborative ecosystem**: Collaborate online on Office documents, organize meetings, share your work. Everything included.
- **🔒 Privacy-first**: Protect your data in a sovereign cloud exclusively developed and hosted in Switzerland. Infomaniak doesn't analyze or resell your data.

## 🏗️ Architecture

The project follows a modular architecture with clear separation of concerns:

- **kDrive**: Main app target containing UIKit ViewControllers, SwiftUI views, app lifecycle, and navigation
- **kDriveCore**: Business logic framework with API layer, data models, managers, and services
- **kDriveResources**: Assets, localized strings, and resources
- **kDriveFileProvider**: Files app integration (NSFileProviderExtension)
- **kDriveShareExtension**: Share sheet extension for sharing files from other apps
- **kDriveActionExtension**: Action sheet extension for quick actions

## 🛠️ Technology Stack

- **Language**: Swift 5.10
- **UI Framework**: UIKit (primary) with SwiftUI integration for newer features
- **Database**: <a href="https://realm.io/">RealmSwift</a> for local data persistence
- **Build System**: <a href="https://tuist.io/">Tuist</a> for project generation and SPM dependency management
- **Tool Management**: <a href="https://mise.jdx.dev/">Mise</a> for managing tool versions
- **Networking**: Alamofire
- **Linting**: SwiftLint, SwiftFormat
- **Minimum iOS**: 13.0+ (SwiftUI features require iOS 16.4+)

## 🚀 Getting Started

### Prerequisites

1. Install <a href="https://mise.jdx.dev/">Mise</a> for tool version management:
   ```bash
   curl https://mise.run | sh
   ```
   
   Note: For alternative installation methods, visit the <a href="https://mise.jdx.dev/getting-started.html">official Mise documentation</a>.

2. Bootstrap the development environment:
   ```bash
   mise install
   # For bash users:
   eval "$(mise activate bash --shims)"
   # For zsh users:
   eval "$(mise activate zsh --shims)"
   # For other shells, see: https://mise.jdx.dev/getting-started.html
   ```

3. Install dependencies and generate the Xcode project:
   ```bash
   tuist install
   tuist generate
   ```

### Building and Running

Open the generated `kDrive.xcworkspace` in Xcode and build the project, or use:
```bash
xcodebuild -scheme "kDrive"
```

### Linting

Run SwiftLint before submitting any changes:
```bash
scripts/lint.sh
```

## 🧪 Testing

Before running the Unit and UI tests, you must create an `Env` struct/enum. Duplicate the sample file (`kDriveTests/Env.sample.swift`), rename it to `Env`, and complete it. You can then run the tests using Xcode or Tuist:
```bash
tuist test
```

## 📄 License & Contributions

This project is under GPLv3 license.

If you see a bug or an enhanceable point, feel free to create an issue, so that we can discuss about it, and once approved, we or you (depending on the criticality of the bug/improvement) will take care of the issue and apply a merge request.

**Please, don't do a merge request before creating an issue.**

## ⚖️ Legal Requirements

Apple, the Apple logo, and Xcode are trademarks of Apple Inc., registered in the U.S. and other countries and regions. App Store is a service mark of Apple Inc.

IOS is a trademark or registered trademark of Cisco in the U.S. and other countries.
