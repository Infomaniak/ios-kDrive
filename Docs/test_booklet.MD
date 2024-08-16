# Test booklet for the native kDrive app

Each test is listed with a standard definition 
- Name
- Goal
- Pre-conditions
- Steps
- Expected results

All tests are to be performed in production.

## Authentication

#### Login

Goal: 
- Verify that the user can successfully log in with valid credentials.

Pre-conditions: 
- A user account with valid credentials (username and password) exists.
- Completely remove previous versions of kDrive
- Clean install from AppStore
- Device is connected to the internet.

Steps:
- Launch the app.
- Navigate to the login screen.
- Enter a valid username and password.
- Tap the "Login" button.

Expected results
- The app should log in the user and navigate to the home screen without any errors.

#### Log-out

Goal: 
- Verify that the user can log out from the app.

Pre-conditions: 
- The user is logged in.
- Internet connectivity is __optional__

Steps:
- Navigate to the profile or settings section.
- Locate and tap the "Logout" button.
- Confirm the logout action if prompted.

Expected results: 
- The user should be logged out and redirected to the login screen.

#### Register

Goal: 
- Verify that the user can create a new account in the app.

Pre-conditions: 
- Completely remove previous versions of kDrive
- Clean install from AppStore
- An email not in use for kSuite
- Internet connectivity

Steps:
- Navigate to the “create a new account” screen
- Go through the process
- Finish it

Expected results: 
- The user should be logged in the app.

#### Account switch

Goal: 
- Verify that a user can switch between multiple accounts without issues.

Pre-conditions:
- The user is currently logged in to multiple accounts.
- Internet connectivity is __optional__

Steps:
- Navigate to the profile or settings section.
- Locate the "Switch Account" option.
- Select "Switch Account."
- Select the desired account

Expected results
- The app should log in to the second account and display the appropriate content for that account. 
- Content should be up-to-date if internet connectivity is present.

#### Drive switch

Goal: 
- A user should be able to switch between drives for a single account.

Pre-conditions:
- A user with multiple drives is connected to kDrive
- Internet connectivity is __optional__

Steps:
- Navigate to the preferences screen
- Select another Drive with the dedicated button

Expected results:
- Content refreshes with the selected Drive

## Photo backup

#### Photo backup from scratch

Goal: 
- Ensure that photos from the device are automatically synchronized with the cloud storage.

Pre-conditions:
- Device is connected to the internet.
- Completely remove previous versions of kDrive
- The app is freshly downloaded form the AppStore
- The user is logged in
- Sufficient space in the user’s Drive.
- Backup options can be selected if you think it adds value to the test.

Steps:
- Enable photo backup in the app settings. Sync should start after a short time.
- Wait for the synchronization to complete with the app opened.

Expected Results:
- All the device photos should be uploaded and appear in the app's gallery or cloud storage. 
- The app should display a message confirming that the synchronization is complete.
- The phone does not lock itself until the uploads are finished.

#### Incremental photo backup

Goal: 
- Ensure that _new_ photos from the device are automatically synchronized with the cloud storage.

Pre-conditions:
- The user is logged in.
- Device is connected to the internet.
- App lock should be turned on in the app’s settings, as we tend to not test with “app lock” enabled
- The app has permission to access photos on the device.
- The photo backup feature is enabled in the app settings.
- The photo backup has finished the initial sync with success.
- Sufficient space in the user’s Drive.
- kDrive app is closed via app switcher

Steps:
- Take a new photo using the device's camera or ensure that there are unsynchronized photos in the gallery.
- Open the app, that will trigger the synchronization process.
- Wait for the synchronization to complete with the app open.

Expected Results:
- The new or unsynchronized photos should be uploaded and appear in the app's gallery. 
- The app should display a message confirming that the synchronization is complete.
- The phone does not lock itself until the uploads are finished.

#### Incremental photo backup in Background (iOS Specific)

Goal:
- Ensure that new pictures are synced in the background.

Pre-conditions:
- Completely remove previous versions of kDrive
- Clean app install from the App Store 
- The user is logged in.
- The app has permission to access photos on the device.
- Photo backup is configured
- Initial Photo backup is finished and successful.
- kDrive app is closed via app switcher
- The internet connectivity is stable, in wifi.

Steps:
- Take a couple of picture with the camera
- Lock the iPhone
- Keep the iPhone plugged in for an entire night.

Expected results
- In the morning, the pictures have been updated.
- A notification was produced.

## File uploads

#### Single file upload

Goal:
- Ensure that the user can upload a file successfully.

Pre-conditions:
- The user is logged in.
- Device is connected to the internet.
- Sufficient space remaining on the current Drive.

Steps:
- Navigate to a folder where file uploads are allowed
- Tap the big “+” button.
- Select a file from the device's storage or the photo roll.
- Confirm the upload.
- Keep the app in the foreground and wait for completion 

