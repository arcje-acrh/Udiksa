// Weather.qml -- singleton: today's weather + the next days from Open-Meteo (free, no account or key). The place is
// picked in Settings > Date & language (search by city name: Open-Meteo's geocoding), saved in Prefs.weather; nothing
// is fetched until a place is set. Refreshed every 30 min. Shown in the calendar panel (Weather tab) and, small,
// next to the date in the notch.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var w: Prefs.v.weather
    readonly property bool wanted: w.on !== false && w.name !== "" && (w.lat !== 0 || w.lon !== 0)
    readonly property bool fahrenheit: w.units === "f"

    property bool ok: false
    property string error: ""
    property real updated: 0
    property var now: ({})                 // { temp, feels, humidity, wind, code, day }
    property var days: []                  // [{ date, code, max, min, rain }]
    property var sun: ({})                 // { rise, set } today, "HH:mm"

    // Open-Meteo weather codes (WMO) -> icon + words
    function icon(code, day) {
        if (code === 0) return day === false ? "󰖔" : "󰖙"
        if (code <= 2) return day === false ? "󰼱" : "󰖕"
        if (code === 3) return "󰖐"
        if (code === 45 || code === 48) return "󰖑"
        if (code >= 51 && code <= 57) return "󰖗"
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "󰖖"
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "󰖘"
        if (code >= 95) return "󰙾"
        return "󰖐"
    }
    function words(code) {
        return ({ 0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Cloudy", 45: "Fog", 48: "Icy fog",
                  51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle", 56: "Freezing drizzle", 57: "Freezing drizzle",
                  61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain",
                  71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains", 80: "Showers", 81: "Showers",
                  82: "Heavy showers", 85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm, hail",
                  99: "Thunderstorm, hail" })[code] || "—"
    }
    function deg(t) { return Math.round(t) + "°" }

    function refresh() {
        if (!wanted) { ok = false; return }
        const q = "latitude=" + w.lat + "&longitude=" + w.lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&timezone=auto&forecast_days=5" + (fahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "")
        fetch.command = ["curl", "-sf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?" + q]
        fetch.running = true
    }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text), c = d.current, y = d.daily
                    root.now = { temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
                                 wind: c.wind_speed_10m, windUnit: root.fahrenheit ? "mph" : "km/h", code: c.weather_code, day: c.is_day === 1 }
                    const ds = []
                    for (let i = 0; i < y.time.length; i++)
                        ds.push({ date: y.time[i], code: y.weather_code[i], max: y.temperature_2m_max[i], min: y.temperature_2m_min[i],
                                  rain: y.precipitation_probability_max ? y.precipitation_probability_max[i] : null })
                    root.days = ds
                    root.sun = { rise: (y.sunrise[0] || "").slice(11, 16), set: (y.sunset[0] || "").slice(11, 16) }
                    root.ok = true; root.error = ""; root.updated = Date.now()
                } catch (e) { root.error = "No weather data" }
            }
        }
        onExited: (code) => { if (code !== 0) root.error = "Offline" }
    }
    Timer { interval: 30 * 60 * 1000; repeat: true; running: root.wanted; onTriggered: root.refresh() }
    onWantedChanged: refresh()
    Component.onCompleted: refresh()
    readonly property string key: w.lat + "," + w.lon + "," + w.units
    onKeyChanged: refresh()

    // ---------- place search (Settings) ----------
    property var found: []                 // [{ name, label, lat, lon }]
    property bool searching: false
    function search(name) {
        if (name.trim().length < 2) { found = []; return }
        searching = true
        geo.command = ["curl", "-sf", "--max-time", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search",
                       "--data-urlencode", "name=" + name.trim(), "-d", "count=8", "-d", "language=en", "-d", "format=json"]
        geo.running = true
    }
    Process {
        id: geo
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.found = (JSON.parse(text).results || []).map(r => ({
                        name: r.name, lat: r.latitude, lon: r.longitude,
                        label: [r.name, r.admin1, r.country].filter(x => x).join(", ") }))
                } catch (e) { root.found = [] }
            }
        }
        onExited: root.searching = false
    }
    function choose(place) {
        Prefs.set(["weather", "name"], place.name)
        Prefs.set(["weather", "lat"], place.lat)
        Prefs.set(["weather", "lon"], place.lon)
        found = []
    }
}
