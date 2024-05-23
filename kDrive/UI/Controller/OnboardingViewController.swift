/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import Lottie
import UIKit

class OnboardingViewController: UIViewController {
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var buttonContentView: UIView!
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!

    @IBOutlet weak var collectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var signInButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var nextButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var registerButtonHeight: NSLayoutConstraint!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var infomaniakLogin: InfomaniakLoginable
    @LazyInjectService var appNavigable: AppNavigable

    var addUser = false
    var slides: [Slide] = []

    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    override func viewDidLoad() {
        super.viewDidLoad()
        infomaniakLogin.setupWebviewNavbar(title: "",
                                           titleColor: nil,
                                           color: nil,
                                           buttonColor: nil,
                                           clearCookie: true,
                                           timeOutMessage: "Timeout")
        nextButton.setImage(KDriveResourcesAsset.arrowRight.image.withRenderingMode(.alwaysTemplate), for: .normal)
        nextButton.imageView?.tintColor = .white
        nextButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerNext
        navigationBar.isHidden = !addUser
        navigationBar.isTranslucent = true
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.shadowImage = UIImage()
        closeBarButtonItem.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        collectionView.register(cellView: SlideCollectionViewCell.self)

        slides = createSlides()
        pageControl.numberOfPages = slides.count
        pageControl.currentPage = 0
        // Handle tap on control to change page
        pageControl.addTarget(self, action: #selector(pageChanged), for: .valueChanged)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        endBackgroundTask()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        signInButton.setLoading(false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: ["Onboarding"])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if view.frame.height < 600 {
            signInButtonHeight.constant = 45
            registerButtonHeight.constant = 45
            nextButtonHeight.constant = 60
            nextButton.layer.cornerRadius = nextButtonHeight.constant / 2
            collectionViewTopConstraint.constant = -40
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        } completion: { _ in
            let indexPath = IndexPath(row: self.pageControl.currentPage, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
    }

    @IBAction func nextButtonPressed(_ sender: Any) {
        if pageControl.currentPage < slides.count - 1 {
            let indexPath = IndexPath(row: pageControl.currentPage + 1, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
    }

    @objc func pageChanged() {
        if pageControl.currentPage < slides.count {
            let indexPath = IndexPath(row: pageControl.currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
    }

    @IBAction func signInButtonPressed(_ sender: Any) {
        MatomoUtils.track(eventWithCategory: .account, name: "openLoginWebview")
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Login WebView") { [weak self] in
            SentryDebug.capture(message: "Background task expired while logging in")
            self?.endBackgroundTask()
        }
        infomaniakLogin.webviewLoginFrom(viewController: self,
                                         hideCreateAccountButton: true,
                                         delegate: self)
    }

    @IBAction func registerButtonPressed(_ sender: Any) {
        MatomoUtils.track(eventWithCategory: .account, name: "openCreationWebview")
        present(RegisterViewController.instantiateInNavigationController(delegate: self), animated: true)
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }

    private func goToMainScreen(with driveFileManager: DriveFileManager) {
        UserDefaults.shared.legacyIsFirstLaunch = false
        UserDefaults.shared.numberOfConnections = 1
        let mainTabViewController = MainTabViewController(driveFileManager: driveFileManager)
        appNavigable.setRootViewController(mainTabViewController, animated: true)
    }

    private func updateButtonsState() {
        if pageControl.currentPage == slides.count - 1 {
            if buttonContentView.isHidden {
                buttonContentView.alpha = 0
                buttonContentView.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.buttonContentView.alpha = 1
                    self.buttonContentView.isHidden = false
                    self.nextButton.alpha = 0
                } completion: { _ in
                    self.nextButton.alpha = 0
                    self.nextButton.isHidden = true
                }
            }
        } else {
            if nextButton.isHidden {
                nextButton.alpha = 0
                nextButton.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.nextButton.alpha = 1
                    self.nextButton.isHidden = false
                    self.buttonContentView.alpha = 0
                } completion: { _ in
                    self.buttonContentView.alpha = 0
                    self.buttonContentView.isHidden = true
                }
            }
        }
    }

    private func createSlides() -> [Slide] {
        let slide1 = Slide(backgroundImage: KDriveResourcesAsset.background1.image,
                           illustrationImage: KDriveResourcesAsset.illuDevices.image,
                           animationName: "illu_devices",
                           title: KDriveResourcesStrings.Localizable.onBoardingTitle1,
                           description: KDriveResourcesStrings.Localizable.onBoardingDescription1)

        let slide2 = Slide(backgroundImage: KDriveResourcesAsset.background2.image,
                           illustrationImage: KDriveResourcesAsset.illuCollab.image,
                           animationName: "illu_collab", title: KDriveResourcesStrings.Localizable.onBoardingTitle2,
                           description: KDriveResourcesStrings.Localizable.onBoardingDescription2)

        let slide3 = Slide(backgroundImage: KDriveResourcesAsset.background3.image,
                           illustrationImage: KDriveResourcesAsset.illuPhotos.image,
                           animationName: "illu_photos",
                           title: KDriveResourcesStrings.Localizable.onBoardingTitle3,
                           description: KDriveResourcesStrings.Localizable.onBoardingDescription3)

        return [slide1, slide2, slide3]
    }

    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }

    class func instantiate() -> OnboardingViewController {
        return Storyboard.main.instantiateViewController(withIdentifier: "OnboardingViewController") as! OnboardingViewController
    }
}

// MARK: - UICollectionView Delegate

extension OnboardingViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return slides.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: SlideCollectionViewCell.self, for: indexPath)
        cell.isSmallDevice = view.frame.height < 600
        cell.configureCell(slide: slides[indexPath.row], isSmallDevice: view.frame.height < 600)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let cell = cell as? SlideCollectionViewCell {
            cell.illustrationAnimationView.currentProgress = 0
            cell.illustrationAnimationView.play()
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(scrollView.contentOffset.x / view.frame.width)
        pageControl.currentPage = Int(pageIndex)
        updateButtonsState()
    }
}

