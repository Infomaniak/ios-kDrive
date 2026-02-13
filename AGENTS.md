# AGENTS.md

## Project Summary

Infomaniak kDrive — a production iOS cloud storage client supporting iPhone, iPad, and Mac Catalyst (iOS 13.0+).

- **Language:** Swift 5.10
- **UI:** UIKit (ViewControllers) with SwiftUI integration (iOS 16.4+)
- **Build system:** Tuist (project generation + SPM dependency management)
- **Database:** RealmSwift (Realm.io)
- **Networking:** Alamofire
- **Linting:** SwiftLint, SwiftFormat
- **CI/CD:** GitHub Actions + Xcode Cloud
- **Commit style:** Conventional Commits
- **Tool version manager:** Mise (https://mise.jdx.dev/)

## Context Map

```
ios-kDrive/
├── kDrive/                      # Main app target — UIKit controllers, views, app lifecycle
│   ├── AppDelegate.swift        #   App lifecycle, background tasks, root initialization
│   ├── AppDelegate+Scene.swift  #   Scene lifecycle configuration
│   ├── AppDelegate+BGNSURLSession.swift  # Background URL session handling
│   ├── SceneDelegate.swift      #   UIWindowSceneDelegate
│   ├── AppRouter.swift          #   Navigation & deep linking coordinator
│   ├── AppRouter+PublicShare.swift     # Public share link handling
│   ├── AppRouter+SharedWithMe.swift    # Shared folders routing
│   ├── AppRouter+BasicLink.swift       # Basic URL scheme handling
│   ├── AppRestorationService.swift     # State restoration
│   ├── UI/                      #   User Interface
│   │   ├── Controller/          #     ViewControllers (UIKit)
│   │   │   ├── Files/           #       File management (FileList, Preview, Search, etc.)
│   │   │   ├── Menu/            #       Navigation menu (PhotoList, Trash, Share)
│   │   │   ├── Home/            #       Home screen
│   │   │   ├── Photo/           #       Photo gallery
│   │   │   └── SwiftUI/         #       SwiftUI integration views
│   │   └── View/                #     Custom UIViews
│   ├── Resources/               #   Assets, localized strings, entitlements
│   │   ├── *.lproj/             #     Localizations (en, de, es, fr, it)
│   │   ├── Assets.xcassets      #     Images, colors, icons
│   │   └── Info.plist           #     App configuration
│   ├── Utils/                   #   Utility functions, helpers
│   │   └── KSuitePro/           #     KSuite Pro integration utilities
│   ├── Data/                    #   App-level data handling
│   └── IAP/                     #   In-App Purchase handling
│
├── kDriveCore/                  # Business logic framework
│   ├── Data/
│   │   ├── Api/                 #   REST API layer
│   │   │   ├── DriveApiFetcher.swift      #   Main API fetcher
│   │   │   ├── DriveApiFetcher+Upload.swift      #   Upload operations
│   │   │   ├── DriveApiFetcher+Listing.swift     #   File listing operations
│   │   │   ├── PublicShareApiFetcher.swift       #   Public share API
│   │   │   ├── Endpoint.swift           #   API endpoints
│   │   │   └── Endpoint+*.swift         #   Endpoint extensions
│   │   ├── Models/              #   Data models (Realm compatible)
│   │   │   ├── File.swift       #     Core file model
│   │   │   ├── Drive/           #     Drive account models
│   │   │   │   ├── Drive.swift  #       Drive entity
│   │   │   │   ├── DrivePack+.swift     # Subscription tiers
│   │   │   │   └── DriveCapabilities.swift       # Feature flags
│   │   │   ├── Upload/          #     Upload models
│   │   │   └── ShareLink.swift  #     Share link models
│   │   ├── Cache/               #   Data persistence & management
│   │   │   ├── AccountManager.swift     # User account management
│   │   │   ├── DriveFileManager/        # File/folder operations
│   │   │   ├── DriveInfosManager/       # Drive metadata
│   │   │   └── AvailableOfflineManager.swift     # Offline sync
│   │   ├── Database/            #   Realm configuration
│   │   │   └── RealmAccessor.swift
│   │   ├── DownloadQueue/       #   Download management
│   │   │   └── BackgroundDownloadSessionManager.swift
│   │   ├── Upload/              #   Upload management
│   │   │   └── Services/
│   │   │       └── BackgroundUploadSessionManager.swift
│   │   └── MQService/           #   MQTT real-time sync
│   ├── Services/                #   App-level services
│   │   ├── AppContextService.swift
│   │   └── BackgroundTasksService.swift
│   ├── UI/                      #   Shared UI components
│   │   ├── Alert/               #     Alert controllers
│   │   └── Scan/                #     Document scanning
│   ├── Utils/                   #   Core utilities
│   │   ├── PHAsset/             #     Photo library utilities
│   │   ├── FileProvider/        #     File provider utilities
│   │   ├── Files/               #     File operations
│   │   ├── Deeplinks/           #     Deep linking
│   │   └── Sentry/              #     Error tracking
│   ├── AudioPlayer/             #   Audio playback
│   ├── VideoPlayer/             #   Video playback
│   └── DI/                      #   Dependency Injection
│       └── FactoryService.swift
│
├── kDriveResources/             # Resources framework (localizations, assets)
├── kDriveFileProvider/          # Files app integration (NSFileProviderExtension)
│   ├── FileProviderExtension.swift      # Main provider implementation
│   ├── Enumerators/             #   Directory/file enumeration
│   │   ├── RootEnumerator.swift
│   │   ├── DirectoryEnumerator.swift
│   │   └── WorkingSetEnumerator.swift
│   └── *.entitlements
├── kDriveShareExtension/        # Share sheet extension
├── kDriveActionExtension/       # Action sheet extension
├── kDriveTests/                 # Unit tests (XCTest)
├── kDriveAPITests/              # API integration tests
├── kDriveUITests/               # UI automation tests
├── kDriveTestShared/            # Shared test utilities
├── Tuist/                       # Tuist configuration
│   ├── Package.swift            #   SPM dependency declarations
│   └── ProjectDescriptionHelpers/   # Build helpers & constants
├── Project.swift                # Tuist project definition
├── scripts/                     # Development scripts
│   └── lint.sh                  #   SwiftLint runner
├── ci_scripts/                  # Xcode Cloud CI — DO NOT run locally
├── .github/workflows/           # GitHub Actions
├── .swiftlint.yml               # SwiftLint rules
├── .swiftformat                 # SwiftFormat config
├── .mise.toml                   # Tool versions
├── .import_loco.yml             # Localization sync config
└── .sonarcloud.properties       # Code quality config
```

## Local Norms

### Command Patterns

```bash
# Install mise if not yet installed
curl https://mise.run | sh

# Bootstrap environment (required before build/lint/test)
mise install
eval "$(mise activate bash --shims)"

# Install SPM dependencies
tuist install

# Generate Xcode project
tuist generate --no-open

# Build
xcodebuild -scheme "kDrive"

# Lint (run before every PR)
scripts/lint.sh

# Run tests
tuist test # Or via Xcode Test Navigator
```

### Code Style

- **Naming:** Swift standard — `camelCase` for variables/functions, `PascalCase` for types.
- **Max line width:** 130 characters.
- **Indentation:** 4 spaces, LF line endings.
- **Imports:** Alphabetical grouping, blank line after imports.
- **SwiftUI (when used):** Property wrappers must be private (`@State`, `@StateObject`, etc.).
- **Localized strings:** Use localized string keys from `kDriveResources` — never raw string literals.
- **DI:** Use `@InjectService` from InfomaniakDI for dependency injection; register via `FactoryService` in kDriveCore.
- **API layer:** Extend `DriveApiFetcher` for API operations. Create focused extensions (`+Upload`, `+Listing`, `+Share`).
- **Endpoint definitions:** Define API endpoints in `Endpoint.swift` and extend with `Endpoint+Files.swift`, `Endpoint+Share.swift`, etc.
- **Concurrency:** Use `async/await` and structured concurrency.
- **Data persistence:** Realm models must be thread-safe; use `RealmAccessor` for background writes.
- **Manager pattern:** Core data managers follow the *Manager naming (AccountManager, DriveFileManager, DriveInfosManager, AvailableOfflineManager).
- **File Provider:** `BackgroundUploadSessionManager` and `BackgroundDownloadSessionManager` handle background upload/download.

### Testing

- **Unit tests:** `kDriveTests/` — XCTest-based, fast tests.
- **API tests:** `kDriveAPITests/` — API integration tests requiring network.
- **UI tests:** `kDriveUITests/` — XCTest UI automation.
- **Setup:** Duplicate `kDriveTests/Env.sample.swift` → `kDriveTests/Env.swift` and fill credentials.
- **Run:** `tuist test` or Xcode Test Navigator.
- **CI:** GitHub Actions run tests on PRs.

### PR Checklist

- Run `scripts/lint.sh` — no lint errors.
- Use Conventional Commits for commit messages.
- Localize all user-facing strings via resource files.
- Ensure Realm models define proper primary keys for thread safety.
- Never use `ci_scripts/` locally.
- Test background uploads/downloads if modifying File Provider.

### Learned Preferences

_None yet. Add user-corrected preferences here as they arise._

## Self-correction

> This section is for you, the future agent.
>
> 1. **Stale Map:** If you encounter a file or folder not listed in the "Context Map", update the map in this file.
> 2. **New Norms:** If the user corrects you (e.g., "Don't use X, use Y"), add that rule to the "Local norms" section immediately so you don't make the mistake again.
> 3. **Refinement:** If you find this file is too verbose, prune it. Keep it high-signal.
