import SwiftUI
import UIKit
import WebKit
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

/// Ponte nativo: batteria reale, schermo acceso in carica, notifiche locali.
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
