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

import InfomaniakCore
import kDriveCore
import kDriveResources
import UIKit

final class SelectAccountViewController: UIViewController {
    let users: [UserProfile]
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(users: [UserProfile]) {
        self.users = users
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sélectionner un compte"

        setupTableView()
        setupBottomButton()
    }

    private func setupTableView() {
        view.addSubview(tableView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = KDriveCoreAsset.backgroundColor.color
        tableView.separatorStyle = .none

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.dataSource = self
        tableView.delegate = self

        tableView.register(cellView: UserAccountTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(cancelButtonPressed)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        navigationItem.largeTitleDisplayMode = .always
    }

    private func setupBottomButton() {
        let saveButton = IKLargeButton(frame: .zero)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle(KDriveCoreStrings.Localizable.buttonSave, for: .normal)
        saveButton.addTarget(self, action: #selector(cancelButtonPressed), for: .touchUpInside)

        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UIConstants.Padding.standard),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -UIConstants.Padding.standard),
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            saveButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        view.bringSubviewToFront(saveButton)
    }

    @objc func cancelButtonPressed() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension SelectAccountViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UserAccountTableViewCell.self, for: indexPath)
        cell.accessoryImageView.image = nil
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        cell.titleLabel.text = users[indexPath.row].displayName
        cell.userEmailLabel.text = users[indexPath.row].email
        users[indexPath.row].getAvatar { image in
            cell.logoImage.image = image
        }
        return cell
    }
}
