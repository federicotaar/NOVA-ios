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

struct Slot {
    let start: Date
    let end: Date
    let subject: String
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
        Lesson(weekday: 5, start: 740, end: 790, subject: "AG"),
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
}

struct OrarioEntry: TimelineEntry {
    let date: Date
    let subject: String
    let target: Date
    let isCurrent: Bool
    let showTimer: Bool
}

enum OrarioLogic {
    static func entry(at now: Date, slots: [Slot]) -> OrarioEntry {
        if let cur = slots.first(where: { $0.start <= now && now < $0.end }) {
            return OrarioEntry(date: now, subject: cur.subject, target: cur.end,
                               isCurrent: true, showTimer: true)
        }
        if let nxt = slots.first(where: { $0.start > now }) {
            let far = nxt.start.timeIntervalSince(now) > 6 * 3600
            return OrarioEntry(date: now, subject: nxt.subject, target: nxt.start,
                               isCurrent: false, showTimer: !far)
        }
        return OrarioEntry(date: now, subject: "NOVA", target: now,
                           isCurrent: false, showTimer: false)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> OrarioEntry {
        OrarioEntry(date: .now, subject: "INFO", target: .now.addingTimeInterval(1800),
                    isCurrent: true, showTimer: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (OrarioEntry) -> Void) {
        let now = Date()
        completion(OrarioLogic.entry(at: now, slots: Orario.slots(from: now, days: 5)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrarioEntry>) -> Void) {
        let now = Date()
        let slots = Orario.slots(from: now, days: 5)
        var dates: [Date] = [now]
        for s in slots {
            if s.start > now { dates.append(s.start) }
            if s.end > now { dates.append(s.end) }
        }
        dates.sort()
        let entries = dates.map { OrarioLogic.entry(at: $0, slots: slots) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NOVAWidgetEntryView: View {
    var entry: OrarioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
                Text(entry.isCurrent ? "alla fine" : "all'inizio")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.target, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.title3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NOVAWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Prossima materia")
        .description("Conto alla rovescia fino al cambio ora.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NOVAWidgetBundle: WidgetBundle {
    var body: some Widget {
        NOVAOrarioWidget()
    }
}
