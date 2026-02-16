# Copilot Coding Agent Onboarding Guide for Infomaniak/ios-kDrive

Before reading this file, please read AGENTS.md to learn more about the project context, structure, and conventions.

## Pull Request Review Instructions

- Pay attention for consistency with existing code style and architecture.
    - Make sure new code is properly abstracted, split, and added to the correct layer (UI / Core …)
    - You can ask to add unit tests in core related code that can be easily tested.
- Ensure strings are localized with KDriveResourcesStrings.Localizable.
- Ensure new UI wrote in UIKit is done in code. It should not rely on XIB, NIB, Storyboards for new features.
    - Regarding UIKit code, make sure we use safeAreaLayoutGuide and size classes to support modern iPhones and iPads. Please warn if something will break on iPad.
    - Regarding UIKit code, prefer the use of UIStackView rather than manually using Auto Layout rules, where reasonably possible.
    
- Ensure new UI wrote in SwiftUI uses Design System components where applicable. Notably IKPaddings, IKRadius, IKIconSize.

Some common Swift UI errors with correction:

Do: `VStack(alignment: .leading, spacing: IKPadding.micro)`
Don't do: `VStack(alignment: .leading)`
Comment: Multiple IKPadding exist, the dev has to choose the closest one to the design spec (micro, ..., giant - refer to IKPadding for full list).

Do: `.padding(value: .medium)`
Don't do: `.padding(16)`
Comment: Multiple IKPadding exist, the dev has to choose the closest one to the design spec (micro, ..., giant - refer to IKPadding for full list).

Do: `RoundedRectangle(cornerRadius: IKRadius.large)`
Don't do: `RoundedRectangle(cornerRadius: 12)`
Comment: Multiple IKRadius exist, the dev has to choose the closest one to the design spec (small, medium, large).
