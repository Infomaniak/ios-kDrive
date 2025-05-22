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

    private lazy var loginDelegateHandler: LoginDelegateHandler = {
        let loginDelegateHandler = LoginDelegateHandler()
        loginDelegateHandler.didStartLoginCallback = { [weak self] in
            guard let self else { return }
            signInButton.setLoading(true)
            registerButton.isEnabled = false
        }
        loginDelegateHandler.didCompleteLoginCallback = { [weak self] in
            guard let self else { return }
            self.signInButton.setLoading(false)
            self.registerButton.isEnabled = true
        }
        loginDelegateHandler.didFailLoginWithErrorCallback = { [weak self] _ in
            guard let self else { return }
            self.signInButton.setLoading(false)
            self.registerButton.isEnabled = true
        }
        return loginDelegateHandler
    }()

    let onboardingViewController: OnboardingViewController
    let slideCount: Int

    let slides: [Slide]
    let dismissHandler: (() -> Void)?

    var showAuthButtons = false {
        didSet {
            updateButtonsVisibility()
        }
    }

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

    let nextButton = UIButton(type: .custom)
    let nextButtonHeight = 80.0
    let registerButton = UIButton(type: .system)
    let signInButton = UIButton(type: .system)

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

        setupNextButton()
        setupAuthButtons()

        if slideCount == 1 {
            showAuthButtons = true
        }
    }

    private func setupNextButton() {
        nextButton.setImage(KDriveResourcesAsset.arrowRight.image.withRenderingMode(.alwaysTemplate), for: .normal)
        nextButton.imageView?.tintColor = .white
        nextButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerNext

        nextButton.backgroundColor = KDriveResourcesAsset.infomaniakColor.color
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.layer.cornerRadius = nextButtonHeight / 2
        nextButton.clipsToBounds = true
        nextButton.addTarget(self, action: #selector(nextButtonPressed), for: .touchUpInside)

        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            nextButton.widthAnchor.constraint(equalToConstant: nextButtonHeight),
            nextButton.heightAnchor.constraint(equalToConstant: nextButtonHeight),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30)
        ])

        view.bringSubviewToFront(nextButton)
    }

    private func setupAuthButtons() {
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.setTitle(KDriveResourcesStrings.Localizable.buttonLogin, for: .normal)
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.backgroundColor = KDriveResourcesAsset.infomaniakColor.color
        signInButton.layer.cornerRadius = 8
        signInButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        signInButton.isHidden = true
        signInButton.addTarget(self, action: #selector(signInButtonPressed), for: .touchUpInside)
        view.addSubview(signInButton)

        registerButton.translatesAutoresizingMaskIntoConstraints = false
        registerButton.setTitle(KDriveCoreStrings.Localizable.buttonSignIn, for: .normal)
        registerButton.setTitleColor(KDriveResourcesAsset.infomaniakColor.color, for: .normal)
        registerButton.layer.cornerRadius = 8
        registerButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        registerButton.isHidden = true
        registerButton.addTarget(self, action: #selector(registerButtonPressed), for: .touchUpInside)
        view.addSubview(registerButton)

        NSLayoutConstraint.activate([
            signInButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UIConstants.Padding.standard),
            signInButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -UIConstants.Padding.standard),
            signInButton.bottomAnchor.constraint(equalTo: registerButton.topAnchor, constant: -UIConstants.Padding.medium),
            signInButton.heightAnchor.constraint(equalToConstant: UIConstants.Button.largeHeight),

            registerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UIConstants.Padding.standard),
            registerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -UIConstants.Padding.standard),
            registerButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -UIConstants.Padding.medium
            ),
            registerButton.heightAnchor.constraint(equalToConstant: UIConstants.Button.largeHeight)
        ])
    }

    private func updateButtonsVisibility() {
        nextButton.isHidden = showAuthButtons
        registerButton.isHidden = !showAuthButtons
        signInButton.isHidden = !showAuthButtons
    }

    @objc private func nextButtonPressed() {
        onboardingViewController.pageIndicator.currentPage += 1
        onboardingViewController.setSelectedSlide(index: onboardingViewController.pageIndicator.currentPage)
    }

    @objc private func signInButtonPressed() {
        appNavigable.showLogin(delegate: loginDelegateHandler)
    }

    @objc private func registerButtonPressed() {
        appNavigable.showRegister(delegate: loginDelegateHandler)
    }
}

extension WaveViewController: OnboardingViewControllerDelegate {
    func shouldAnimateBottomViewForIndex(_ index: Int) -> Bool {
        return false
    }

    func willDisplaySlideViewCell(_ slideViewCell: InfomaniakOnboarding.SlideCollectionViewCell, at index: Int) {}

    func currentIndexChanged(newIndex: Int) {
        let isLast = newIndex == slideCount - 1
        showAuthButtons = isLast
    }
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
