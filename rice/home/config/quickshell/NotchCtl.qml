// NotchCtl.qml -- singleton: open/close notch panels from outside (keybinds, scripts):
//   qs ipc call notch open <battery|power|volume|wifi|bluetooth|clock|media>
//   qs ipc call notch toggle <id>      qs ipc call notch close
// A panel opened this way stays open ("pinned") until the mouse has been in the notch and left, or Esc.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    signal openRequested(string id)
    signal toggleRequested(string id)
    signal closeRequested()
    IpcHandler {
        target: "notch"
        function open(id: string): void { root.openRequested(id) }
        function toggle(id: string): void { root.toggleRequested(id) }
        function close(): void { root.closeRequested() }
    }
}
