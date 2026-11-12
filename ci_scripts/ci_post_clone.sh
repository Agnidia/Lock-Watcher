#!/bin/sh

set -e

# Archives become TestFlight and App Store builds, whose companions register for production only, so the sandbox key stays out of them.
if [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]; then
    SECRETS_APNS_SANDBOX_KEY_ID=""
    SECRETS_APNS_SANDBOX_KEY_P8_BASE64=""
    echo "APNs sandbox key omitted (archive build)"
fi

cat <<EOF > "$CI_PRIMARY_REPOSITORY_PATH/Source/Application/Secrets.swift"
import Foundation

enum Secrets {
    static let soul = "${SECRETS_SOUL}"
    static let keychainId = "${SECRETS_KEYCHAIN_ID}"
    static let appKey = "${SECRETS_APP_KEY}"
    static let userDefaultsId = "${SECRETS_USER_DEFAULTS_ID}"
    static let dropboxKey = "${SECRETS_DROPBOX_KEY}"
    static let apnsTeamId = "${SECRETS_APNS_TEAM_ID}"
    static let apnsSandboxKeyId = "${SECRETS_APNS_SANDBOX_KEY_ID}"
    static let apnsSandboxKeyP8Base64 = "${SECRETS_APNS_SANDBOX_KEY_P8_BASE64}"
    static let apnsProductionKeyId = "${SECRETS_APNS_PRODUCTION_KEY_ID}"
    static let apnsProductionKeyP8Base64 = "${SECRETS_APNS_PRODUCTION_KEY_P8_BASE64}"
}
EOF

echo "✅ Secrets.swift created"

defaults delete com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile
defaults delete com.apple.dt.Xcode IDEDisableAutomaticPackageResolution
