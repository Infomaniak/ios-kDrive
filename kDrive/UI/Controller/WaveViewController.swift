/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import CocoaLumberjackSwift
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakLogin
import InfomaniakOnboarding
import kDriveCore
import kDriveResources
import Lottie
import UIKit

class WaveViewController: UIViewController {
    @LazyInjectService private var appNavigable: AppNavigable

    let onboardingViewController: OnboardingViewController
    let slideCount: Int

    let slides: [Slide]
    let dismissHandler: (() -> Void)?

    init(slides: [Slide], dismissHandler: (() -> Void)? = nil) {
        self.slides = slides
        self.dismissHandler = dismissHandler

        let configuration = OnboardingConfiguration(
            headerImage: KDriveResourcesAsset.logo.image,
            slides: slides,
            pageIndicatorColor: KDriveResourcesAsset.infomaniakColor.color,
            isScrollEnabled: true,
            dismissHandler: dismissHandler,
            isPageIndicatorHidden: false
        )
        onboardingViewController = OnboardingViewController(configuration: configuration)
        slideCount = slides.count
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color

        onboardingViewController.delegate = self
        addChild(onboardingViewController)
        onboardingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(onboardingViewController.view)
        onboardingViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            onboardingViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            onboardingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            onboardingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            onboardingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loginDelegateHandler(signInButton: UIButton, registerButton: UIButton) -> LoginDelegateHandler {
        let loginDelegateHandler = LoginDelegateHandler()
        loginDelegateHandler.didStartLoginCallback = {
            signInButton.isEnabled = false
            registerButton.isEnabled = false
        }
        loginDelegateHandler.didCompleteLoginCallback = {
            signInButton.isEnabled = true
            registerButton.isEnabled = true
        }
        loginDelegateHandler.didFailLoginWithErrorCallback = { _ in
            signInButton.isEnabled = true
            registerButton.isEnabled = true
        }
        return loginDelegateHandler
    }

    func createNextButton(in containerView: UIView) {
        let nextButton = IKRoundButton()
        let nextButtonHeight = 80.0
        nextButton.setImage(KDriveResourcesAsset.arrowRight.image.withRenderingMode(.alwaysTemplate), for: .normal)
        nextButton.imageView?.tintColor = .white
        nextButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerNext
        nextButton.elevated = true
        nextButton.layer.cornerRadius = nextButtonHeight / 2
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onboardingViewController.pageIndicator.currentPage += 1
            onboardingViewController.setSelectedSlide(index: onboardingViewController.pageIndicator.currentPage)
        }, for: .touchUpInside)

        containerView.addSubview(nextButton)
        NSLayoutConstraint.activate([
            nextButton.widthAnchor.constraint(equalToConstant: nextButtonHeight),
            nextButton.heightAnchor.constraint(equalToConstant: nextButtonHeight),
            nextButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            nextButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nextButton.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 0),
            nextButton.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: 0),
            nextButton.topAnchor.constraint(greaterThanOrEqualTo: containerView.topAnchor, constant: 0),
            nextButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: 0)
        ])
    }

    func createSignInRegisterButton(in containerView: UIView) {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = UIConstants.Padding.mediumSmall
        stackView.distribution = .fillProportionally
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.Padding.medium, right: 0)

        let signInButton = IKLargeButton()
        let registerButton = IKLargeButton()
        let loginDelegateHandler = loginDelegateHandler(signInButton: signInButton, registerButton: registerButton)

        signInButton.style = .primaryButton
        signInButton.elevated = true
        signInButton.setTitle(KDriveResourcesStrings.Localizable.buttonLogin, for: .normal)
        signInButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            appNavigable.showLogin(delegate: loginDelegateHandler)
        }, for: .touchUpInside)

        registerButton.style = .plainButton
        registerButton.setTitle(KDriveCoreStrings.Localizable.buttonSignIn, for: .normal)
        registerButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            appNavigable.showRegister(delegate: loginDelegateHandler)
        }, for: .touchUpInside)

        stackView.addArrangedSubview(signInButton)
        stackView.addArrangedSubview(registerButton)
        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            registerButton.heightAnchor.constraint(equalToConstant: UIConstants.Button.largeHeight),
            signInButton.heightAnchor.constraint(equalToConstant: UIConstants.Button.largeHeight),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                               constant: UIConstants.Padding.standard),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,
                                                constant: -UIConstants.Padding.standard),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 350)
        ])
    }
}

