// Weather.qml -- singleton: today's weather + the next days from Open-Meteo (free, no account or key). The place is
// picked in Settings > Date & language (search by city name: Open-Meteo's geocoding), saved in Prefs.weather; nothing
// is fetched until a place is set. Refreshed every 30 min. Shown only in the clock panel (Weather tab + a line in Day).
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
    Timer { interval: 60 * 1000; repeat: true; running: root.wanted && !root.ok; onTriggered: root.refresh() }   // offline / failed: retry every minute
    onWantedChanged: refresh()
    Component.onCompleted: refresh()
    readonly property string key: w.lat + "," + w.lon + "," + w.units
    onKeyChanged: refresh()

    // ---------- places (Settings) ----------
    // Indian cities to pick from in Settings > Date & language (any other place: use the search below it)
    readonly property var india: [
        { name: "Agra", lat: 27.18, lon: 78.02 },
        { name: "Ahmedabad", lat: 23.02, lon: 72.57 },
        { name: "Amritsar", lat: 31.63, lon: 74.87 },
        { name: "Bangalore", lat: 12.97, lon: 77.59 },
        { name: "Bhavnagar", lat: 21.76, lon: 72.15 },
        { name: "Bhopal", lat: 23.26, lon: 77.41 },
        { name: "Bhubaneswar", lat: 20.3, lon: 85.82 },
        { name: "Chandigarh", lat: 30.73, lon: 76.78 },
        { name: "Chennai", lat: 13.08, lon: 80.27 },
        { name: "Coimbatore", lat: 11.02, lon: 76.96 },
        { name: "Dehradun", lat: 30.32, lon: 78.03 },
        { name: "Delhi", lat: 28.61, lon: 77.21 },
        { name: "Gandhinagar", lat: 23.22, lon: 72.65 },
        { name: "Goa (Panaji)", lat: 15.49, lon: 73.83 },
        { name: "Guwahati", lat: 26.14, lon: 91.74 },
        { name: "Hyderabad", lat: 17.39, lon: 78.49 },
        { name: "Indore", lat: 22.72, lon: 75.86 },
        { name: "Jaipur", lat: 26.91, lon: 75.79 },
        { name: "Jamnagar", lat: 22.47, lon: 70.07 },
        { name: "Jodhpur", lat: 26.24, lon: 73.02 },
        { name: "Kanpur", lat: 26.45, lon: 80.35 },
        { name: "Kochi", lat: 9.93, lon: 76.27 },
        { name: "Kolkata", lat: 22.57, lon: 88.36 },
        { name: "Leh", lat: 34.15, lon: 77.58 },
        { name: "Lucknow", lat: 26.85, lon: 80.95 },
        { name: "Ludhiana", lat: 30.9, lon: 75.86 },
        { name: "Madurai", lat: 9.93, lon: 78.12 },
        { name: "Mangaluru", lat: 12.91, lon: 74.86 },
        { name: "Mumbai", lat: 19.08, lon: 72.88 },
        { name: "Mysuru", lat: 12.3, lon: 76.64 },
        { name: "Nagpur", lat: 21.15, lon: 79.09 },
        { name: "Nashik", lat: 19.99, lon: 73.79 },
        { name: "Patna", lat: 25.59, lon: 85.14 },
        { name: "Puducherry", lat: 11.93, lon: 79.83 },
        { name: "Pune", lat: 18.52, lon: 73.86 },
        { name: "Raipur", lat: 21.25, lon: 81.63 },
        { name: "Rajkot", lat: 22.3, lon: 70.8 },
        { name: "Ranchi", lat: 23.34, lon: 85.31 },
        { name: "Shimla", lat: 31.1, lon: 77.17 },
        { name: "Srinagar", lat: 34.08, lon: 74.8 },
        { name: "Surat", lat: 21.17, lon: 72.83 },
        { name: "Thiruvananthapuram", lat: 8.52, lon: 76.94 },
        { name: "Udaipur", lat: 24.59, lon: 73.71 },
        { name: "Vadodara", lat: 22.31, lon: 73.18 },
        { name: "Varanasi", lat: 25.32, lon: 83.01 },
        { name: "Visakhapatnam", lat: 17.69, lon: 83.22 }
    ]

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
