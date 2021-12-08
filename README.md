# Infomaniak kDrive app

[![Tuist badge](https://img.shields.io/badge/Powered%20by-Tuist-blue)](https://tuist.io)
[![CI workflow](https://github.com/Infomaniak/ios-kDrive/actions/workflows/ci.yml/badge.svg)](https://github.com/Infomaniak/ios-kDrive/actions/workflows/ci.yml)

## A modern iOS application for [kDrive by Infomaniak](https://www.infomaniak.com/kdrive).
### Synchronise, share, collaborate.  The Swiss cloud that’s 100% secure.

#### :cloud: All the space you need
Always have access to all your photos, videos and documents. kDrive can store up to 106 TB of data.

#### :globe_with_meridians: A collaborative ecosystem. Everything included. 
Collaborate online on Office documents, organise meetings, share your work. Anything is possible!

#### :lock:  kDrive respects your privacy
Protect your data in a sovereign cloud exclusively developed and hosted in Switzerland. Infomaniak doesn’t analyze or resell your data.

[<img src="https://apple-resources.s3.amazonaws.com/media-badges/download-on-the-app-store/black/en-us.svg" alt="Download on the App Store">](https://apps.apple.com/app/infomaniak-kdrive/id1482778676)

## License & Contributions
This project is under GPLv3 license.
If you see a bug or an enhanceable point, feel free to create an issue, so that we can discuss about it, and once approved, we or you (depending on the criticality of the bug/improvement) will take care of the issue and apply a merge request.
Please, don't do a merge request before creating an issue.

## Tech things

### Language
The whole project is developed in **Swift 5** using **Xcode 12**.

### Tuist
This project uses [Tuist](https://tuist.io/docs/usage/getting-started/) to prevent conflicts on xcodeproj files. To generate the Xcode project, you need to install Tuist and run the `tuist generate` command. Refer to their documentation for more information.

### Compatibility
The minimum needed version to execute the app is iOS 12.0, anyway, we recommend to use the most recent version of iOS, the majority of our tests having been carried out on iOS 14.

### Cache
We use [Realm.io](https://realm.io/) on both platforms (iOS and Android) to store the offline data of files and shares (in different databases instances). App and user preferences are stored in `UserDefaults`. 

### Structure
The structure of the app, its algorithms and the general functioning are common with the Android app.

## Testing
Before running the Unit and UI tests, you must create an `Env` struct/enum. Duplicate the sample file (`kDriveTests/Env.sample.swift`), rename it to `Env`, and complete it. You can then run the tests using Xcode or Tuist.

## Legal Requirements

Apple, the Apple logo, and Xcode are trademarks of Apple Inc., registered in the U.S. and other countries and regions. App Store is a service mark of Apple Inc.

 IOS is a trademark or registered trademark of Cisco in the U.S. and other countries.
