// SetNotify.qml -- Settings > Notifications: do not disturb, history, a test; calendar: holidays, your items.
import QtQuick
import Quickshell

SetPage {
    id: page

    SetGroup { title: "Notifications" }
    SetRow {
        title: "Do not disturb"
        desc: "Notifications are kept in the list but not shown in the notch (critical ones still are)."
        Seg { options: ["Off", "On"]; current: Notifs.dnd ? 1 : 0; onPicked: (i) => Notifs.dnd = (i === 1) }
    }
    SetRow {
        title: "History"
        desc: Notifs.list.length + " notification" + (Notifs.list.length === 1 ? "" : "s") + " in the bell list."
        SetButton { text: "Clear all"; warn: true; enabled: Notifs.list.length > 0; onClicked: Notifs.clearAll() }
    }
    SetRow {
        title: "Test"
        desc: "Send a sample notification to see how it looks."
        SetButton { text: "Send test"; icon: "󰂚"; onClicked: Quickshell.execDetached(["notify-send", "-a", "Settings", "Test notification", "This is how notifications look in the current theme."]) }
    }

    SetGroup { title: "Calendar" }
    SetRow {
        title: "Holidays"
        desc: "India, from Google's public holiday calendar; refreshed every 30 days (" + Object.keys(Agenda.holidays).length + " days known)."
    }
    SetRow {
        title: "Your events, reminders and alarms"
        desc: Agenda.items.length + " saved. Add new ones in the calendar (click the clock in the notch); remove any here."
        SetButton { text: "Open calendar"; icon: "󰃭"; onClicked: { page.host.close(); Quickshell.execDetached(["qs", "ipc", "call", "notch", "open", "clock"]) } }
    }
    Repeater {
        model: Agenda.items.slice().sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time))
        delegate: SetRow {
            required property var modelData
            readonly property var kinds: ({ event: "󰃭 Event", reminder: "󰂚 Reminder", alarm: "󰀠 Alarm" })
            title: modelData.text
            desc: (kinds[modelData.kind] || modelData.kind) + "  ·  " + (modelData.repeat === "daily" ? "every day from " + modelData.date
                  : modelData.repeat === "yearly" ? "every year on " + modelData.date.substr(5) : modelData.date) + (modelData.time ? " at " + modelData.time : ", all day")
            SetButton { text: "Remove"; warn: true; onClicked: Agenda.remove(modelData.id) }
        }
    }
}
