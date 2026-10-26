import WidgetKit
import SwiftUI

// Orario personale letto dal contenitore condiviso dell'app.
// weekday: 2 = lunedi ... 6 = venerdi (Calendar: 1 = domenica)

struct Lesson {
    let weekday: Int
    let start: Int // minuti da mezzanotte
    let end: Int
    let subject: String
    var room: String = ""
}

struct Slot: Identifiable {
    let start: Date
    let end: Date
    let subject: String
    var room: String = ""
    var id: TimeInterval { start.timeIntervalSince1970 }
}

enum Orario {
    // L'orario e' quello dell'utente: NOVA lo scrive in un file condiviso (App Group).
    // AltStore/SideStore rinominano il gruppo in group.<id>.<TEAMID> e lo pubblicano in ALTAppGroups,
    // ma non sempre nel bundle del widget: come ridondanza ricaviamo il nome anche dal bundle ID
    // resigned del widget (federicotaranu.site.<TEAMID>.NOVAWidget).
    static func groupIDs() -> [String] {
        var ids: [String] = []
        if let a = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { ids += a }
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Info.plist")
        if let d = NSDictionary(contentsOf: host), let a = d["ALTAppGroups"] as? [String] { ids += a }
        if let bid = Bundle.main.bundleIdentifier {
            var comps = bid.split(separator: ".").map(String.init)
            while comps.count > 2 {
                ids.append("group." + comps.joined(separator: "."))
                comps.removeLast()
            }
        }
        ids.append("group.federicotaranu.site")
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    // Nessun orario di riserva: un file vuoto resta vuoto, un file assente resta non disponibile.
    static func decode(_ data: Data) -> [Lesson]? {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = j["lessons"] as? [[String: Any]] else { return nil }
        var out: [Lesson] = []
        for o in arr {
            guard let d = o["d"] as? Int, let start = o["s"] as? Int, let end = o["e"] as? Int,
                  let name = o["n"] as? String, (2...7).contains(d), start >= 0, end <= 1440,
                  end > start, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            out.append(Lesson(weekday: d, start: start, end: end, subject: name,
                              room: (o["r"] as? String ?? "").trimmingCharacters(in: .whitespaces)))
        }
        return out
    }

    static func load() -> (lessons: [Lesson], linked: Bool) {
        for id in groupIDs() {
            guard let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
                .appendingPathComponent("timetable.json"),
                  let data = try? Data(contentsOf: u), let lessons = decode(data) else { continue }
            // Risponde all'app: il widget ha letto davvero da questo contenitore.
            if let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                try? "{\"t\":\(Date().timeIntervalSince1970)}".write(to: base.appendingPathComponent("widgetping.json"), atomically: true, encoding: .utf8)
            }
            return (lessons, true)
        }
        return ([], false)
    }

    static var lessons: [Lesson] { load().lessons }

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    static let hm: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH.mm"
        return f
    }()

    static func range(_ s: Slot) -> String {
        "\(hm.string(from: s.start)) – \(hm.string(from: s.end))"
    }

    static func slots(from day: Date, days: Int) -> [Slot] {
        let cal = calendar
        let startDay = cal.date(bySettingHour: 0, minute: 0, second: 0, of: day) ?? day
        var out: [Slot] = []
        for i in 0..<days {
            guard let d = cal.date(byAdding: .day, value: i, to: startDay) else { continue }
            let wd = cal.component(.weekday, from: d)
            for l in lessons where l.weekday == wd {
                out.append(Slot(
                    start: d.addingTimeInterval(TimeInterval(l.start * 60)),
                    end: d.addingTimeInterval(TimeInterval(l.end * 60)),
                    subject: l.subject,
                    room: l.room))
            }
        }
        return out.sorted { $0.start < $1.start }
    }

    // Date in cui la timeline va ricalcolata: ogni cambio ora piu la mezzanotte.
    static func boundaries(from now: Date, days: Int) -> [Date] {
        var dates: [Date] = [now]
        for s in slots(from: now, days: days) {
            if s.start > now { dates.append(s.start) }
            if s.end > now { dates.append(s.end) }
        }
        let cal = calendar
        for i in 1...days {
            if let d = cal.date(byAdding: .day, value: i, to: cal.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now) {
                dates.append(d)
            }
        }
        return dates.sorted()
    }
}

// MARK: - Widget 1: prossima materia con barra di avanzamento

struct OrarioEntry: TimelineEntry {
    let date: Date
    let subject: String
    let target: Date
    let barStart: Date
    let isCurrent: Bool
    let showTimer: Bool
    let range: String
    var room: String = ""
    var linked: Bool = true
    var roomSuffix: String { room.isEmpty ? "" : " · " + room }
}

