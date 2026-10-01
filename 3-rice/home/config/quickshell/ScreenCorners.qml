// ScreenCorners.qml -- rounded screen corners (user 2026-10-02): a small black arc in each corner of every screen, with
// the same radius as the windows' OUTER edge = decoration:rounding + general:border_size (the border is drawn around the
// rounded corner, so a window's visible curve is that much rounder), so the screen reads like one big rounded tile.
// Four tiny click-through overlay windows per screen, drawn once (nothing runs). Radius: Corners.qml; hidden while game
// mode is on (rounding 0 there).
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    readonly property real r: Corners.r

    component Corner: PanelWindow {
        id: w
        property bool right: false
        property bool bottom: false
        property var scr
        screen: scr
        visible: root.r > 0 && !Modes.game
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "udiksa-corner"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: !bottom; bottom: bottom; left: !right; right: right }
        implicitWidth: root.r; implicitHeight: root.r
        color: "transparent"
        mask: Region {}                              // never takes the mouse
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // drawn for the top-left corner, turned for the others
            rotation: w.bottom ? (w.right ? 180 : 270) : (w.right ? 90 : 0)
            ShapePath {
                fillColor: "black"; strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: root.r; y: 0 }
                PathArc { x: 0; y: root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: one
            required property var modelData
            Corner { scr: one.modelData }
            Corner { scr: one.modelData; right: true }
            Corner { scr: one.modelData; bottom: true }
            Corner { scr: one.modelData; right: true; bottom: true }
        }
    }
}
