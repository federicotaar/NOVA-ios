import WidgetKit
import SwiftUI

// Orario 3X ITI - definitivo dal 19 ottobre 2026 (foto bacheca ClasseViva)
// weekday: 2 = lunedi ... 6 = venerdi (Calendar: 1 = domenica)

struct Lesson {
    let weekday: Int
    let start: Int // minuti da mezzanotte
    let end: Int
    let subject: String
}

struct Slot: Identifiable {
    let start: Date
    let end: Date
    let subject: String
    var id: TimeInterval { start.timeIntervalSince1970 }
}

enum Orario {
    static let lessons: [Lesson] = [
        // Lunedi
        Lesson(weekday: 2, start: 490, end: 590, subject: "INFO"),
        Lesson(weekday: 2, start: 590, end: 640, subject: "IRC"),
        Lesson(weekday: 2, start: 640, end: 690, subject: "SR"),
        Lesson(weekday: 2, start: 690, end: 740, subject: "ING"),
        Lesson(weekday: 2, start: 740, end: 840, subject: "TELECOM"),
        // Martedi (via Canapa, 19-LING)
        Lesson(weekday: 3, start: 490, end: 590, subject: "ING"),
        Lesson(weekday: 3, start: 590, end: 640, subject: "TPSIT"),
        Lesson(weekday: 3, start: 640, end: 740, subject: "ITA"),
        Lesson(weekday: 3, start: 740, end: 790, subject: "MAT"),
        // Mercoledi
        Lesson(weekday: 4, start: 490, end: 540, subject: "STO"),
        Lesson(weekday: 4, start: 540, end: 590, subject: "ITA"),
        Lesson(weekday: 4, start: 590, end: 690, subject: "MAT"),
        Lesson(weekday: 4, start: 690, end: 740, subject: "SR"),
        Lesson(weekday: 4, start: 740, end: 840, subject: "INFO"),
        // Giovedi
        Lesson(weekday: 5, start: 490, end: 540, subject: "TELECOM"),
        Lesson(weekday: 5, start: 540, end: 640, subject: "TPSIT"),
        Lesson(weekday: 5, start: 640, end: 740, subject: "SMS"),
        Lesson(weekday: 5, start: 740, end: 840, subject: "AG"),
        // Venerdi
        Lesson(weekday: 6, start: 490, end: 590, subject: "INFO"),
        Lesson(weekday: 6, start: 590, end: 640, subject: "STO"),
        Lesson(weekday: 6, start: 640, end: 690, subject: "ITA"),
        Lesson(weekday: 6, start: 690, end: 740, subject: "MAT"),
        Lesson(weekday: 6, start: 740, end: 840, subject: "SR"),
    ]

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
                    subject: l.subject))
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
}

enum OrarioLogic {
    static func entry(at now: Date, slots: [Slot]) -> OrarioEntry {
        if let cur = slots.first(where: { $0.start <= now && now < $0.end }) {
            return OrarioEntry(date: now, subject: cur.subject, target: cur.end, barStart: cur.start,
                               isCurrent: true, showTimer: true, range: Orario.range(cur))
        }
        if let nxt = slots.first(where: { $0.start > now }) {
            let far = nxt.start.timeIntervalSince(now) > 6 * 3600
            let prevEnd = slots.last(where: { $0.end <= now })?.end ?? nxt.start.addingTimeInterval(-3600)
            return OrarioEntry(date: now, subject: nxt.subject, target: nxt.start, barStart: prevEnd,
                               isCurrent: false, showTimer: !far, range: Orario.range(nxt))
        }
        return OrarioEntry(date: now, subject: "NOVA", target: now, barStart: now,
                           isCurrent: false, showTimer: false, range: "")
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

struct NOVAOrarioView: View {
    var entry: OrarioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.isCurrent ? entry.subject : "POI: \(entry.subject)")
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget 2: lezioni di oggi

struct DayEntry: TimelineEntry {
    let date: Date
    let slots: [Slot]
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        let now = Date()
        return DayEntry(date: now, slots: Orario.slots(from: now, days: 1))
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let now = Date()
        completion(DayEntry(date: now, slots: Orario.slots(from: now, days: 1)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let entries = Orario.boundaries(from: now, days: 2).map {
            DayEntry(date: $0, slots: Orario.slots(from: $0, days: 1))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NOVAOggiView: View {
    @Environment(\.widgetFamily) var family
    var entry: DayEntry

    var body: some View {
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
                        Text(s.subject)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget 3: fine scuola

struct FineEntry: TimelineEntry {
    let date: Date
    let target: Date?
    let isToday: Bool
}

enum FineLogic {
    static func entry(at now: Date) -> FineEntry {
        let slots = Orario.slots(from: now, days: 5)
        guard let target = slots.last(where: { $0.end > now })?.end else {
            return FineEntry(date: now, target: nil, isToday: false)
        }
        return FineEntry(date: now, target: target, isToday: Orario.calendar.isDate(target, inSameDayAs: now))
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
    var entry: FineEntry

    var body: some View {
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
                Text("Finito!")
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NOVAWidgetBundle: WidgetBundle {
    var body: some Widget {
        NOVAOrarioWidget()
        NOVAOggiWidget()
        NOVAFineWidget()
    }
}
