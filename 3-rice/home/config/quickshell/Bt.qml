// Bt.qml -- singleton: Bluetooth on / off that is REMEMBERED across reboots (user 2026-09-28: "remember last state").
// Off = the radio's soft kill-switch (rfkill block) + adapter off; on = unblock + adapter on. systemd-rfkill saves the
// kill-switch at shutdown and restores it at boot, and BlueZ powers an unblocked adapter by itself, so Bluetooth comes
// back exactly as you left it. (Only switching the adapter off was forgotten: BlueZ turned it on at every boot.)
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    function power(ad, on) {
        if (on) {
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"])
            Qt.callLater(() => { if (ad) ad.enabled = true })
        } else {
            if (ad) ad.enabled = false
            Quickshell.execDetached(["rfkill", "block", "bluetooth"])
        }
    }
}
