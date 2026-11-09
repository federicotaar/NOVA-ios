import SwiftUI
import WidgetKit
import UIKit

// Fixture di verifica per Sources/NOVAWidget/NOVAWidget.swift (compilato nello stesso target
// dalla workflow widget-verify.yml, con il suo @main rimosso solo nella copia CI).
// Verifica: (1) decode con dati misti validi/non validi, (2) stati vuoto/non valido espliciti,
// (3) entry popolate per casa e lock screen, (4) render PNG reali delle view in ogni famiglia.

private var results: [[String: Any]] = []

private func check(_ cond: Bool, _ name: String) {
    results.append(["name": name, "ok": cond])
    print("CHECK \(name): \(cond ? "ok" : "FAIL")")
}

private func docs() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

// Override della famiglia widget per i render CI: la copia CI del widget sostituisce
// @Environment(\.widgetFamily) con una lettura di questo valore (vedi widget-verify.yml).
enum WidgetVerifyFamily {
    static var current: WidgetFamily = .systemMedium
}

// Quota di pixel non neri: gli stati e le famiglie accessory usano Color.primary/secondary,
// quindi un render tutto nero segnala un problema reale (o un ambiente di render sbagliato).
private func nonBlackRatio(_ img: UIImage) -> Double {
    guard let cg = img.cgImage, let data = cg.dataProvider?.data else { return 0 }
    let len = CFDataGetLength(data)
    guard let ptr = CFDataGetBytePtr(data), len > 0 else { return 0 }
    let bpp = cg.bitsPerPixel / 8
    let bpr = cg.bytesPerRow
    var lit = 0, total = 0
    let step = max(1, (cg.width * cg.height) / 20000)
    var i = 0
    while i < cg.width * cg.height {
        let x = i % cg.width, y = i / cg.width
        let off = y * bpr + x * bpp
        if off + 2 < len {
            if Int(ptr[off]) + Int(ptr[off + 1]) + Int(ptr[off + 2]) > 96 { lit += 1 }
        }
        total += 1
        i += step
    }
    return total > 0 ? Double(lit) / Double(total) : 0
}

@MainActor
private func renderPNG<V: View>(_ view: V, family: WidgetFamily, size: CGSize, name: String) {
    WidgetVerifyFamily.current = family
    let hc = UIHostingController(rootView: view)
    hc.view.bounds = CGRect(origin: .zero, size: size)
    hc.view.backgroundColor = .black
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    // Dark: le famiglie accessory (lock screen) usano i colori di default (primary/secondary),
    // che il sistema rende chiari sullo sfondo scuro della lock screen.
    window.overrideUserInterfaceStyle = .dark
    window.rootViewController = hc
    window.isHidden = false
    let renderer = UIGraphicsImageRenderer(size: size)
    let img = renderer.image { _ in hc.view.drawHierarchy(in: hc.view.bounds, afterScreenUpdates: true) }
    let url = docs().appendingPathComponent(name + ".png")
    do {
        try img.pngData()?.write(to: url)
        let bytes = (try? Data(contentsOf: url))?.count ?? 0
        let ratio = nonBlackRatio(img)
        check(bytes > 2500 && ratio > 0.003, "render_" + name)
        print("RENDER \(name): \(bytes) bytes, nonBlack=\(String(format: "%.4f", ratio))")
    } catch {
        check(false, "render_" + name)
    }
    window.isHidden = true
}

