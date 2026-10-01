// CornerArcs.qml -- the four black corner arcs drawn INSIDE a full-screen surface (ThemeSwitcher.qml), for surfaces
// that would cover the desktop's own ScreenCorners windows. Put it last (on top): CornerArcs { r: Corners.r }
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property real r: Corners.r
    anchors.fill: parent
    visible: r > 0
    Repeater {
        model: [[0, 0, 0], [1, 0, 90], [1, 1, 180], [0, 1, 270]]      // x right?, y bottom?, rotation
        delegate: Shape {
            required property var modelData
            x: modelData[0] ? root.width - root.r : 0
            y: modelData[1] ? root.height - root.r : 0
            width: root.r; height: root.r
            rotation: modelData[2]
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "black"; strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: root.r; y: 0 }
                PathArc { x: 0; y: root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
