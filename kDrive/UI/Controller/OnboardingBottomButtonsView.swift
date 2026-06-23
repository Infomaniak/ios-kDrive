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

import DesignSystem
import InfomaniakDI
import InterAppLogin
import kDriveCore
import SwiftUI

struct OnboardingBottomButtonsView: View {
    @InjectService private var appNavigable: AppNavigable
    @InjectService private var accountManager: AccountManageable

    @ObservedObject var loginDelegateHandler: LoginDelegateHandler

    var body: some View {
        ContinueWithAccountView(isLoading: loginDelegateHandler.isLoading, excludingUserIds: accountManager.accountIds) {
            appNavigable.showLogin(delegate: loginDelegateHandler)
        } onLoginWithAccountsPressed: { accounts in
            loginDelegateHandler.login(with: accounts)
        } onCreateAccountPressed: {
            appNavigable.showRegister(delegate: loginDelegateHandler)
        }
        .padding(IKPadding.large)
        .ikButtonTheme(.drive)
    }
}
