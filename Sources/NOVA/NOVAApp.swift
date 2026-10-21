import SwiftUI
import UIKit
import WebKit
import Security
import UserNotifications
import BackgroundTasks
import AuthenticationServices
import CryptoKit

@main
struct NOVAApp: App {
    init() { BGHandler.register() }

    var body: some Scene {
        WindowGroup {
            WebContainer()
                .ignoresSafeArea()
                .background(Color.black.ignoresSafeArea())
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct WebContainer: UIViewRepresentable {
    func makeCoordinator() -> Bridge { Bridge() }

    func makeUIView(context: Context) -> WKWebView {
        let bridge = context.coordinator
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: "nova")
        config.userContentController.addUserScript(
            WKUserScript(source: Bridge.polyfill(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = bridge
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        bridge.web = web
        bridge.start()
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        if let url = bundle.url(forResource: "nova", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Ponte nativo: batteria reale, schermo acceso in carica, notifiche locali, ClasseViva.
final class Bridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, UNUserNotificationCenterDelegate {
    weak var web: WKWebView?
    private let center = UNUserNotificationCenter.current()

    // Safari/WKWebView su iPhone non espone navigator.getBattery né Notification:
    // li simuliamo con i dati nativi, così nova.html funziona senza modifiche.
    static func polyfill() -> String {
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        let level = d.batteryLevel < 0 ? 1.0 : Double(d.batteryLevel)
        let charging = d.batteryState == .charging || d.batteryState == .full
        return """
        (function(){
          var post=function(m){window.webkit.messageHandlers.nova.postMessage(m)};
          var b=new EventTarget();b.level=\(level);b.charging=\(charging);b.chargingTime=Infinity;b.dischargingTime=Infinity;
          navigator.getBattery=function(){return Promise.resolve(b)};
          window.__novaBattery=function(l,c){b.level=l;b.charging=c;b.dispatchEvent(new Event('levelchange'));b.dispatchEvent(new Event('chargingchange'))};
          var res=null;function N(){}N.permission='default';
          N.requestPermission=function(){return new Promise(function(r){res=r;post({t:'perm'})})};
          window.Notification=N;
          window.__novaPerm=function(p){N.permission=p;if(res){res(p);res=null}};
        })();
        """
    }

    func start() {
        center.delegate = self
        UIDevice.current.isBatteryMonitoringEnabled = true
        for n in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                self?.pushBattery()
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            BGHandler.schedule()
        }
        BGHandler.schedule()
        pushBattery()
    }

    func pushBattery() {
        let d = UIDevice.current
        let level = d.batteryLevel < 0 ? 1.0 : Double(d.batteryLevel)
        let charging = d.batteryState == .charging || d.batteryState == .full
        UIApplication.shared.isIdleTimerDisabled = charging   // schermo acceso solo in carica
        web?.evaluateJavaScript("window.__novaBattery&&__novaBattery(\(level),\(charging))")
    }

    // Link esterni (es. console.groq.com) si aprono in Safari, non dentro l'app.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pushBattery()
        center.getNotificationSettings { s in
            let p = s.authorizationStatus == .authorized ? "granted" : (s.authorizationStatus == .denied ? "denied" : "default")
            DispatchQueue.main.async { webView.evaluateJavaScript("window.__novaPerm&&__novaPerm('\(p)')") }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let t = body["t"] as? String else { return }
        if t == "perm" {
            center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                let p = ok ? "granted" : "denied"
                DispatchQueue.main.async { self.web?.evaluateJavaScript("__novaPerm('\(p)')") }
            }
        } else if t == "sched", let items = body["items"] as? [[String: Any]] {
            schedule(items)
        } else if t == "hwn" {
            UserDefaults.standard.set(body["on"] as? Bool ?? true, forKey: "nova.hwn")
        } else if t == "timer" {
            scheduleTimer(body["at"] as? Double)
        } else if t == "spotify" {
            let reqId = body["id"] as? Int ?? 0
            Task {
                let result = await Spotify.handle(body)
                self.replyClasseViva(reqId, result)
            }
        } else if t == "groq" {
            let reqId = body["id"] as? Int ?? 0
            Task {
                let result = await Groq.handle(body)
                self.replyClasseViva(reqId, result)
            }
        } else if t == "classeviva" {
            let reqId = body["id"] as? Int ?? 0
            Task {
                let result = await ClasseViva.handle(body)
                self.replyClasseViva(reqId, result)
            }
        }
    }

    // Risposta asincrona verso nova.html (window.__novaCV)
    func replyClasseViva(_ id: Int, _ result: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(result),
              let data = try? JSONSerialization.data(withJSONObject: result),
              var json = String(data: data, encoding: .utf8) else { return }
        json = json.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                   .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        DispatchQueue.main.async {
            self.web?.evaluateJavaScript("window.__novaCV&&__novaCV(\(id),\(json))")
        }
    }

    // Riprogramma tutti i promemoria futuri (iOS ne ammette max 64 in sospeso).
    func schedule(_ items: [[String: Any]]) {
        center.getPendingNotificationRequests { reqs in
            let old = reqs.map { $0.identifier }.filter { $0.hasPrefix("rem.") }
            self.center.removePendingNotificationRequests(withIdentifiers: old)
        }
        let now = Date()
        let upcoming = items.compactMap { i -> (String, String, Date)? in
            guard let id = i["id"] as? String, let title = i["title"] as? String, let ms = i["at"] as? Double else { return nil }
            let date = Date(timeIntervalSince1970: ms / 1000)
            return date > now ? (id, title, date) : nil
        }.sorted { $0.2 < $1.2 }.prefix(25)
        for (id, title, date) in upcoming {
            let c = UNMutableNotificationContent()
            c.title = "NOVA · Promemoria"
            c.body = title
            c.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            center.add(UNNotificationRequest(identifier: "rem." + id, content: c,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    // Timer Focus: una notifica locale a fine sessione, anche con l'app chiusa.
    func scheduleTimer(_ atMs: Double?) {
        center.removePendingNotificationRequests(withIdentifiers: ["timer"])
        guard let ms = atMs else { return }
        let secs = ms / 1000 - Date().timeIntervalSince1970
        guard secs > 1 else { return }
        let c = UNMutableNotificationContent()
        c.title = "NOVA · Focus"
        c.body = "Sessione finita. Fai una pausa."
        c.sound = .default
        center.add(UNNotificationRequest(identifier: "timer", content: c,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: secs, repeats: false)))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

// MARK: - Credenziali ClasseViva nel Portachiavi iOS (restano solo sul telefono)

enum CredStore {
    private static let service = "nova.classeviva"

    static func save(uid: String, pass: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["uid": uid, "pass": pass]) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "login"
        ]
        SecItemDelete(base as CFDictionary)
        var q = base
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func read() -> (uid: String, pass: String)? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "login",
            kSecReturnData as String: true
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uid = dict["uid"] as? String,
              let pass = dict["pass"] as? String else { return nil }
        return (uid, pass)
    }

    static func clear() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "login"
        ]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - ClasseViva REST (web.spaggiari.eu/rest/v1)

enum ClasseViva {
    static let base = "https://web.spaggiari.eu/rest/v1"

    // Coppie di header usate dai client open source documentati: se una chiave API
    // non viene più accettata si prova automaticamente l'altra.
    private static let headerPairs: [(ua: String, key: String)] = [
        ("CVVS/std/4.1.7 Android/10", "Tg1NWEwNGIgIC0K"),
        ("zorro/1.0", "+zorro+")
    ]

    private static func call(_ path: String, method: String = "GET", body: [String: Any]? = nil, token: String? = nil, pair: Int = 0) async throws -> (Data, Int) {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(headerPairs[pair].ua, forHTTPHeaderField: "User-Agent")
        req.setValue(headerPairs[pair].key, forHTTPHeaderField: "Z-Dev-ApiKey")
        if let token = token { req.setValue(token, forHTTPHeaderField: "Z-Auth-Token") }
        if let body = body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static func handle(_ msg: [String: Any]) async -> [String: Any] {
        let op = msg["op"] as? String ?? ""
        switch op {
        case "logout":
            CredStore.clear()
            return ["ok": 1]
        case "login":
            guard let uid = msg["uid"] as? String, !uid.isEmpty,
                  let pass = msg["pass"] as? String, !pass.isEmpty else { return ["ok": 0, "err": "dati"] }
            return await loginFlow(uid: uid, pass: pass, ident: msg["ident"] as? String, save: true)
        case "refresh":
            guard let c = CredStore.read() else { return ["ok": 0, "err": "no-creds"] }
            return await loginFlow(uid: c.uid, pass: c.pass, ident: nil, save: false)
        default:
            return ["ok": 0, "err": "op"]
        }
    }

    static func loginFlow(uid: String, pass: String, ident: String?, save: Bool, background: Bool = false) async -> [String: Any] {
        var payload: [String: Any] = ["uid": uid, "pass": pass, "ident": NSNull()]
        if let ident = ident, !ident.isEmpty { payload["ident"] = ident }
        for pair in 0..<headerPairs.count {
            do {
                let (data, status) = try await call("/auth/login", method: "POST", body: payload, pair: pair)
                // Risposta non JSON (es. 403 del firewall): prova la coppia successiva.
                guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if pair + 1 < headerPairs.count { continue }
                    return ["ok": 0, "err": "bloccato", "info": "HTTP \(status)"]
                }
                // Chiave API rifiutata: prova la coppia successiva.
                if let e = j["error"] as? String, (e.lowercased().contains("apikey") || e.lowercased().contains("api key")), pair + 1 < headerPairs.count { continue }
                // Account famiglia con più profili: l'app fa scegliere lo studente.
                if let choices = j["choices"] as? [[String: Any]], !choices.isEmpty {
                    let list: [[String: Any]] = choices.map { c in
                        ["ident": c["ident"] as? String ?? "",
                         "name": c["name"] as? String ?? "",
                         "school": c["school"] as? String ?? ""]
                    }
                    return ["ok": 0, "needChoice": 1, "choices": list]
                }
                guard status == 200, let token = j["token"] as? String, let fullIdent = j["ident"] as? String else {
                    let info = (j["info"] as? String ?? "") + " " + (j["error"] as? String ?? "")
                    return ["ok": 0, "err": "credenziali", "info": "HTTP \(status) " + info.trimmingCharacters(in: .whitespaces)]
                }
                let studentID = fullIdent.replacingOccurrences(of: "[A-Za-z]", with: "", options: .regularExpression)
                if save { CredStore.save(uid: uid, pass: pass) }
                let first = j["firstName"] as? String ?? ""
                let last = j["lastName"] as? String ?? ""
                let name = (first + " " + last).trimmingCharacters(in: .whitespaces)
                let events = await fetchEvents(token: token, studentID: studentID, pair: pair)
                let grades = await gradesItems(token: token, studentID: studentID, pair: pair)
                await HomeNotifs.process(events, background: background)
                return ["ok": 1, "name": name, "events": events, "grades": grades]
            } catch {
                return ["ok": 0, "err": "rete", "info": error.localizedDescription]
            }
        }
        return ["ok": 0, "err": "rete", "info": "nessuna risposta"]
    }

    // Tutto quello che la sua scuola pubblica: compiti nuovi (NEWDC, sezione
    // "Compiti e materiali"), annotazioni dei prof (AGNT: verifiche, interrogazioni)
    // e compiti vecchio stile in agenda (AGHW).
    private static func fetchEvents(token: String, studentID: String, pair: Int) async -> [[String: Any]] {
        await homeworkItems(token: token, studentID: studentID, pair: pair)
            + agendaItems(token: token, studentID: studentID, pair: pair)
    }

    private static func clean(_ s: String, _ maxLen: Int) -> String {
        var t = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > maxLen { t = String(t.prefix(maxLen - 1)) + "…" }
        return t
    }

    // Compiti dal registro nuovo (eventi NEWDC): l'endpoint restituisce quelli ancora aperti.
    private static func homeworkItems(token: String, studentID: String, pair: Int) async -> [[String: Any]] {
        for path in ["/students/\(studentID)/homeworks", "/students/\(studentID)/homeworks/index"] {
            do {
                let (data, status) = try await call(path, token: token, pair: pair)
                if status == 404 { continue }
                guard status == 200,
                      let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = j["items"] as? [[String: Any]] else { return [] }
                var out: [[String: Any]] = []
                for e in items {
                    guard let id = e["evtId"] as? Int else { continue }
                    if e["homeworkDone"] as? Bool ?? false { continue }
                    guard let date = e["expiryDate"] as? String, date.count >= 10 else { continue }
                    let subj = (e["subjectDesc"] as? String ?? "").capitalized
                    let teacher = (e["teacherName"] as? String ?? "").capitalized
                    let desc = clean(e["homeworkDesc"] as? String ?? "Compito", 900)
                    var note = subj
                    if !teacher.isEmpty { note = note.isEmpty ? teacher : note + " · " + teacher }
                    out.append(["id": "hw\(id)", "title": desc, "note": note, "date": String(date.prefix(10)), "kind": "hw", "subj": subj, "teacher": teacher])
                }
                return out
            } catch { return [] }
        }
        return []
    }

    // Agenda: annotazioni dei prof (AGNT) + compiti vecchio stile (AGHW), da una
    // settimana fa a un mese avanti. Prova prima la agenda nuova (agendav2).
    private static func agendaItems(token: String, studentID: String, pair: Int) async -> [[String: Any]] {
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: now),
              let end = Calendar.current.date(byAdding: .day, value: 30, to: now) else { return [] }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        let a = f.string(from: start), b = f.string(from: end)
        for path in ["/students/\(studentID)/agendav2/all/\(a)/\(b)", "/students/\(studentID)/agenda/all/\(a)/\(b)"] {
            guard let events = await agendaCall(path, token: token, pair: pair) else { continue }
            var out: [[String: Any]] = []
            for e in events {
                guard let code = e["evtCode"] as? String, let id = e["evtId"] as? Int,
                      let dtb = e["evtDatetimeBegin"] as? String, dtb.count >= 10 else { continue }
                let date = String(dtb.prefix(10))
                let notes = clean(e["notes"] as? String ?? "", 700)
                let author = (e["authorName"] as? String ?? "").capitalized
                if code == "AGNT" {
                    guard !notes.isEmpty else { continue }
                    out.append(["id": "ag\(id)", "title": notes, "note": author, "date": date, "kind": "test", "subj": "Verifica / annotazione", "teacher": author])
                } else if code == "AGHW" {
                    let subj = (e["subjectDesc"] as? String ?? "Compito").capitalized
                    var note = notes
                    if !author.isEmpty { note = note.isEmpty ? author : note + " · " + author }
                    out.append(["id": "ahw\(id)", "title": subj, "note": note, "date": date, "kind": "hw", "subj": subj, "teacher": author])
                }
            }
            return out
        }
        return []
    }

    // Voti dal registro (/grades): solo quelli numerici.
    private static func gradesItems(token: String, studentID: String, pair: Int) async -> [[String: Any]] {
        do {
            let (data, status) = try await call("/students/\(studentID)/grades", token: token, pair: pair)
            guard status == 200,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let g = j["grades"] as? [[String: Any]] else { return [] }
            var out: [[String: Any]] = []
            for e in g {
                guard let v = e["decimalValue"] as? Double, let date = e["evtDate"] as? String, date.count >= 10 else { continue }
                let subj = (e["subjectDesc"] as? String ?? "").capitalized
                let d = String(date.prefix(10))
                let id = (e["evtId"] as? Int).map { "g\($0)" } ?? "g\(d)\(subj)\(v)"
                out.append(["id": id, "subj": subj, "date": d, "v": v,
                            "d": e["displayValue"] as? String ?? String(v),
                            "n": clean(e["notesForFamily"] as? String ?? "", 200),
                            "k": e["componentDesc"] as? String ?? ""])
            }
            return out
        } catch { return [] }
    }

    static func backgroundRefresh() async -> Bool {
        guard let c = CredStore.read() else { return false }
        let r = await loginFlow(uid: c.uid, pass: c.pass, ident: nil, save: false, background: true)
        return (r["ok"] as? Int) == 1
    }

    private static func agendaCall(_ path: String, token: String, pair: Int) async -> [[String: Any]]? {
        do {
            let (data, status) = try await call(path, token: token, pair: pair)
            guard status == 200,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let agenda = j["agenda"] as? [[String: Any]] else { return nil }
            return agenda
        } catch { return nil }
    }
}


// MARK: - Aggiornamento in background (best effort: decide iOS quando farlo)

enum BGHandler {
    static let id = "it.tuonome.nova.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            schedule()
            let work = Task {
                let ok = await ClasseViva.backgroundRefresh()
                task.setTaskCompleted(success: ok)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: id)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }
}

// MARK: - Notifiche compiti: la sera prima (18:00) di ogni scadenza, anche ad app chiusa

enum HomeNotifs {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "nova.hwn") as? Bool ?? true }

    static func process(_ events: [[String: Any]], background: Bool) async {
        let center = UNUserNotificationCenter.current()
        let ud = UserDefaults.standard
        let ids = Set(events.compactMap { $0["id"] as? String })
        let known = Set(ud.stringArray(forKey: "nova.known") ?? [])
        let fresh = events.filter { !known.contains($0["id"] as? String ?? "") }
        ud.set(Array(ids), forKey: "nova.known")
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Novità trovate dall'aggiornamento in background: avviso subito.
        if background && !known.isEmpty && !fresh.isEmpty {
            let c = UNMutableNotificationContent()
            let tests = fresh.filter { ($0["kind"] as? String) == "test" }.count
            c.title = fresh.count == 1 ? (tests == 1 ? "NOVA · Nuova verifica" : "NOVA · Nuovo compito") : "NOVA · \(fresh.count) novità"
            c.body = fresh.prefix(3).map { line($0) }.joined(separator: "\n")
            c.sound = .default
            try? await center.add(UNNotificationRequest(identifier: "hw.new.\(Int(Date().timeIntervalSince1970))", content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
        }

        // Promemoria della sera prima, un messaggio per giorno di scadenza.
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map { $0.identifier }.filter { $0.hasPrefix("hw.day.") })
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        var byDay: [String: [[String: Any]]] = [:]
        for e in events { if let d = e["date"] as? String { byDay[d, default: []].append(e) } }
        let cal = Calendar.current
        let now = Date()
        var count = 0
        for day in byDay.keys.sorted() {
            guard count < 30, let due = f.date(from: day),
                  let before = cal.date(byAdding: .day, value: -1, to: due),
                  let fire = cal.date(bySettingHour: 18, minute: 0, second: 0, of: before),
                  fire > now, let items = byDay[day] else { continue }
            let c = UNMutableNotificationContent()
            c.title = "NOVA · Per domani"
            var lines = items.prefix(4).map { line($0) }
            if items.count > 4 { lines.append("+ altri \(items.count - 4)") }
            c.body = lines.joined(separator: "\n")
            c.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            try? await center.add(UNNotificationRequest(identifier: "hw.day.\(day)", content: c,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            count += 1
        }
    }

    private static func line(_ e: [String: Any]) -> String {
        var t = e["title"] as? String ?? ""
        if t.count > 70 { t = String(t.prefix(69)) + "…" }
        if (e["kind"] as? String) == "test" { return "Verifica: " + t }
        let s = e["subj"] as? String ?? ""
        return s.isEmpty ? t : s + ": " + t
    }
}

// MARK: - Segreti nel Portachiavi (chiave Groq)

enum Secret {
    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "nova.secret",
         kSecAttrAccount as String: account]
    }
    static func set(_ account: String, _ value: String) {
        SecItemDelete(base(account) as CFDictionary)
        var q = base(account)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
    static func get(_ account: String) -> String? {
        var q = base(account)
        q[kSecReturnData as String] = true
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func clear(_ account: String) { SecItemDelete(base(account) as CFDictionary) }
}

// MARK: - Groq (chatbot): api.groq.com, NON Grok di xAI

enum Groq {
    static let models = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "openai/gpt-oss-20b"]
    static let base = "https://api.groq.com/openai/v1"

    static func handle(_ msg: [String: Any]) async -> [String: Any] {
        switch msg["op"] as? String ?? "" {
        case "has":
            return ["ok": 1, "has": Secret.get("groq") != nil]
        case "clear":
            Secret.clear("groq")
            return ["ok": 1]
        case "set":
            let key = (msg["key"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if key.hasPrefix("xai-") { return ["ok": 0, "err": "grok"] }
            guard key.hasPrefix("gsk_"), key.count > 20 else { return ["ok": 0, "err": "formato"] }
            var req = URLRequest(url: URL(string: base + "/models")!)
            req.timeoutInterval = 20
            req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if status == 401 || status == 403 { return ["ok": 0, "err": "key"] }
                guard status == 200 else { return ["ok": 0, "err": "rete", "info": "HTTP \(status)"] }
            } catch { return ["ok": 0, "err": "rete"] }
            Secret.set("groq", key)
            return ["ok": 1]
        case "chat":
            guard let key = Secret.get("groq") else { return ["ok": 0, "err": "nokey"] }
            let msgs = msg["messages"] as? [[String: Any]] ?? []
            for model in models {
                var req = URLRequest(url: URL(string: base + "/chat/completions")!)
                req.httpMethod = "POST"
                req.timeoutInterval = 60
                req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["model": model, "messages": msgs, "temperature": 0.5, "max_tokens": 900]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                do {
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if status == 200,
                       let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ch = (j["choices"] as? [[String: Any]])?.first,
                       let m = ch["message"] as? [String: Any],
                       let t = m["content"] as? String { return ["ok": 1, "text": t, "model": model] }
                    if status == 401 || status == 403 { return ["ok": 0, "err": "key"] }
                    if status == 429 { return ["ok": 0, "err": "limite"] }
                } catch { return ["ok": 0, "err": "rete"] }
            }
            return ["ok": 0, "err": "modello"]
        default:
            return ["ok": 0, "err": "op"]
        }
    }
}


// MARK: - Spotify (Web API, login PKCE: serve un Client ID dell'utente e Premium per i comandi)

final class AuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum Spotify {
    static let redirect = "nova://spotify-callback"
    static let scopes = "user-read-playback-state user-modify-playback-state"
    static let presenter = AuthPresenter()
    static var session: ASWebAuthenticationSession?

    static var cid: String { Secret.get("spotify.cid") ?? "" }

    static func handle(_ msg: [String: Any]) async -> [String: Any] {
        switch msg["op"] as? String ?? "" {
        case "status":
            return ["ok": 1, "cid": !cid.isEmpty, "conn": Secret.get("spotify.refresh") != nil]
        case "setcid":
            let v = (msg["cid"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if v.isEmpty { Secret.clear("spotify.cid") } else { Secret.set("spotify.cid", v) }
            Secret.clear("spotify.refresh")
            UserDefaults.standard.removeObject(forKey: "nova.sp.access")
            return ["ok": 1]
        case "logout":
            Secret.clear("spotify.refresh")
            UserDefaults.standard.removeObject(forKey: "nova.sp.access")
            return ["ok": 1]
        case "login":
            return await login()
        case "state":
            return await state()
        case "play": return await control("PUT", "/me/player/play")
        case "pause": return await control("PUT", "/me/player/pause")
        case "next": return await control("POST", "/me/player/next")
        case "prev": return await control("POST", "/me/player/previous")
        default:
            return ["ok": 0, "err": "op"]
        }
    }

    private static func randomString(_ n: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<n).map { _ in chars.randomElement()! })
    }

    private static func form(_ d: [String: String]) -> Data {
        let body = d.map { k, v in
            k + "=" + (v.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v)
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    private static func tokenRequest(_ params: [String: String]) async -> (Int, [String: Any]?) {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = form(params)
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return (0, nil) }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (status, try? JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func store(_ j: [String: Any]) {
        if let a = j["access_token"] as? String {
            let exp = Date().timeIntervalSince1970 + (j["expires_in"] as? Double ?? 3600)
            UserDefaults.standard.set(["t": a, "e": exp], forKey: "nova.sp.access")
        }
        if let r = j["refresh_token"] as? String { Secret.set("spotify.refresh", r) }
    }

    static func login() async -> [String: Any] {
        let id = cid
        guard !id.isEmpty else { return ["ok": 0, "err": "nocid"] }
        let verifier = randomString(64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: id),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: scopes)
        ]
        guard let url = comps.url else { return ["ok": 0, "err": "client"] }
        let callback: URL? = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let s = ASWebAuthenticationSession(url: url, callbackURLScheme: "nova") { u, _ in cont.resume(returning: u) }
                s.presentationContextProvider = presenter
                s.prefersEphemeralWebBrowserSession = false
                session = s
                if !s.start() { cont.resume(returning: nil) }
            }
        }
        guard let cb = callback,
              let items = URLComponents(url: cb, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value else {
            return ["ok": 0, "err": "denied"]
        }
        let (status, j) = await tokenRequest(["client_id": id, "grant_type": "authorization_code", "code": code,
                                              "redirect_uri": redirect, "code_verifier": verifier])
        guard status == 200, let tok = j else { return ["ok": 0, "err": status == 0 ? "rete" : "client", "info": "HTTP \(status)"] }
        store(tok)
        return ["ok": 1]
    }

    private static func accessToken(force: Bool = false) async -> String? {
        let ud = UserDefaults.standard
        if !force, let d = ud.dictionary(forKey: "nova.sp.access"), let t = d["t"] as? String,
           let e = d["e"] as? Double, e > Date().timeIntervalSince1970 + 30 { return t }
        guard let r = Secret.get("spotify.refresh"), !cid.isEmpty else { return nil }
        let (status, j) = await tokenRequest(["client_id": cid, "grant_type": "refresh_token", "refresh_token": r])
        guard status == 200, let tok = j else { return nil }
        store(tok)
        return tok["access_token"] as? String
    }

    private static func api(_ method: String, _ path: String) async -> (Int, Data)? {
        for attempt in 0..<2 {
            guard let token = await accessToken(force: attempt == 1) else { return (401, Data()) }
            var req = URLRequest(url: URL(string: "https://api.spotify.com/v1" + path)!)
            req.httpMethod = method
            req.timeoutInterval = 15
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            if method != "GET" { req.setValue("0", forHTTPHeaderField: "Content-Length") }
            guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 && attempt == 0 { continue }
            return (status, data)
        }
        return nil
    }

    private static func fail(_ status: Int, _ data: Data) -> [String: Any] {
        if status == 401 { return ["ok": 0, "err": "auth"] }
        if status == 404 { return ["ok": 0, "err": "nodevice"] }
        if status == 403 {
            let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let reason = ((j?["error"] as? [String: Any])?["reason"] as? String) ?? ""
            return ["ok": 0, "err": reason == "PREMIUM_REQUIRED" ? "premium" : "client", "info": reason]
        }
        return ["ok": 0, "err": "rete", "info": "HTTP \(status)"]
    }

    static func state() async -> [String: Any] {
        guard let (status, data) = await api("GET", "/me/player") else { return ["ok": 0, "err": "rete"] }
        if status == 204 { return ["ok": 1, "idle": 1] }
        guard status == 200 else { return fail(status, data) }
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = j["item"] as? [String: Any] else { return ["ok": 1, "idle": 1] }
        let artists = (item["artists"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }.joined(separator: ", ")
        let imgs = ((item["album"] as? [String: Any])?["images"] as? [[String: Any]]) ?? []
        let img = (imgs.count > 1 ? imgs[1] : imgs.first)?["url"] as? String ?? ""
        return ["ok": 1, "playing": j["is_playing"] as? Bool ?? false,
                "track": item["name"] as? String ?? "", "artist": artists, "img": img]
    }

    static func control(_ method: String, _ path: String) async -> [String: Any] {
        guard let (status, data) = await api(method, path) else { return ["ok": 0, "err": "rete"] }
        if status == 200 || status == 202 || status == 204 { return ["ok": 1] }
        return fail(status, data)
    }
}