enum OrarioLogic {
    static func entry(at now: Date, slots: [Slot]) -> OrarioEntry {
        let linked = Orario.load().linked
        if let cur = slots.first(where: { $0.start <= now && now < $0.end }) {
            return OrarioEntry(date: now, subject: cur.subject, target: cur.end, barStart: cur.start,
                               isCurrent: true, showTimer: true, range: Orario.range(cur), room: cur.room, linked: linked)
        }
        if let nxt = slots.first(where: { $0.start > now }) {
            let far = nxt.start.timeIntervalSince(now) > 6 * 3600
            let prevEnd = slots.last(where: { $0.end <= now })?.end ?? nxt.start.addingTimeInterval(-3600)
            return OrarioEntry(date: now, subject: nxt.subject, target: nxt.start, barStart: prevEnd,
                               isCurrent: false, showTimer: !far, range: Orario.range(nxt), room: nxt.room, linked: linked)
        }
        return OrarioEntry(date: now, subject: "ORARIO", target: now, barStart: now,
                           isCurrent: false, showTimer: false, range: Orario.lessons.isEmpty ? "Aggiungilo in NOVA" : "", linked: linked)
    }
}

struct OrarioProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrarioEntry {
        OrarioEntry(date: .now, subject: "INFO", target: .now.addingTimeInterval(1800),
                    barStart: .now.addingTimeInterval(-1800), isCurrent: true, showTimer: true, range: "8.10 – 9.50")
    }

    func getSnapshot(in context: Context, completion: @escaping (OrarioEntry) -> Void) {
        let now = Date()
        completion(OrarioLogic.entry(at: now, slots: Orario.slots(from: now, days: 5)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrarioEntry>) -> Void) {
        let now = Date()
        let slots = Orario.slots(from: now, days: 5)
        let entries = Orario.boundaries(from: now, days: 5).map { OrarioLogic.entry(at: $0, slots: slots) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}


struct TimetableUnavailableView: View {
    @Environment(\.widgetFamily) var family
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(family == .accessoryCircular || family == .accessoryInline ? "NOVA: dati assenti" : "Orario non disponibile")
                .font(.headline).minimumScaleFactor(0.5)
            if family != .accessoryCircular && family != .accessoryInline {
                Text("Apri NOVA. La condivisione con il widget non è verificata.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct NOVAOrarioView: View {
    @Environment(\.widgetFamily) var family
    var entry: OrarioEntry

    var body: some View {
        Group { if !entry.linked { TimetableUnavailableView() } else {

        if family == .accessoryInline {
            Group {
                if entry.subject == "ORARIO" && !entry.isCurrent {
                    Text("Niente lezioni")
                } else {
                    Text(entry.isCurrent ? "\(entry.subject)\(entry.roomSuffix) · \(entry.range)" : "POI \(entry.subject)\(entry.roomSuffix) · \(entry.range)")
                }
            }
            .containerBackground(Color.clear, for: .widget)
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isCurrent ? entry.subject + entry.roomSuffix : "POI: \(entry.subject)\(entry.roomSuffix)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if entry.showTimer {
                    Text(timerInterval: entry.date...entry.target, countsDown: true)
                        .font(.title2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    ProgressView(timerInterval: entry.barStart...entry.target, countsDown: false,
                                 label: { EmptyView() }, currentValueLabel: { EmptyView() })
                } else if entry.subject == "ORARIO" {
                    Text("Niente lezioni")
                        .font(.subheadline)
                } else {
                    Text(entry.target, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(Color.clear, for: .widget)
        } else {
            orarioHome
        }
    
        }}
    }

    @ViewBuilder var orarioHome: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.isCurrent ? entry.subject + entry.roomSuffix : "POI: \(entry.subject)\(entry.roomSuffix)")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if entry.showTimer {
                Text(timerInterval: entry.date...entry.target, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                ProgressView(timerInterval: entry.barStart...entry.target, countsDown: false,
                             label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(.white)
                HStack {
                    Text(entry.isCurrent ? "alla fine" : "all'inizio")
                    Spacer()
                    Text(entry.range)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                Text(entry.target, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.title3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(entry.range)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct NOVAOrarioWidget: Widget {
    let kind = "NOVAOrarioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrarioProvider()) { entry in
            NOVAOrarioView(entry: entry)
        }
        .configurationDisplayName("Prossima materia")
        .description("Conto alla rovescia fino al cambio ora, con barra di avanzamento e orario della lezione.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Widget 2: lezioni di oggi

struct DayEntry: TimelineEntry {
    let date: Date
    let slots: [Slot]
    var linked: Bool = true
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        let now = Date()
        return DayEntry(date: now, slots: Orario.slots(from: now, days: 1))
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let now = Date()
        completion(DayEntry(date: now, slots: Orario.slots(from: now, days: 1), linked: Orario.load().linked))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let linked = Orario.load().linked
        let entries = Orario.boundaries(from: now, days: 2).map {
            DayEntry(date: $0, slots: Orario.slots(from: $0, days: 1), linked: linked)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NOVAOggiView: View {
    @Environment(\.widgetFamily) var family
    var entry: DayEntry

    var body: some View {
        Group { if !entry.linked { TimetableUnavailableView() } else {

        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                if entry.slots.isEmpty {
                    Text("Nessuna lezione")
                        .font(.headline)
                } else {
                    ForEach(entry.slots.prefix(3)) { s in
                        HStack(spacing: 6) {
                            Text(Orario.hm.string(from: s.start))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(s.room.isEmpty ? s.subject : s.subject + " · " + s.room)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                    if entry.slots.count > 3 {
                        Text("+\(entry.slots.count - 3) altre")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(Color.clear, for: .widget)
        } else {
            oggiHome
        }
    
        }}
    }

    @ViewBuilder var oggiHome: some View {
        let maxRows = family == .systemSmall ? 2 : 5
        VStack(alignment: .leading, spacing: 4) {
            Text("OGGI")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if entry.slots.isEmpty {
                Spacer()
                Text("Nessuna lezione")
                    .font(.headline)
                Spacer()
            } else {
                ForEach(entry.slots.prefix(maxRows)) { s in
                    let now = entry.date
                    let live = s.start <= now && now < s.end
                    HStack(spacing: 8) {
                        Text(Orario.hm.string(from: s.start))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(live ? Color.white : Color.secondary)
                            .frame(width: 36, alignment: .leading)
                        Text(s.room.isEmpty ? s.subject : s.subject + " · " + s.room)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Spacer()
                        if live {
                            Text("ORA")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .clipShape(Capsule())
                        } else {
                            Text(Orario.hm.string(from: s.end))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(live ? Color.white.opacity(0.16) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if entry.slots.count > maxRows {
                    Text("+\(entry.slots.count - maxRows) altre")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct NOVAOggiWidget: Widget {
    let kind = "NOVAOggiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            NOVAOggiView(entry: entry)
        }
        .configurationDisplayName("Lezioni di oggi")
        .description("L'orario di oggi con i tempi di ogni lezione.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Widget 3: fine scuola

struct FineEntry: TimelineEntry {
    let date: Date
    let target: Date?
    let isToday: Bool
    var barStart: Date? = nil
    var linked: Bool = true
}

enum FineLogic {
    static func entry(at now: Date) -> FineEntry {
        let linked = Orario.load().linked
        let slots = Orario.slots(from: now, days: 5)
        guard let target = slots.last(where: { $0.end > now })?.end else {
            return FineEntry(date: now, target: nil, isToday: false, linked: linked)
        }
        let sameDay = Orario.calendar.isDate(target, inSameDayAs: now)
        let barStart = sameDay ? slots.first(where: { Orario.calendar.isDate($0.start, inSameDayAs: now) })?.start : nil
        return FineEntry(date: now, target: target, isToday: sameDay, barStart: barStart, linked: linked)
    }
}

struct FineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FineEntry {
        FineEntry(date: .now, target: .now.addingTimeInterval(3600), isToday: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (FineEntry) -> Void) {
        completion(FineLogic.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FineEntry>) -> Void) {
        let now = Date()
        var dates = Orario.boundaries(from: now, days: 5)
        if let t = FineLogic.entry(at: now).target { dates.append(t) }
        let entries = dates.sorted().map { FineLogic.entry(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NOVAFineView: View {
    @Environment(\.widgetFamily) var family
    var entry: FineEntry

    var body: some View {
        Group { if !entry.linked { TimetableUnavailableView() } else {

        if family == .accessoryCircular {
            Group {
            if let target = entry.target, entry.isToday, let start = entry.barStart, start < target {
                let total = target.timeIntervalSince(start)
                let elapsed = min(max(entry.date.timeIntervalSince(start), 0), total)
                Gauge(value: elapsed, in: 0...total) {
                    Text("FINE")
                } currentValueLabel: {
                    Text(target, format: .dateTime.hour().minute())
                        .font(.system(.title3, design: .rounded))
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                Text(entry.target == nil ? "Nessuna lezione" : "–")
                    .font(.headline)
            }
            }
            .containerBackground(Color.clear, for: .widget)
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text("FINE SCUOLA")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let target = entry.target, entry.isToday {
                    Text(timerInterval: entry.date...target, countsDown: true)
                        .font(.title2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("alle \(Orario.hm.string(from: target))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let target = entry.target {
                    Text(target, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("Nessuna lezione")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(Color.clear, for: .widget)
        } else {
            fineHome
        }
    
        }}
    }

    @ViewBuilder var fineHome: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("FINE SCUOLA")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if let target = entry.target {
                if entry.isToday {
                    Text(timerInterval: entry.date...target, countsDown: true)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("alle \(Orario.hm.string(from: target))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(target, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.title3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("ultima campanella")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Nessuna lezione")
                    .font(.title3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct NOVAFineWidget: Widget {
    let kind = "NOVAFineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FineProvider()) { entry in
            NOVAFineView(entry: entry)
        }
        .configurationDisplayName("Fine scuola")
        .description("Quanto manca all'ultima campanella.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget 4: calendario del mese (solo home screen)

struct MeseEntry: TimelineEntry {
    let date: Date
    let tests: Set<String> // "yyyy-MM-dd" con verifiche
    let hw: Set<String>    // "yyyy-MM-dd" con compiti
    let linked: Bool
}

enum MeseStore {
    static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Orario.calendar
        f.timeZone = Orario.calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Orario.calendar
        f.timeZone = Orario.calendar.timeZone
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    // Pallini condivisi dall'app in events.json (stesso ponte App Group dell'orario).
    static func load() -> (tests: Set<String>, hw: Set<String>, linked: Bool) {
        for id in Orario.groupIDs() {
            guard let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
                .appendingPathComponent("events.json"),
                  let data = try? Data(contentsOf: u),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = j["dots"] as? [[String: Any]] else { continue }
            var t = Set<String>()
            var h = Set<String>()
            for o in arr {
                guard let d = o["d"] as? String else { continue }
                if (o["k"] as? String) == "test" { t.insert(d) } else { h.insert(d) }
            }
            return (t, h, true)
        }
        return ([], [], false)
    }
}

struct MeseProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeseEntry {
        MeseEntry(date: .now, tests: [], hw: [], linked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (MeseEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeseEntry>) -> Void) {
        let now = Date()
        let cal = Orario.calendar
        let midnight = cal.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now
        let next = cal.date(byAdding: .day, value: 1, to: midnight) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> MeseEntry {
        let l = MeseStore.load()
        return MeseEntry(date: Date(), tests: l.tests, hw: l.hw, linked: l.linked)
    }
}

struct NOVAMeseView: View {
    var entry: MeseEntry
    @Environment(\.widgetFamily) var family

    private func dayString(_ day: Int, year: Int, month: Int) -> String {
        let d = Orario.calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? entry.date
        return MeseStore.dayFmt.string(from: d)
    }

    var body: some View {
        let cal = Orario.calendar
        let y = cal.component(.year, from: entry.date)
        let m = cal.component(.month, from: entry.date)
        let first = cal.date(from: DateComponents(year: y, month: m, day: 1)) ?? entry.date
        let daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let offset = (cal.component(.weekday, from: first) + 5) % 7 // lunedi = 0
        let todayStr = MeseStore.dayFmt.string(from: entry.date)
        let letters = ["M", "T", "W", "T", "F", "S", "S"] // lunedi prima, come da richiesta
        let big = family == .systemLarge
        let sc: CGFloat = big ? 1.7 : 1
        VStack(spacing: big ? 10 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(MeseStore.monthFmt.string(from: entry.date).capitalized)
                    .font(big ? .title3 : .headline)
                    .lineLimit(1)
                Spacer()
                Circle().fill(.red).frame(width: 6*sc, height: 6*sc)
                Text("verifiche").font(big ? .caption : .caption2).foregroundStyle(.secondary)
                Circle().fill(Color(red: 0.35, green: 0.6, blue: 1)).frame(width: 6*sc, height: 6*sc)
                Text("compiti").font(big ? .caption : .caption2).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: big ? 8 : 3) {
                ForEach(0..<7, id: \.self) { i in
                    Text(letters[i])
                        .font(.system(size: 9*sc, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<offset, id: \.self) { _ in
                    Text(" ").font(.caption2)
                }
                ForEach(1...daysInMonth, id: \.self) { d in
                    let ds = dayString(d, year: y, month: m)
                    let isToday = ds == todayStr
                    VStack(spacing: 1) {
                        Text("\(d)")
                            .font(.system(size: 9*sc, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.black : Color.white)
                            .frame(width: 14*sc, height: 14*sc)
                            .background(Circle().fill(isToday ? Color.white : Color.clear))
                        HStack(spacing: 2) {
                            if entry.tests.contains(ds) { Circle().fill(.red).frame(width: 4*sc, height: 4*sc) }
                            if entry.hw.contains(ds) { Circle().fill(Color(red: 0.35, green: 0.6, blue: 1)).frame(width: 4*sc, height: 4*sc) }
                        }
                        .frame(height: 4*sc)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if !entry.linked {
                Text("Apri NOVA e tocca Aggiorna per vedere compiti e verifiche")
                    .font(.system(size: 8*sc))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerBackground(Color.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct NOVAMeseWidget: Widget {
    let kind = "NOVAMeseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeseProvider()) { entry in
            NOVAMeseView(entry: entry)
        }
        .configurationDisplayName("Calendario del mese")
        .description("Il mese con i compiti in blu e le verifiche in rosso.")
        .supportedFamilies([.systemMedium])
    }
}


// MARK: - Widget compiti del prossimo giorno di scuola (ven-dom mostra lunedi)

struct CompitiEntry: TimelineEntry {
    let date: Date
    let targetLabel: String
    let items: [(title: String, subj: String)]
    let linked: Bool
}

enum CompitiStore {
    // lun-gio -> domani; ven/dom/sab -> lunedi (niente giorni vuoti nel weekend)
    static func targetDate(from now: Date) -> Date {
        let cal = Orario.calendar
        let wd = cal.component(.weekday, from: now) // 1=dom ... 7=sab
        let add = (wd >= 2 && wd <= 5) ? 1 : (9 - wd) % 7
        let midnight = cal.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now
        return cal.date(byAdding: .day, value: add, to: midnight) ?? now
    }

    static func load() -> (items: [(title: String, subj: String, date: String)], linked: Bool) {
        for id in Orario.groupIDs() {
            guard let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
                .appendingPathComponent("homework.json"),
                  let data = try? Data(contentsOf: u),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = j["items"] as? [[String: Any]] else { continue }
            let items = arr.compactMap { o -> (title: String, subj: String, date: String)? in
                guard let t = o["t"] as? String, let d = o["d"] as? String else { return nil }
                return (t, o["s"] as? String ?? "", d)
            }
            return (items, true)
        }
        return ([], false)
    }
}

struct CompitiProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompitiEntry {
        CompitiEntry(date: .now, targetLabel: "domani", items: [(title: "Compito di esempio", subj: "Materia")], linked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (CompitiEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompitiEntry>) -> Void) {
        let now = Date()
        let cal = Orario.calendar
        let midnight = cal.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now
        let next = cal.date(byAdding: .day, value: 1, to: midnight) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> CompitiEntry {
        let now = Date()
        let cal = Orario.calendar
        let target = CompitiStore.targetDate(from: now)
        let tstr = MeseStore.dayFmt.string(from: target)
        let names = ["", "domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
        let isTomorrow = cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now).map { MeseStore.dayFmt.string(from: $0) } == tstr
        let label = isTomorrow ? "domani" : names[cal.component(.weekday, from: target)]
        let l = CompitiStore.load()
        let items = l.items.filter { $0.date == tstr }.map { (title: $0.title, subj: $0.subj) }
        return CompitiEntry(date: now, targetLabel: label, items: items, linked: l.linked)
    }
}

struct NOVACompitiView: View {
    var entry: CompitiEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let maxRows = family == .systemSmall ? 3 : 5
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Compiti")
                    .font(.headline)
                Spacer()
                Text(entry.targetLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !entry.linked {
                Spacer(minLength: 0)
                Text("Apri NOVA e tocca Aggiorna per vedere i compiti")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if entry.items.isEmpty {
                Spacer(minLength: 0)
                Text("Niente compiti per " + entry.targetLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.items.prefix(maxRows).enumerated()), id: \.offset) { _, it in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(it.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(2)
                        if !it.subj.isEmpty {
                            Text(it.subj)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                if entry.items.count > maxRows {
                    Text("+\(entry.items.count - maxRows) altri")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color.black, for: .widget)
        .foregroundStyle(.white)
    }
}

struct NOVACompitiWidget: Widget {
    let kind = "NOVACompitiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompitiProvider()) { entry in
            NOVACompitiView(entry: entry)
        }
        .configurationDisplayName("Compiti di domani")
        .description("I compiti per il prossimo giorno di scuola: da venerdi a domenica mostra quelli di lunedi.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NOVAWidgetBundle: WidgetBundle {
    var body: some Widget {
        NOVAOrarioWidget()
        NOVAOggiWidget()
        NOVAFineWidget()
        NOVAMeseWidget()
        NOVACompitiWidget()
    }
}