@MainActor
private func runVerification() {
    // --- 1. decode: dati misti ---
    let mixed = """
    {"v":1,"lessons":[
      {"d":2,"s":490,"e":550,"n":"INFO","r":"LAB"},
      {"d":1,"s":490,"e":550,"n":"GIORNO_ERR"},
      {"d":3,"s":600,"e":550,"n":"FINE_PRIMA_INIZIO"},
      {"d":4,"s":600,"e":660,"n":"MAT"},
      {"d":5,"s":700,"e":760,"n":"   "},
      {"d":8,"s":61,"e":120,"n":"FUORI_RANGE"},
      {"d":6,"s":800,"e":1500,"n":"OLTRE_MEZZANOTTE"},
      {"d":7,"s":800}
    ]}
    """
    let t = Orario.decode(Data(mixed.utf8))
    check(t != nil, "decode_mixed_returns_value")
    check(t?.lessons.map { $0.subject } == ["INFO", "MAT"], "decode_mixed_keeps_valid_only")
    check(t?.dropped == 6, "decode_mixed_counts_dropped")
    check(t?.lessons.first?.room == "LAB", "decode_mixed_keeps_room")

    let empty = Orario.decode(Data(#"{"v":1,"lessons":[]}"#.utf8))
    check(empty?.lessons.isEmpty == true && empty?.dropped == 0, "decode_empty_valid")

    let garbage = Orario.decode(Data("non json".utf8))
    check(garbage == nil, "decode_garbage_nil")
    let wrongRoot = Orario.decode(Data(#"{"v":1,"lessons":{"a":1}}"#.utf8))
    check(wrongRoot == nil, "decode_wrong_root_nil")

    // --- 2. stati vuoto / non valido espliciti ---
    check(OrarioLogic.emptyRange(lessons: [], dropped: 0) == "Aggiungilo in NOVA", "empty_state_add_prompt")
    check(OrarioLogic.emptyRange(lessons: [], dropped: 2) == "Dati orario non validi", "invalid_state_explicit")
    check(OrarioLogic.emptyRange(lessons: [Lesson(weekday: 2, start: 490, end: 550, subject: "INFO")], dropped: 0) == "", "populated_state_no_prompt")

    // --- 3. entry popolate (lunedi' con 3 lezioni) ---
    var cal = Orario.calendar
    let monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 8, minute: 30))!
    let day = cal.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
    func slot(_ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, _ n: String, _ r: String = "") -> Slot {
        Slot(start: day.addingTimeInterval(TimeInterval(sh * 3600 + sm * 60)),
             end: day.addingTimeInterval(TimeInterval(eh * 3600 + em * 60)), subject: n, room: r)
    }
    let slots = [slot(8, 10, 9, 10, "INFO", "LAB"), slot(9, 10, 10, 5, "MAT"), slot(10, 5, 11, 0, "ITA")]

    let cur = OrarioLogic.entry(at: monday, slots: slots)
    check(cur.isCurrent && cur.subject == "INFO" && cur.showTimer, "entry_current_lesson")
    check(cur.range == "08.10 – 09.10", "entry_current_range")

    let between = cal.date(byAdding: .minute, value: 70, to: monday)! // 9:40, dentro MAT? no: MAT 9.10-10.5 -> dentro
    let eBetween = OrarioLogic.entry(at: between, slots: slots)
    check(eBetween.isCurrent && eBetween.subject == "MAT", "entry_second_lesson")

    let after = cal.date(bySettingHour: 15, minute: 0, second: 0, of: monday)!
    let eAfter = OrarioLogic.entry(at: after, slots: slots)
    check(!eAfter.isCurrent && eAfter.subject == "ORARIO" && !eAfter.showTimer, "entry_day_over")

    // --- 4. render PNG reali per famiglia ---
    let now = Date()
    let populated = OrarioEntry(date: now, subject: "INFO", target: now.addingTimeInterval(2400),
                                barStart: now.addingTimeInterval(-1200), isCurrent: true,
                                showTimer: true, range: "8.10 – 9.10", room: "LAB", linked: true)
    renderPNG(NOVAOrarioView(entry: populated), family: .systemSmall,
              size: CGSize(width: 170, height: 170), name: "orario-home-small")
    renderPNG(NOVAOrarioView(entry: populated), family: .systemMedium,
              size: CGSize(width: 360, height: 170), name: "orario-home-medium")
    renderPNG(NOVAOrarioView(entry: populated), family: .accessoryInline,
              size: CGSize(width: 320, height: 24), name: "orario-lock-inline")
    renderPNG(NOVAOrarioView(entry: populated), family: .accessoryRectangular,
              size: CGSize(width: 170, height: 76), name: "orario-lock-rect")

    let dayEntry = DayEntry(date: now, slots: slots, linked: true)
    renderPNG(NOVAOggiView(entry: dayEntry), family: .systemSmall,
              size: CGSize(width: 170, height: 170), name: "oggi-home-small")
    renderPNG(NOVAOggiView(entry: dayEntry), family: .accessoryRectangular,
              size: CGSize(width: 170, height: 76), name: "oggi-lock-rect")

    let fineEntry = FineEntry(date: now, target: now.addingTimeInterval(5400), isToday: true,
                              barStart: now.addingTimeInterval(-3600), linked: true)
    renderPNG(NOVAFineView(entry: fineEntry), family: .accessoryCircular,
              size: CGSize(width: 84, height: 84), name: "fine-lock-circular")
    renderPNG(NOVAFineView(entry: fineEntry), family: .accessoryRectangular,
              size: CGSize(width: 170, height: 76), name: "fine-lock-rect")

    // stati espliciti
    let unlinked = OrarioEntry(date: now, subject: "ORARIO", target: now, barStart: now,
                               isCurrent: false, showTimer: false, range: "", linked: false)
    renderPNG(NOVAOrarioView(entry: unlinked), family: .systemSmall,
              size: CGSize(width: 170, height: 170), name: "state-unavailable")
    let invalid = OrarioEntry(date: now, subject: "ORARIO", target: now, barStart: now,
                              isCurrent: false, showTimer: false,
                              range: OrarioLogic.emptyRange(lessons: [], dropped: 3), linked: true)
    renderPNG(NOVAOrarioView(entry: invalid), family: .systemSmall,
              size: CGSize(width: 170, height: 170), name: "state-invalid-data")
    let emptyState = OrarioEntry(date: now, subject: "ORARIO", target: now, barStart: now,
                                 isCurrent: false, showTimer: false,
                                 range: OrarioLogic.emptyRange(lessons: [], dropped: 0), linked: true)
    renderPNG(NOVAOrarioView(entry: emptyState), family: .systemSmall,
              size: CGSize(width: 170, height: 170), name: "state-empty")

    // --- 5. esito ---
    let failed = results.filter { !($0["ok"] as? Bool ?? false) }
    let summary: [String: Any] = ["total": results.count, "failed": failed.count, "checks": results]
    if let data = try? JSONSerialization.data(withJSONObject: summary, options: .prettyPrinted) {
        try? data.write(to: docs().appendingPathComponent("widget-verify.json"))
    }
    print("WIDGET-VERIFY DONE total=\(results.count) failed=\(failed.count)")
    FileManager.default.createFile(atPath: docs().path + "/widget-verify-done", contents: nil)
}

@main
struct WidgetVerifyApp: App {
    var body: some Scene {
        WindowGroup {
            Color.black
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        runVerification()
                    }
                }
        }
    }
}
