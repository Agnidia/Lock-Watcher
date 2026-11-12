"""Writes the app's JSON-encoded settings groups into the screenshot-only defaults plist.

usage: prefs.py <plist> <page>   where <page> is a SettingsPage raw value: capture, snapshot, options, sync, notifications.
"""
import json, plistlib, sys, time

path, page = sys.argv[1], sys.argv[2]
apple_ref = 978307200
groups = {
    "OptionsSettings": dict(isFirstLaunch=False, keepLastActionsCount=10, isSaveSnapshotToDisk=False,
                            addLocationToSnapshot=True, addIPAddressToSnapshot=True, addTraceRouteToSnapshot=False,
                            traceRouteServer="", isProtected=False,
                            authSettings=dict(biometrics=False, watch=False, devicePassword=False)),
    "TriggerSettings": dict(isUseSnapshotOnWakeUp=True, isUseSnapshotOnLogin=True, isUseSnapshotOnWrongPassword=False,
                            isUseSnapshotOnSwitchToBatteryPower=False, isUseSnapshotOnUSBMount=True,
                            isUseSnapshotOnDisplayAttach=True, isUseSnapshotOnLocationChange=True,
                            isUseSnapshotOnLockedInput=True, lockedInputDelay=5),
    "SyncSettings": dict(isSaveSnapshotToDisk=False, isSendNotificationToMail=False, mailRecipient="",
                         isICloudSyncEnable=True, isDropboxEnable=False, dropboxName="",
                         isUseSnapshotLocalNotification=True, isSendPushEnable=True),
    "SnapshotSettings": dict(outputType="photo", videoDuration=3, quality=75),
    "RetentionSettings": dict(keepFiles="oneWeek", startDate=time.time() - 86400 * 30 - apple_ref, isUpgradeNoticeShown=True),
    # The companion invitation is shown once; a set date keeps it out of the shots.
    "UISettings": dict(lastSettingsPage=page, companionPromptShownAt=time.time() - apple_ref),
}
data = {k: json.dumps(v).encode() for k, v in groups.items()}
with open(path, "wb") as f:
    plistlib.dump(data, f)
