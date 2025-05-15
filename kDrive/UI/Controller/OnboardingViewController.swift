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
import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import Lottie
import UIKit

class OnboardingViewController: UIViewController {
    @LazyInjectService private var appNavigable: AppNavigable
    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var infomaniakLogin: InfomaniakLoginable
    @LazyInjectService private var matomo: MatomoUtils

    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

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
            self.endBackgroundTask()
        }
        loginDelegateHandler.didFailLoginWithErrorCallback = { [weak self] _ in
            guard let self else { return }
            self.signInButton.setLoading(false)
            self.registerButton.isEnabled = true
        }
        return loginDelegateHandler
    }()

    @IBOutlet var navigationBar: UINavigationBar!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var pageControl: UIPageControl!
    @IBOutlet var nextButton: UIButton!
    @IBOutlet var signInButton: UIButton!
    @IBOutlet var registerButton: UIButton!
    @IBOutlet var buttonContentView: UIView!
    @IBOutlet var closeBarButtonItem: UIBarButtonItem!

    @IBOutlet var collectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var signInButtonHeight: NSLayoutConstraint!
    @IBOutlet var nextButtonHeight: NSLayoutConstraint!
    @IBOutlet var registerButtonHeight: NSLayoutConstraint!

    var addUser = false
    var slides: [Slide] = []

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
        matomo.track(view: ["Onboarding"])
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
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Login WebView") { [weak self] in
            SentryDebug.capture(message: "Background task expired while logging in")
            self?.endBackgroundTask()
        }
        appNavigable.showLogin(delegate: loginDelegateHandler)
    }

    @IBAction func registerButtonPressed(_ sender: Any) {
        appNavigable.showRegister(delegate: loginDelegateHandler)
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        dismiss(animated: true)
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