extension WaveViewController: OnboardingViewControllerDelegate {
    func shouldAnimateBottomViewForIndex(_ index: Int) -> Bool {
        guard slides.count > 1 else { return false }

        return index == slideCount - 1
    }

    func willDisplaySlideViewCell(_ slideViewCell: InfomaniakOnboarding.SlideCollectionViewCell, at index: Int) {}

    func bottomUIViewForIndex(_ index: Int) -> UIView? {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        if index != slideCount - 1 {
            createNextButton(in: containerView)
        } else {
            createSignInRegisterButton(in: containerView)
        }

        return containerView
    }

    func currentIndexChanged(newIndex: Int) {}
}

extension Slide {
    static var onboardingSlides: [Slide] {
        return [
            Slide(backgroundImage: KDriveResourcesAsset.background1.image,
                  backgroundImageTintColor: KDriveResourcesAsset.backgroundColor.color,
                  content: .animation(IKLottieConfiguration(
                      id: 1,
                      filename: "illu_devices",
                      bundle: KDriveResources.bundle,
                      loopFrameStart: 54,
                      loopFrameEnd: 138,
                      lottieConfiguration: .init(renderingEngine: .mainThread)
                  )),
                  bottomViewController: OnboardingBottomViewController(
                      title: KDriveResourcesStrings.Localizable.onBoardingTitle1,
                      description: KDriveResourcesStrings.Localizable.onBoardingDescription1
                  )),
            Slide(backgroundImage: KDriveResourcesAsset.background2.image,
                  backgroundImageTintColor: KDriveResourcesAsset.backgroundColor.color,
                  content: .animation(IKLottieConfiguration(
                      id: 2,
                      filename: "illu_collab",
                      bundle: KDriveResources.bundle,
                      loopFrameStart: 108,
                      loopFrameEnd: 253,
                      lottieConfiguration: .init(renderingEngine: .mainThread)
                  )),
                  bottomViewController: OnboardingBottomViewController(
                      title: KDriveResourcesStrings.Localizable.onBoardingTitle2,
                      description: KDriveResourcesStrings.Localizable.onBoardingDescription2
                  )),
            Slide(backgroundImage: KDriveResourcesAsset.background3.image,
                  backgroundImageTintColor: KDriveResourcesAsset.backgroundColor.color,
                  content: .animation(IKLottieConfiguration(
                      id: 3,
                      filename: "illu_photos",
                      bundle: KDriveResources.bundle,
                      loopFrameStart: 111,
                      loopFrameEnd: 187,
                      lottieConfiguration: .init(renderingEngine: .mainThread)
                  )),
                  bottomViewController: OnboardingBottomViewController(
                      title: KDriveResourcesStrings.Localizable.onBoardingTitle3,
                      description: KDriveResourcesStrings.Localizable.onBoardingDescription3
                  ))
        ]
    }

    static var pleaseLogin =
        [
            Slide(backgroundImage: KDriveResourcesAsset.background3.image,
                  backgroundImageTintColor: KDriveResourcesAsset.backgroundColor.color,
                  content: .animation(IKLottieConfiguration(
                      id: 3,
                      filename: "illu_photos",
                      bundle: KDriveResources.bundle,
                      loopFrameStart: 111,
                      loopFrameEnd: 187,
                      lottieConfiguration: .init(renderingEngine: .mainThread)
                  )),
                  bottomViewController: OnboardingBottomViewController(
                      title: KDriveResourcesStrings.Localizable.onBoardingTitle3,
                      description: KDriveResourcesStrings.Localizable.onBoardingDescription3
                  ))
        ]
}

@available(iOS 17, *)
#Preview {
    WaveViewController(slides: Slide.onboardingSlides)
}

@available(iOS 17, *)
#Preview {
    WaveViewController(slides: Slide.pleaseLogin)
}