// MARK: - Infomaniak Login Delegate

extension OnboardingViewController: InfomaniakLoginDelegate {
    func didCompleteLoginWith(code: String, verifier: String) {
        MatomoUtils.track(eventWithCategory: .account, name: "loggedIn")
        let previousAccount = accountManager.currentAccount
        signInButton.setLoading(true)
        registerButton.isEnabled = false
        Task {
            do {
                _ = try await accountManager.createAndSetCurrentAccount(code: code, codeVerifier: verifier)
                guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
                    throw DriveError.NoDriveError.noDriveFileManager
                }
                signInButton.setLoading(false)
                registerButton.isEnabled = true
                MatomoUtils.connectUser()
                goToMainScreen(with: currentDriveFileManager)
            } catch {
                DDLogError("Error on didCompleteLoginWith \(error)")

                if let previousAccount {
                    accountManager.switchAccount(newAccount: previousAccount)
                }
                signInButton.setLoading(false)
                registerButton.isEnabled = true
                if let noDriveError = error as? InfomaniakCore.ApiError, noDriveError.code == DriveError.noDrive.code {
                    let driveErrorVC = DriveErrorViewController.instantiate(errorType: .noDrive, drive: nil)
                    present(driveErrorVC, animated: true)
                } else if let driveError = error as? DriveError,
                          driveError == .noDrive
                          || driveError == .productMaintenance
                          || driveError == .driveMaintenance
                          || driveError == .blocked {
                    let errorViewType: DriveErrorViewController.DriveErrorViewType
                    switch driveError {
                    case .productMaintenance, .driveMaintenance:
                        errorViewType = .maintenance
                    case .blocked:
                        errorViewType = .blocked
                    default:
                        errorViewType = .noDrive
                    }
                    let driveErrorVC = DriveErrorViewController.instantiate(errorType: errorViewType, drive: nil)
                    present(driveErrorVC, animated: true)
                } else {
                    let metadata = [
                        "Underlying Error": error.asAFError?.underlyingError.debugDescription ?? "Not an AFError"
                    ]
                    SentryDebug.capture(error: error, context: metadata, contextKey: "Error")
                    okAlert(
                        title: KDriveResourcesStrings.Localizable.errorTitle,
                        message: KDriveResourcesStrings.Localizable.errorConnection
                    )
                }
            }
            endBackgroundTask()
        }
    }

    func didFailLoginWith(error: Error) {
        signInButton.setLoading(false)
        registerButton.isEnabled = true
    }
}
