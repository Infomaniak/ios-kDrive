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

import UIKit
import kDriveCore
import Lottie

class MigrationViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var migrationDoneButton: UIButton!
    @IBOutlet weak var migrationProgressView: UIView!
    @IBOutlet weak var buttonView: UIView!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var migrationFailedLabel: UILabel!

    private var migrationResult: MigrationResult?
    private var slides: [Slide] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(cellView: SlideCollectionViewCell.self)

        setupViewForMigration()
    }

    private func setupViewForMigration() {
        buttonView.alpha = 0
        migrationProgressView.alpha = 1
        migrationProgressView.isHidden = false
        buttonView.isHidden = true

        let migrationSlide = Slide(backgroundImage: KDriveAsset.background1.image,
            illustrationImage: KDriveAsset.illuDevices.image,
            animationName: "illu_devices",
            title: "migrationTitle".localized,
            description: KDriveStrings.Localizable.migrationDescription)

        slides = [migrationSlide]
        MigrationHelper.migrate { (result) in
            DispatchQueue.main.async { [self] in
                migrationResult = result
                buttonView.alpha = 0
                buttonView.isHidden = false
                retryButton.isHidden = result.success
                migrationFailedLabel.isHidden = result.success

                UIView.animate(withDuration: 0.5) {
                    self.buttonView.alpha = 1
                    self.migrationProgressView.alpha = 0
                } completion: { (done) in
                    self.migrationProgressView.isHidden = true
                    self.buttonView.isHidden = false
                }
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { (context) in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        } completion: { (context) in
            let indexPath = IndexPath(row: 0, section: 0)
            self.collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
    }

    @IBAction func migrationDoneButtonPressed(_ sender: Any) {
        MigrationHelper.cleanup()
        if migrationResult?.success == true {
            UserDefaults.store(firstLaunch: false)
            UserDefaults.store(numberOfConnection: 1)
            (UIApplication.shared.delegate as! AppDelegate).setRootViewController(MainTabViewController.instantiate(), animated: true)
            if migrationResult?.photoSyncEnabled == true {
                let mainTabViewController = MainTabViewController.instantiate()
                (UIApplication.shared.delegate as! AppDelegate).setRootViewController(mainTabViewController, animated: true)
                let floatingPanelViewController = MigratePhotoSyncSettingsFloatingPanelViewController.instantiatePanel()
                (floatingPanelViewController.contentViewController as? MigratePhotoSyncSettingsFloatingPanelViewController)?.actionHandler = { sender in
                    let photoSyncSettingsVC = PhotoSyncSettingsViewController.instantiate()
                    guard let currentVC = mainTabViewController.selectedViewController as? UINavigationController else {
                        return
                    }
                    currentVC.dismiss(animated: true)
                    currentVC.setInfomaniakAppearanceNavigationBar()
                    currentVC.pushViewController(photoSyncSettingsVC, animated: true)
                }
                mainTabViewController.present(floatingPanelViewController, animated: true)
            }
        } else {
            (UIApplication.shared.delegate as! AppDelegate).setRootViewController(OnboardingViewController.instantiate(), animated: true)
        }
    }

    @IBAction func retryButtonPressed(_ sender: Any) {
        setupViewForMigration()
    }

    class func instantiate() -> MigrationViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MigrationViewController") as! MigrationViewController
    }

}

// MARK: - UICollectionView Delegate

extension MigrationViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return slides.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: SlideCollectionViewCell.self, for: indexPath)
        cell.configureCell(slide: slides[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? SlideCollectionViewCell {
            cell.illustrationAnimationView.currentProgress = 0
            cell.illustrationAnimationView.play()
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }

}
