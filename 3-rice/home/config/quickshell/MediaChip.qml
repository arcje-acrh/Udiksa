// MediaChip.qml -- small "now playing" item on the left of the notch (music icon + title).
// Grey icon only when nothing plays. Hover or click opens the media panel (MediaPanel.qml).
import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root
    property bool active: false            // its panel is open (coral)
    property int maxTextWidth: 160
    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length ? ps[0] : null
    }
    width: row.width; height: row.height
    Row {
        id: row
        spacing: 7
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.player && root.player.isPlaying ? "󰝚" : "󰎊"
            color: root.active ? Theme.coral : (root.player ? Theme.text : Theme.dim)
            font.family: Theme.font; font.pixelSize: 14
        }
        Text {
            visible: root.player !== null && text !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTextWidth)
            elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle || "") : ""
            color: root.active ? Theme.coral : Theme.muted
            font.family: Theme.font; font.pixelSize: 12
        }
    }
}