Expected results
- The selected file should upload successfully.
- The app should display a confirmation or the uploaded file in the relevant section.
- The device does not lock itself until the uploads are finished.

#### Many file upload

Goal:
- Ensure that the user can upload a collection of files successfully.
- 
Pre-conditions:
- The user is logged in.
- Device is connected to the internet.
- Sufficient space remaining on the current Drive.

Steps:
- Navigate to a folder where file uploads are allowed
- Tap the big “+” button.
- Select at least 20 files from the device's storage or the photo roll.
- Confirm the upload.
- Keep the app in the foreground and wait for completion 

Expected results
- The selected files should upload successfully.
- The app should display a confirmation or the number of uploaded file in a notification.
- The phone should not overheat.
- The device does not lock itself until the uploads are finished.

#### Background large file upload

Goal: 
- Verify that files continue to upload in the background if the user navigates away from the app.

Pre-conditions:
- The user is logged in.
- Device is connected to the internet.
- Sufficient space remaining on the current Drive.
- The app is configured to allow background uploads. (Default on iOS on a clean install)

Steps
- Navigate to a folder where file uploads are allowed
- Start uploading a large file that will take some time to complete. (Eg. 500MB video)
- Minimise the app or switch to another app while the upload is in progress.
- Wait for a few minutes.

Expected results: 
- Either:
    - A notification brings you back into the app to finish the upload
        - Tap it, it should then finish without issues.
    - A notification informs you the upload was finished.
        - Tap it, you should navigate to the folder it was uploaded into.

#### Restart file upload

Goal: 
- Verify that a paused upload restarts when we re-open the app.

Pre-conditions:
- The user is logged in.
- Device is connected to the internet.

Steps
- Navigate to a folder where file uploads are allowed
- Start uploading a large file that will take some time to complete. (Eg. 500MB video)
- Force stop the app with the app switcher.
- Re-open the app.

Expected results: 
- The app restarts the upload seamlessly and finishes it.
- The device does not lock itself until the uploads are finished.

#### Share extension upload

Goal:
- Ensure that the user can upload a file successfully from the share extension 

Pre-conditions:
- A user is logged in.
- Device is connected to the internet.

Steps:
- Open Safari, go to “apple.com”
- Tap the native share button.
- Select kDrive.
- Select a destination within a drive you have write access.
- Confirm the upload.

Expected results
- kDrive is expected to open and the upload should start right away.
- The upload should finish without the app going to background

## Native file provider (Files.app on iOS)

#### All drives of a user shows up

Goal:
- All drives of a user shows up in the native file explorer

Pre-conditions:
- One or Multiple users are logged in on kDrive
- Device is connected to the internet.
- “Show in Files” is toggled ON is settings/security (default)

Steps
- Open Files.app
- Tap Browse tab
- Navigate to top section

Expected results
- All drives should be listed for all logged-in users

#### List all files

Goal:
- File.app file listing should match kDrive app

Pre-conditions:
- One user is logged in on kDrive
- Device is connected to the internet.
- “Show in Files” is toggled ON is settings/security (default)

Steps
- Open Files.app
- Tap Browse tab
- Navigate to a folder with files in it.

Expected results
- Files should be matching what is visible in the kDrive app.

#### Open a file

Goal:
- File.app should be able to load a file

Pre-conditions:
- One user is logged in on kDrive
- Device is connected to the internet.
- “Show in Files” is toggled ON is settings/security (default)

Steps
- Open Files.app
- Tap Browse tab
- Navigate to a folder with pictures in it.
- Tap a picture.

Expected results
- Picture should load and be displayed (not just a preview)

#### Single file upload from Files.app

Goal:
- Ensure that the user can upload a file successfully from Files.app

Pre-conditions:
- The user is logged in.
- Device is connected to the internet.
- “Show in Files” is toggled ON is settings/security (default)

Steps:
- Copy a photo from the photo roll or copy a file from the local device in files.app
- Navigate to a folder where file uploads are allowed within the Files.app app.
- Create a new folder.
- Navigate to the new folder.
- Tap on empty space.
- Select paste.

Expected results
- The upload starts
- Then either
    - The upload finishes
    - A notification brings you to kDrive.app to finish the upload
        - The upload finishes

#### Disable Files.app

Goal:
- File.app does not show kDrive

Pre-conditions:
- One user is logged in on kDrive
- Device is connected to the internet.

Steps
- “Show in Files” is toggled __OFF__ is settings/security
- Open Files.app
- Tap Browse tab

Expected results
- Nothing kDrive related should show up.

## Share Links

#### Open a private share deeplink

Goal:
- A user should navigate to the correct destination 

Pre-conditions:
- The user is logged in.
- Device is connected to the internet.
- A private share link is made available for the current user

Steps:
- Tap the private share link (from kChat, it can be easily done)

Expected results
- kDrive opens to the correct folder within the correct drive

## Public share links

TBD when the feature is available.

- Public share link while logged in 
- Public share link while logged out
- Public share link converted to private share while logged in 
