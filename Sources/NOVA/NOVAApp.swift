import SwiftUI
import UIKit
import WebKit
import Security
import UserNotifications

@main
struct NOVAApp: App {
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
        pushBattery()
    }

    func pushBattery() {
        let d = UIDevice.current
        let level = d.batteryLevel < 0 ? 1.0 : Double(d.batteryLevel)
        let charging = d.batteryState == .charging || d.batteryState == .full
        UIApplication.shared.isIdleTimerDisabled = charging   // schermo acceso solo in carica
        web?.evaluateJavaScript("window.__novaBattery&&__novaBattery(\(level),\(charging))")
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
        center.removeAllPendingNotificationRequests()
        let now = Date()
        let upcoming = items.compactMap { i -> (String, String, Date)? in
            guard let id = i["id"] as? String, let title = i["title"] as? String, let ms = i["at"] as? Double else { return nil }
            let date = Date(timeIntervalSince1970: ms / 1000)
            return date > now ? (id, title, date) : nil
        }.sorted { $0.2 < $1.2 }.prefix(60)
        for (id, title, date) in upcoming {
            let c = UNMutableNotificationContent()
            c.title = "NOVA · Promemoria"
            c.body = title
            c.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            center.add(UNNotificationRequest(identifier: id, content: c,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
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

    private static func loginFlow(uid: String, pass: String, ident: String?, save: Bool) async -> [String: Any] {
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
                let events = await homework(token: token, studentID: studentID, pair: pair)
                return ["ok": 1, "name": name, "events": events]
            } catch {
                return ["ok": 0, "err": "rete", "info": error.localizedDescription]
            }
        }
        return ["ok": 0, "err": "rete", "info": "nessuna risposta"]
    }

    // Compiti (codice AGHW) da una settimana fa a tre settimane avanti.
    private static func homework(token: String, studentID: String, pair: Int) async -> [[String: Any]] {
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: now),
              let end = Calendar.current.date(byAdding: .day, value: 21, to: now) else { return [] }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        do {
            let (data, status) = try await call("/students/\(studentID)/agenda/AGHW/\(f.string(from: start))/\(f.string(from: end))", token: token, pair: pair)
            guard status == 200,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let agenda = j["agenda"] as? [[String: Any]] else { return [] }
            var out: [[String: Any]] = []
            for e in agenda {
                guard let id = e["evtId"] as? Int else { continue }
                let subj = (e["subjectDesc"] as? String ?? "Compito").capitalized
                let notes = (e["notes"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let author = (e["authorName"] as? String ?? "").capitalized
                var note = notes
                if !author.isEmpty { note = note.isEmpty ? author : note + " · " + author }
                var date = ""
                if let dtb = e["evtDatetimeBegin"] as? String { date = String(dtb.prefix(10)) }
                out.append(["id": id, "title": subj, "note": note, "date": date])
            }
            return out
        } catch {
            return []
        }
    }
}

