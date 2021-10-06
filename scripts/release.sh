#!/usr/bin/env bash

if [ -z "$APPSTORECONNECT_USER" ]; then
    echo "\$APPSTORECONNECT_USER is empty, please add a user and a password"
    echo "Add user using: export APPSTORECONNECT_USER=<user>"
    echo "Add password to keychain using: xcrun altool --store-password-in-keychain-item appstoreconnect-password -u \$APPSTORECONNECT_USER -p <password>"
else
    SCRIPT_DIR=`dirname "$0"`
    cd $SCRIPT_DIR
    cd ..

    echo "----- Tuist - Xcode project generation -----"
    tuist generate
    if [ $? -ne 0 ]; then
        echo "Tuist generate failed, exiting"
        exit $?
    fi

    rm -R ./release
    mkdir ./release

    ARCHIVE_PATH=./release/kDrive.xcarchive
    EXPORT_PATH=./release/kDrive-release

    echo "----- Xcode build - Archive -----"
    xcodebuild -workspace kDrive.xcworkspace -scheme kDrive -archivePath $ARCHIVE_PATH archive
    if [ $? -ne 0 ]; then
        echo "Xcode build failed, exiting"
        exit $?
    fi
    
    echo "----- Xcode build - Export archive -----"
    xcodebuild -exportArchive -archivePath $ARCHIVE_PATH -exportPath $EXPORT_PATH -exportOptionsPlist $SCRIPT_DIR/exportOptions.plist
    if [ $? -ne 0 ]; then
        echo "Xcode export archive failed, exiting"
        exit $?
    fi
    
    echo "----- AppStoreConnect - Validate -----"
    xcrun altool --validate-app -f ./release/kDrive-release/kDrive.ipa --type ios -u $APPSTORECONNECT_USER -p "@keychain:appstoreconnect-password"
    if [ $? -ne 0 ]; then
        echo "AppStoreConnect validation failed, exiting"
        exit $?
    fi
    
    echo "----- AppStoreConnect - Upload -----"
    xcrun altool --upload-app -f ./release/kDrive-release/kDrive.ipa --type ios -u $APPSTORECONNECT_USER -p "@keychain:appstoreconnect-password"
    if [ $? -ne 0 ]; then
        echo "AppStoreConnect upload failed, exiting"
        exit $?
    fi
fi

