import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Security
import UserNotifications
import BackgroundTasks
import AuthenticationServices
import CryptoKit
import CoreLocation
import CoreHaptics
import AVFoundation
import WidgetKit
import LocalAuthentication

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
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(bridge, name: "nova")
        config.userContentController.addUserScript(
            WKUserScript(source: Bridge.polyfill(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = bridge
        bridge.rearmBgLocIfNeeded()
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.contentInset = .zero
        web.scrollView.verticalScrollIndicatorInsets = .zero
        web.scrollView.horizontalScrollIndicatorInsets = .zero
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        bridge.web = web
        if #available(iOS 26.0, *) { bridge.nativeComposer = NativeGlassComposer(web:web)
            bridge.nativeNavigation = NativeGlassNavigation(web:web)
            bridge.nativeSettings = NativeSettingsControls(web:web)
            bridge.nativeToast = NativeStatusNotice(web:web)
            config.userContentController.addUserScript(WKUserScript(source:"window.__novaNativeGlass=true",injectionTime:.atDocumentStart,forMainFrameOnly:true)) }
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
final class Bridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, UNUserNotificationCenterDelegate, AVAudioPlayerDelegate {
    weak var web: WKWebView?
    var nativeComposer: AnyObject?
    var nativeNavigation: AnyObject?
    var nativeSettings: AnyObject?
    var nativeToast: AnyObject?
    private let center = UNUserNotificationCenter.current()
    private var introAudio: AVAudioPlayer?
    private var introClips: [AVAudioPlayer] = []
    private var introIndex = 0
    private var introRunning = false
    private var introWork: DispatchWorkItem?
    private var introHapticPlayer: CHHapticPatternPlayer?
    private var fallbackWork: [DispatchWorkItem] = []
    private var hapticEngine: CHHapticEngine?

    private var locManager: CLLocationManager?
    private var locReadGeneration = 0
    private var locWaiting = false
    private var locLastError = -1
    private let bgUd = UserDefaults.standard
    private var bgTasks: [URLSessionDataTask] = []

    /// Posizione a app chiusa, SOLO su richiesta esplicita: aggiornamenti ai grandi spostamenti.
    /// Riattiva il monitoraggio dopo rilancio (anche in background) se l'utente lo aveva attivato.
    func rearmBgLocIfNeeded() {
        guard bgUd.bool(forKey: "nova.bgLoc.on"), bgUd.string(forKey: "nova.bgLoc.session") != nil else { return }
        if locManager == nil {
            let m = CLLocationManager()
            m.desiredAccuracy = kCLLocationAccuracyHundredMeters
            m.delegate = self
            locManager = m
        }
        if let m = locManager, m.authorizationStatus == .authorizedAlways {
            m.allowsBackgroundLocationUpdates = true
            m.pausesLocationUpdatesAutomatically = true
            m.startMonitoringSignificantLocationChanges()
        }
    }

    private func bgLocHandle(_ body: [String: Any]) {
        let on = (body["on"] as? Int ?? (body["on"] as? Bool == true ? 1 : 0)) == 1
        if !on { bgDisarm(); return }
        guard let session = body["session"] as? String, !session.isEmpty else { bgDisarm(); return }
        bgUd.set(session, forKey: "nova.bgLoc.session")
        if let tok = body["token"] as? String, !tok.isEmpty { bgUd.set(tok, forKey: "nova.bgLoc.token") }
        bgUd.set(body["sharing"] as? Bool ?? true, forKey: "nova.bgLoc.sharing")
        bgUd.set(true, forKey: "nova.bgLoc.on")
        if locManager == nil {
            let m = CLLocationManager()
            m.desiredAccuracy = kCLLocationAccuracyHundredMeters
            m.delegate = self
            locManager = m
        }
        guard let m = locManager else { return }
        switch m.authorizationStatus {
        case .authorizedAlways:
            bgArm(m)
        case .authorizedWhenInUse, .notDetermined:
            if body["restore"] as? Bool == true {
                bgDisarm()
                web?.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('off')")
            } else { m.requestAlwaysAuthorization() }
        case .denied, .restricted:
            bgDisarm()
            web?.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('denied')")
        @unknown default:
            break
        }
    }

    private func bgArm(_ m: CLLocationManager) {
        m.allowsBackgroundLocationUpdates = true
        m.pausesLocationUpdatesAutomatically = true
        m.startMonitoringSignificantLocationChanges()
        web?.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('on')")
    }

    private func bgDisarm() {
        bgTasks.forEach { $0.cancel() }; bgTasks.removeAll()
        bgUd.removeObject(forKey: "nova.bgLoc.session")
        bgUd.set(false, forKey: "nova.bgLoc.on")
        bgUd.removeObject(forKey: "nova.bgLoc.token")
        bgUd.removeObject(forKey: "nova.bgLoc.sharing")
        if let m = locManager {
            m.stopMonitoringSignificantLocationChanges()
            m.allowsBackgroundLocationUpdates = false
        }
        web?.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('off')")
    }

    private func bgUpload(_ l: CLLocation) {
        guard bgUd.bool(forKey: "nova.bgLoc.on"),
              bgUd.bool(forKey: "nova.bgLoc.sharing"),
              locManager?.authorizationStatus == .authorizedAlways,
              let session = bgUd.string(forKey: "nova.bgLoc.session"), !session.isEmpty,
              let tok = bgUd.string(forKey: "nova.bgLoc.token"), !tok.isEmpty,
              let url = URL(string: "https://api.federicotaranu.site/location") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["lat": l.coordinate.latitude, "lon": l.coordinate.longitude, "sharing": true, "session": session]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        bgTasks.removeAll { $0.state == .completed || $0.state == .canceling }
        let task = URLSession.shared.dataTask(with: req) { _, _, _ in }
        bgTasks.append(task); task.resume()
    }

    private func locReply(_ lat: Double = 0, _ lon: Double = 0, status: String, phase: String) {
        let auth = locManager.map { Int($0.authorizationStatus.rawValue) } ?? -1
        let detail = "auth=\(auth); cl=\(locLastError); phase=\(phase)"
        let args: [Any] = [lat, lon, status, detail]
        guard let data = try? JSONSerialization.data(withJSONObject: args), let json = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.web?.evaluateJavaScript("window.__novaLoc&&window.__novaLoc.apply(null,\(json))", completionHandler: nil)
        }
    }

    func locGet() {
        if !Thread.isMainThread { DispatchQueue.main.async { self.locGet() }; return }
        locLastError = -1
        if locManager == nil {
            let m = CLLocationManager()
            m.desiredAccuracy = kCLLocationAccuracyHundredMeters
            m.delegate = self
            locManager = m
        }
        guard let m = locManager else { return }
        switch m.authorizationStatus {
        case .notDetermined:
            m.requestWhenInUseAuthorization()
            // didChangeAuthorization riprova da solo; il timer JS copre il caso in cui non arriva risposta
        case .authorizedWhenInUse, .authorizedAlways:
            locRead(m)
        default:
            locReply(status: "denied", phase: "authorization")
        }
    }

    func locRead(_ m: CLLocationManager) {
        locReadGeneration += 1
        let generation = locReadGeneration
        locWaiting = true
        m.startUpdatingLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
            guard let self = self, self.locWaiting, generation == self.locReadGeneration else { return }
            self.locWaiting = false
            m.stopUpdatingLocation()
            self.locReply(status: "timeout", phase: "fix_timeout")
        }
    }

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
        faceIdSetup()
        center.delegate = self
        UIDevice.current.isBatteryMonitoringEnabled = true
        for n in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                self?.pushBattery()
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopIntro()
            self?.introEvent("end")
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

    // Feedback tattile in stile iOS: leggero sui tocchi, selezione sui segmenti, successo sui compiti completati.
    func haptic(_ style: String?) {
        switch style {
        case "selection": UISelectionFeedbackGenerator().selectionChanged()
        case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy": UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "warning": UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
        case "rumble": rumble()
        case "shakerumble": shakeRumble()
        default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // Bundled neural narration. No network, speech synthesizer or runtime service.
    private static let narration: [String] = [
        "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"
    ]

    // Start time (s) of each spoken word after the first, per narration clip, measured
    // from the bundled audio. The first word of each line is covered by the accent hit at t=0.
    private static let wordTicks: [[Double]] = [
        [0.25, 0.95],
        [0.20, 0.68, 1.18, 2.26, 2.40, 2.66],
        [1.37, 2.90, 4.57],
        [0.20]
    ]

    func introEvent(_ event: String, index: Int = 0) {
        web?.evaluateJavaScript("window.__novaIntro&&window.__novaIntro('\(event)',\(index))")
    }

    func stopIntro() {
        introRunning = false
        introWork?.cancel(); introWork = nil
        introAudio?.stop(); introAudio = nil
        introClips.removeAll()
        try? introHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        introHapticPlayer = nil
        fallbackWork.forEach { $0.cancel() }; fallbackWork.removeAll()
    }

    func startIntro() {
        stopIntro()
        do {
            // Ambient keeps the silent switch and other apps' audio intact.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            introClips = try Self.narration.map { encoded in
                guard let data = Data(base64Encoded: encoded) else { throw NSError(domain: "NOVAIntro", code: 1) }
                let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.m4a.rawValue)
                player.enableRate = true
                player.prepareToPlay()
                player.delegate = self
                return player
            }
            introRunning = true; introIndex = 0
            playIntroCue()
        } catch {
            stopIntro()
            introEvent("fallback")
        }
    }

    func playIntroCue() {
        guard introRunning else { return }
        guard introIndex < introClips.count else {
            introEvent("zoom"); shakeRumble()
            queueIntro(after: 2.9) { [weak self] in
                self?.stopIntro(); self?.introEvent("end")
            }
            return
        }
        let player = introClips[introIndex]
        introAudio = player
        introEvent("cue", index: introIndex)
        introBeat(index: introIndex, duration: player.duration / Double(player.rate))
        if !player.play() { advanceIntro() }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard introRunning, player === introAudio else { return }
        advanceIntro()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard introRunning, player === introAudio else { return }
        advanceIntro()
    }

    private func advanceIntro() {
        let pause = introIndex < 4 ? 0.24 : (introIndex == 4 ? 0.18 : 0.08)
        introIndex += 1
        queueIntro(after: pause) { [weak self] in self?.playIntroCue() }
    }

    private func queueIntro(after delay: Double, _ action: @escaping () -> Void) {
        introWork?.cancel()
        let work = DispatchWorkItem(block: action)
        introWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func transient(_ time: Double, _ strength: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: strength),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time)
    }

    private func playHaptics(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallback: [Double]) {
        try? introHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        fallbackWork.forEach { $0.cancel() }; fallbackWork.removeAll()
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                if hapticEngine == nil {
                    hapticEngine = try CHHapticEngine()
                    hapticEngine?.resetHandler = { [weak self] in try? self?.hapticEngine?.start() }
                }
                guard let engine = hapticEngine else { throw NSError(domain: "NOVAIntro", code: 2) }
                try engine.start()
                let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
                let player = try engine.makePlayer(with: pattern)
                introHapticPlayer = player // Keep alive throughout the pattern.
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch { /* Use impact generators on unsupported/interrupted engines. */ }
        }
        for time in fallback {
            let work = DispatchWorkItem {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
            }
            fallbackWork.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: work)
        }
    }

    // Layered haptics per narration line: an accent hit when the line lands, a swelling low
    // "underscore", an accelerating heartbeat (lub-dub) and one soft tick exactly when each
    // spoken word starts (aligned to the bundled narration, see wordTicks).
    func introBeat(index: Int, duration: Double) {
        let build = Float(index) / 3
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        var times: [Double] = [0]
        events.append(transient(0, 0.8 + 0.05 * Float(index), 0.5))
        let span = max(0.4, duration)
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3 + 0.1 * Float(index)),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
        ], relativeTime: 0.05, duration: span))
        curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.5),
            .init(relativeTime: span, value: 1.0)
        ], relativeTime: 0.05))
        let ticks = index < Self.wordTicks.count ? Self.wordTicks[index] : []
        for (w, t) in ticks.enumerated() {
            events.append(transient(t, min(0.9, 0.42 + 0.07 * Float(w)), 0.75))
            times.append(t)
        }
        let period = 0.85 - 0.07 * Double(index)
        var t = 0.4
        while t < duration - 0.2 {
            events.append(transient(t, 0.55 + 0.1 * build, 0.3))
            events.append(transient(t + 0.13, 0.4 + 0.1 * build, 0.25))
            times.append(t)
            t += period
        }
        playHaptics(events, curves: curves, fallback: times)
    }

    // Final push: rising full-scale rumble, accelerating impacts, then a double landing hit.
    func rumble() {
        let continuous = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        ], relativeTime: 0, duration: 1.3)
        let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.4),
            .init(relativeTime: 0.45, value: 0.7),
            .init(relativeTime: 0.95, value: 1.0),
            .init(relativeTime: 1.3, value: 1.0)
        ], relativeTime: 0)
        let sharp = CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [
            .init(relativeTime: 0, value: -0.3),
            .init(relativeTime: 1.0, value: 0.6),
            .init(relativeTime: 1.3, value: 0.0)
        ], relativeTime: 0)
        let times = [0.0, 0.26, 0.46, 0.62, 0.75, 0.86, 0.95, 1.03, 1.12, 1.24, 1.36]
        let hits = times.map { transient($0, 1.0, 0.9) }
        playHaptics([continuous] + hits, curves: [curve, sharp], fallback: times)
    }

    // Finale: the icon shake you feel — a rising bed with accelerating, strengthening hits
    // that ramp for as long as the on-screen shake grows (~2 s), then cut to black.
    func shakeRumble() {
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
        ], relativeTime: 0, duration: 2.25))
        curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.15),
            .init(relativeTime: 1.0, value: 0.45),
            .init(relativeTime: 1.7, value: 0.8),
            .init(relativeTime: 2.25, value: 1.0)
        ], relativeTime: 0))
        var times: [Double] = []
        var t = 0.0
        var step = 0.34
        while t < 2.2 {
            let p = Float(t / 2.25)
            events.append(transient(t, 0.25 + 0.75 * p, 0.4 + 0.6 * p))
            times.append(t)
            t += step
            step = max(0.06, step * 0.82)
        }
        playHaptics(events, curves: curves, fallback: times)
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
        // Converge la UI sullo stato nativo reale: attivo solo se autorizzato Sempre e mai spento.
        if bgUd.bool(forKey: "nova.bgLoc.on"), bgUd.string(forKey: "nova.bgLoc.session") != nil, let m = locManager ?? Optional(CLLocationManager()) {
            if m.delegate == nil { m.delegate = self; m.desiredAccuracy = kCLLocationAccuracyHundredMeters }
            locManager = m
            if m.authorizationStatus == .authorizedAlways {
                m.allowsBackgroundLocationUpdates = true
                m.pausesLocationUpdatesAutomatically = true
                m.startMonitoringSignificantLocationChanges()
                webView.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('on')")
            } else {
                bgDisarm()
                webView.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('wheninuse')")
            }
        }
        center.getNotificationSettings { s in
            let p = s.authorizationStatus == .authorized ? "granted" : (s.authorizationStatus == .denied ? "denied" : "default")
            DispatchQueue.main.async { webView.evaluateJavaScript("window.__novaPerm&&__novaPerm('\(p)')") }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let t = body["t"] as? String else { return }
        if t == "nativeToast" {
            if message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host.isEmpty, #available(iOS 26.0, *), let notice=nativeToast as? NativeStatusNotice { notice.show(body) }; return
        } else if t == "nativeSettings" {
            if message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host.isEmpty, #available(iOS 26.0, *), let settings=nativeSettings as? NativeSettingsControls { settings.sync(body) }; return
        } else if t == "nativeNavigation" {
            if message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host.isEmpty, #available(iOS 26.0, *), let navigation=nativeNavigation as? NativeGlassNavigation { navigation.sync(body) }; return
        } else if t == "nativeComposer" {
            if message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host.isEmpty, #available(iOS 26.0, *), let composer = nativeComposer as? NativeGlassComposer { composer.sync(body) }
            return
        } else if t == "perm" {
            center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                let p = ok ? "granted" : "denied"
                DispatchQueue.main.async { self.web?.evaluateJavaScript("__novaPerm('\(p)')") }
            }
        } else if t == "reminderOne" {
            scheduleOneReminder(body)
        } else if t == "sched", let items = body["items"] as? [[String: Any]] {
            schedule(items)
        } else if t == "plan", let items = body["items"] as? [[String: Any]] {
            planSchedule(items)
        } else if t == "hwn" {
            let on = body["on"] as? Bool ?? true
            UserDefaults.standard.set(on, forKey: "nova.hwn")
            if !on {
                center.getPendingNotificationRequests { reqs in
                    let ids = reqs.map { $0.identifier }.filter { $0.hasPrefix("plan.") || $0.hasPrefix("hw.") }
                    self.center.removePendingNotificationRequests(withIdentifiers: ids)
                }
            }
        } else if t == "faceid" {
            faceIdHandle(body)
        } else if t == "loc" {
            locGet()
        } else if t == "bgLoc" {
            bgLocHandle(body)
        } else if t == "haptic" {
            haptic(body["style"] as? String)
        } else if t == "locationSettings" {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        } else if t == "mediaAudio" {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
        } else if t == "intro" {
            if body["stop"] as? Bool == true { stopIntro() } else { startIntro() }
        } else if t == "timer" {
            scheduleTimer(body["at"] as? Double)
        } else if t == "spotify" {
            let reqId = body["id"] as? Int ?? 0
            Task {
                let result = await Spotify.handle(body)
                self.replyClasseViva(reqId, result)
            }
        } else if t == "tt" {
            let reqId = body["id"] as? Int ?? 0
            if (body["op"] as? String) == "hw" {
                let written = TT.saveHomework(body["json"] as? String ?? "")
                replyClasseViva(reqId, ["ok": 1, "shared": !written.isEmpty])
            } else {
                let written = TT.save(body["json"] as? String ?? "")
                replyClasseViva(reqId, ["ok": 1, "shared": !written.isEmpty, "ping": TT.widgetPing(), "groups": written])
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

    // Blocco app con Face ID / codice (impostazione facoltativa, salvata in UserDefaults)
    private var lockView: UIView?
    private var unlocking = false

    @objc private func appForegrounded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.web?.evaluateJavaScript("window.__novaForeground&&window.__novaForeground()", completionHandler: nil)
        }
    }

    func faceIdSetup() {
        NotificationCenter.default.addObserver(self, selector: #selector(appForegrounded), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBackgrounded), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        if UserDefaults.standard.bool(forKey: "nova.faceid") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.showLock(); self.tryUnlock() }
        }
    }

    @objc private func appBackgrounded() {
        if UserDefaults.standard.bool(forKey: "nova.faceid") { showLock() }
    }

    @objc private func appActive() {
        guard UserDefaults.standard.bool(forKey: "nova.faceid") else { return }
        if lockView == nil { showLock() }
        tryUnlock()
    }

    private func showLock() {
        guard lockView == nil, let web = web else { return }
        let parent: UIView = web.superview ?? web
        let v = UIView(frame: parent.bounds)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.backgroundColor = .black
        let l = UILabel()
        l.text = "NOVA è bloccata"
        l.textColor = .white
        l.font = .systemFont(ofSize: 20, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(l)
        let b = UIButton(type: .system)
        b.setTitle("Sblocca con Face ID", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(unlockTapped), for: .touchUpInside)
        v.addSubview(b)
        NSLayoutConstraint.activate([
            l.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            l.centerYAnchor.constraint(equalTo: v.centerYAnchor, constant: -30),
            b.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            b.topAnchor.constraint(equalTo: l.bottomAnchor, constant: 20)
        ])
        parent.addSubview(v)
        v.alpha = 0
        UIView.animate(withDuration: 0.15) { v.alpha = 1 }
        lockView = v
    }

    @objc private func unlockTapped() { tryUnlock() }

    private func tryUnlock() {
        if unlocking { return }
        unlocking = true
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // Nessun Face ID/codice configurato: non intrappolare l'utente fuori dalla sua app.
            unlocking = false
            hideLock()
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sblocca NOVA") { ok, _ in
            DispatchQueue.main.async {
                self.unlocking = false
                if ok { self.hideLock() }
            }
        }
    }

    private func hideLock() {
        guard let v = lockView else { return }
        lockView = nil
        UIView.animate(withDuration: 0.2, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }

    private func faceIdHandle(_ body: [String: Any]) {
        let op = body["op"] as? String ?? ""
        let reqId = body["id"] as? Int ?? 0
        if op == "has" {
            let ctx = LAContext()
            var e: NSError?
            let avail = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &e)
            replyClasseViva(reqId, ["ok": 1, "on": UserDefaults.standard.bool(forKey: "nova.faceid"), "avail": avail])
            return
        }
        if op == "set" {
            let on = body["on"] as? Bool ?? false
            if !on {
                UserDefaults.standard.set(false, forKey: "nova.faceid")
                hideLock()
                replyClasseViva(reqId, ["ok": 1, "on": false])
                return
            }
            let ctx = LAContext()
            var e: NSError?
            guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &e) else {
                replyClasseViva(reqId, ["ok": 0, "err": "noauth"])
                return
            }
            // Verifica subito: il blocco si attiva solo se Face ID/codice passa una prima volta.
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Attiva il blocco di NOVA") { ok, _ in
                DispatchQueue.main.async {
                    UserDefaults.standard.set(ok, forKey: "nova.faceid")
                    self.replyClasseViva(reqId, ["ok": 1, "on": ok])
                }
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
    // Acknowledge only after iOS accepted the local notification request.
    private func scheduleOneReminder(_ body: [String: Any]) {
        guard let id = body["id"] as? String, let at = body["at"] as? Double,
              let title = body["title"] as? String else { return }
        let reply: (Bool) -> Void = { ok in
            let data = try? JSONSerialization.data(withJSONObject: [id, ok])
            guard let data = data, let args = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self.web?.evaluateJavaScript("window.__novaReminderResult&&__novaReminderResult.apply(null,\(args))") }
        }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { reply(false); return }
            let seconds = at / 1000 - Date().timeIntervalSince1970
            guard seconds > 1 else { reply(false); return }
            let c = UNMutableNotificationContent()
            c.title = "NOVA · Promemoria"; c.body = String(title.prefix(200)); c.sound = .default
            let request = UNNotificationRequest(identifier: "manual." + id, content: c,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
            self.center.add(request) { error in reply(error == nil) }
        }
    }

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

    // Piano promemoria scelto dall'assistente IA: il JS lo manda dopo ogni aggiornamento.
    // Sostituisce il piano precedente e i promemoria automatici, e resta salvato così gli
    // aggiornamenti in background non ricreano duplicati per 36 ore.
    func planSchedule(_ items: [[String: Any]]) {
        guard HomeNotifs.enabled else { return }
        let now = Date()
        var valid: [[String: Any]] = []
        for i in items {
            guard let title = i["title"] as? String, let ms = i["at"] as? Double else { continue }
            guard Date(timeIntervalSince1970: ms / 1000) > now else { continue }
            valid.append(["title": title, "body": i["body"] as? String ?? title, "at": ms])
        }
        valid.sort { ($0["at"] as? Double ?? 0) < ($1["at"] as? Double ?? 0) }
        valid = Array(valid.prefix(25))
        UserDefaults.standard.set(["ts": now.timeIntervalSince1970, "items": valid], forKey: "nova.plan")
        center.getPendingNotificationRequests { reqs in
            let old = reqs.map { $0.identifier }.filter { $0.hasPrefix("plan.") || $0.hasPrefix("hw.day.") || $0.hasPrefix("hw.morn.") || $0.hasPrefix("hw.test.") }
            self.center.removePendingNotificationRequests(withIdentifiers: old)
        }
        let cal = Calendar.current
        for (n, i) in valid.enumerated() {
            let c = UNMutableNotificationContent()
            c.title = i["title"] as? String ?? "NOVA"
            c.body = i["body"] as? String ?? ""
            c.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: Date(timeIntervalSince1970: (i["at"] as? Double ?? 0) / 1000))
            center.add(UNNotificationRequest(identifier: "plan.\(n)", content: c,
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
                // Condivide compiti/verifiche col widget calendario del mese (pallini rossi/blu).
                // Gira anche negli aggiornamenti in background, quindi il widget resta fresco.
                var seenDots = Set<String>()
                var dots: [[String: String]] = []
                let mdf = DateFormatter()
                mdf.locale = Locale(identifier: "en_US_POSIX")
                mdf.dateFormat = "yyyy-MM-dd"
                var mcomps = Calendar.current.dateComponents([.year, .month], from: Date())
                mcomps.day = 1
                let monthStart = Calendar.current.date(from: mcomps).map { mdf.string(from: $0) } ?? ""
                for e in events {
                    guard let d = e["date"] as? String, d >= monthStart else { continue }
                    let k = (e["kind"] as? String) == "test" ? "test" : "hw"
                    if seenDots.insert(d + "|" + k).inserted { dots.append(["d": d, "k": k]) }
                }
                if let ddata = try? JSONSerialization.data(withJSONObject: ["v": 1, "dots": dots]),
                   let djson = String(data: ddata, encoding: .utf8) {
                    _ = TT.saveEvents(djson)
                }
                let todayStr = mdf.string(from: Date())
                let hwItems = events.compactMap { e -> [String: String]? in
                    guard (e["kind"] as? String) == "hw",
                          let d = e["date"] as? String, d >= todayStr,
                          let t = e["title"] as? String else { return nil }
                    return ["t": t, "s": e["subj"] as? String ?? "", "d": d]
                }
                if let hdata = try? JSONSerialization.data(withJSONObject: ["v": 1, "items": hwItems]),
                   let hjson = String(data: hdata, encoding: .utf8) {
                    _ = TT.saveHomework(hjson)
                }
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
    static let id = "federicotaranu.site.refresh"

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

        // Se l'assistente IA ha programmato un piano nelle ultime 36 ore, quello vince:
        // niente promemoria automatici duplicati. Scaduto, tornano gli orari automatici.
        if let plan = UserDefaults.standard.dictionary(forKey: "nova.plan"), let ts = plan["ts"] as? Double {
            if Date().timeIntervalSince1970 - ts < 36 * 3600 { return }
            UserDefaults.standard.removeObject(forKey: "nova.plan")
        }
        // Promemoria automatici di riserva (senza piano IA):
        // - la mattina del giorno di scadenza alle 6:30 ("Per oggi", prima che esca di casa)
        // - la sera prima: alle 16:30 se quel giorno ci sono 3+ cose da fare, altrimenti 18:30
        // - le verifiche hanno anche un avviso due giorni prima, alle 18:30
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map { $0.identifier }.filter { $0.hasPrefix("hw.day.") || $0.hasPrefix("hw.morn.") || $0.hasPrefix("hw.test.") || $0.hasPrefix("plan.") })
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        var byDay: [String: [[String: Any]]] = [:]
        for e in events { if let d = e["date"] as? String { byDay[d, default: []].append(e) } }
        let cal = Calendar.current
        let now = Date()
        var count = 0
        for day in byDay.keys.sorted() {
            guard let due = f.date(from: day), let items = byDay[day] else { continue }
            let tests = items.filter { ($0["kind"] as? String) == "test" }
            let eveHour = items.count >= 3 ? 16 : 18
            let slots: [(id: String, title: String, bodyItems: [[String: Any]], fire: Date?)] = [
                ("hw.morn.\(day)", "NOVA · Per oggi", items,
                 cal.date(bySettingHour: 6, minute: 30, second: 0, of: due)),
                ("hw.day.\(day)", "NOVA · Per domani", items,
                 cal.date(byAdding: .day, value: -1, to: due).flatMap { cal.date(bySettingHour: eveHour, minute: 30, second: 0, of: $0) }),
                ("hw.test.\(day)", tests.count == 1 ? "NOVA · Verifica tra 2 giorni" : "NOVA · Verifiche tra 2 giorni", tests,
                 tests.isEmpty ? nil : cal.date(byAdding: .day, value: -2, to: due).flatMap { cal.date(bySettingHour: 18, minute: 30, second: 0, of: $0) })
            ]
            for slot in slots {
                guard count < 40, let fire = slot.fire, fire > now else { continue }
                let c = UNMutableNotificationContent()
                c.title = slot.title
                var lines = slot.bodyItems.prefix(4).map { line($0) }
                if slot.bodyItems.count > 4 { lines.append("+ altri \(slot.bodyItems.count - 4)") }
                c.body = lines.joined(separator: "\n")
                c.sound = .default
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                try? await center.add(UNNotificationRequest(identifier: slot.id, content: c,
                                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                count += 1
            }
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

// MARK: - Orario personale condiviso con i widget (App Group)

enum TT {
    // AltStore/SideStore rinominano i gruppi come group.<id>.<TEAMID> e li pubblicano in ALTAppGroups,
    // ma non sempre in TUTTI i bundle (app si, widget no). Come ridondanza ricaviamo il nome anche
    // dal bundle ID resigned: app = federicotaranu.site.<TEAMID>, widget = federicotaranu.site.<TEAMID>.NOVAWidget.
    static func groupIDs() -> [String] {
        var ids: [String] = []
        if let a = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { ids += a }
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

    static func containers() -> [(id: String, url: URL)] {
        var out: [(id: String, url: URL)] = []
        var seenPaths = Set<String>()
        for id in groupIDs() {
            guard let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id),
                  seenPaths.insert(u.path).inserted else { continue }
            out.append((id, u))
        }
        return out
    }

    // Scrive in TUTTI i contenitori raggiungibili: se app e widget risolvono gruppi diversi,
    // il file arriva comunque a quello che il widget riesce a leggere.
    static func save(_ json: String) -> [String] {
        var written: [String] = []
        for (id, u) in containers() {
            do {
                try json.write(to: u.appendingPathComponent("timetable.json"), atomically: true, encoding: .utf8)
                written.append(id)
            } catch {}
        }
        if !written.isEmpty {
            WidgetCenter.shared.reloadAllTimelines()
            for kind in ["NOVAOrarioWidget", "NOVAOggiWidget", "NOVAFineWidget", "NOVAMeseWidget", "NOVACompitiWidget"] {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        }
        return written
    }

    // Vero solo se il widget ha davvero letto da un contenitore condiviso (ci scrive un ping).
    static func widgetPing() -> Bool {
        for (_, u) in containers() {
            if FileManager.default.fileExists(atPath: u.appendingPathComponent("widgetping.json").path) { return true }
        }
        return false
    }

    // Compiti e verifiche per il widget calendario (pallini del mese): stesso ponte dell'orario.
    static func saveEvents(_ json: String) -> [String] {
        var written: [String] = []
        for (id, u) in containers() {
            do {
                try json.write(to: u.appendingPathComponent("events.json"), atomically: true, encoding: .utf8)
                written.append(id)
            } catch {}
        }
        if !written.isEmpty { WidgetCenter.shared.reloadTimelines(ofKind: "NOVAMeseWidget") }
        return written
    }

    // Compiti aperti per il widget "Compiti di domani": li scrive l'app (rispetta
    // i segnati come fatti) e il refresh ClasseViva (novita' dal registro).
    static func saveHomework(_ json: String) -> [String] {
        var written: [String] = []
        for (id, u) in containers() {
            do {
                try json.write(to: u.appendingPathComponent("homework.json"), atomically: true, encoding: .utf8)
                written.append(id)
            } catch {}
        }
        if !written.isEmpty { WidgetCenter.shared.reloadTimelines(ofKind: "NOVACompitiWidget") }
        return written
    }
}

// MARK: - Groq (chatbot): api.groq.com, NON Grok di xAI

enum Groq {
    // Groq depreca in fretta: llama-4 vision spenti a meta 2026, llama-3.x chat spenti ago 2026.
    // Vivi ora (ott 2026): gpt-oss per chat, qwen3.8-27b per vision. Controlla console.groq.com/docs/deprecations.
    static let models = ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b"]
    static let visionModels = ["qwen/qwen3.8-27b"]
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
                let body: [String: Any] = ["model": model, "messages": msgs, "temperature": 0.5, "max_tokens": 2500, "reasoning_effort": "low"]
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
        case "vision":
            guard let key = Secret.get("groq") else { return ["ok": 0, "err": "nokey"] }
            let prompt = msg["prompt"] as? String ?? ""
            let img = msg["img"] as? String ?? ""
            guard img.hasPrefix("data:image/") else { return ["ok": 0, "err": "img"] }
            let content: [[String: Any]] = [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": img]]
            ]
            var lastInfo = ""
            for model in visionModels {
                var req = URLRequest(url: URL(string: base + "/chat/completions")!)
                req.httpMethod = "POST"
                req.timeoutInterval = 90
                req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "model": model,
                    "messages": [["role": "user", "content": content]],
                    "temperature": 0,
                    "max_tokens": 3000,
                    "reasoning_effort": "none",
                    "response_format": ["type": "json_object"]
                ]
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
                    if let txt = String(data: data, encoding: .utf8) { lastInfo = String(txt.prefix(300)) }
                } catch { return ["ok": 0, "err": "rete"] }
            }
            return ["ok": 0, "err": "modello", "info": lastInfo]
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

// Delegate posizione: senza questi metodi requestLocation() fa terminare l'app.
extension Bridge: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last, l.horizontalAccuracy >= 0,
              abs(l.timestamp.timeIntervalSinceNow) < 60 else { return }
        if locWaiting { locWaiting = false; locReadGeneration += 1; manager.stopUpdatingLocation() }
        locReply(l.coordinate.latitude, l.coordinate.longitude, status: "ok", phase: "fix_received")
        bgUpload(l)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locLastError = (error as NSError).code
        if (error as? CLError)?.code == .locationUnknown { return }
        guard locWaiting else { return }
        locWaiting = false; locReadGeneration += 1; manager.stopUpdatingLocation()
        locReply(status: "unavailable", phase: "delegate_error")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locRead(manager)
        case .denied, .restricted:
            locReply(status: "denied", phase: "authorization")
        default:
            break
        }
        guard bgUd.bool(forKey: "nova.bgLoc.on"), bgUd.string(forKey: "nova.bgLoc.session") != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways:
            bgArm(manager)
        case .authorizedWhenInUse:
            bgDisarm()
            web?.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('wheninuse')")
        case .denied, .restricted:
            bgDisarm()
            web?.evaluateJavaScript("window.__novaBgLoc&&__novaBgLoc('denied')")
        default:
            break
        }
    }
}
// Native iOS26 Liquid Glass message control; older versions keep the web composer.
@available(iOS 26.0, *)
final class NativeGlassComposer: NSObject, UITextFieldDelegate, PHPickerViewControllerDelegate {
 weak var web: WKWebView?
 let surface=UIVisualEffectView(effect: UIGlassEffect(style:.clear))
 let permissions=UIButton(type:.system)
 let photo=UIButton(type:.system), mic=UIButton(type:.system), send=UIButton(type:.system), input=UITextField()
 var mode="", account="", remote="";var row=CGRect.zero;var keyboard:CGFloat=0
 init(web:WKWebView){super.init();self.web=web
 let effect=UIGlassEffect(style:.clear);effect.isInteractive=true;surface.effect=effect;surface.cornerConfiguration = .capsule()
 surface.accessibilityIdentifier="nativeLiquidGlassComposer"
 input.placeholder="Scrivi un messaggio";input.font = .systemFont(ofSize:16);input.delegate=self;input.accessibilityLabel="Messaggio";input.returnKeyType = .send
 input.addTarget(self,action:#selector(changed),for:.editingChanged)
 for (b,symbol,label) in [(permissions,"slider.horizontal.3","Permessi azioni"),(photo,"plus","Invia foto"),(mic,"mic","Messaggio vocale"),(send,"arrow.up.circle.fill","Invia")]{b.setImage(UIImage(systemName:symbol),for:.normal);b.accessibilityLabel=label;b.tintColor = .label;b.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([b.widthAnchor.constraint(equalToConstant:44),b.heightAnchor.constraint(equalToConstant:44)])}
 permissions.addTarget(self,action:#selector(permission),for:.touchUpInside)
 photo.addTarget(self,action:#selector(pick),for:.touchUpInside);mic.addTarget(self,action:#selector(record),for:.touchUpInside);send.addTarget(self,action:#selector(submit),for:.touchUpInside)
 let stack=UIStackView(arrangedSubviews:[photo,permissions,input,mic,send]);stack.spacing=4;stack.alignment = .center;stack.translatesAutoresizingMaskIntoConstraints=false;surface.contentView.addSubview(stack)
 NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:surface.contentView.leadingAnchor,constant:5),stack.trailingAnchor.constraint(equalTo:surface.contentView.trailingAnchor,constant:-5),stack.topAnchor.constraint(equalTo:surface.contentView.topAnchor,constant:5),stack.bottomAnchor.constraint(equalTo:surface.contentView.bottomAnchor,constant:-5)])
 web.addSubview(surface);surface.isHidden=true
 NotificationCenter.default.addObserver(self,selector:#selector(keyboardChanged(_:)),name:UIResponder.keyboardWillChangeFrameNotification,object:nil)
 }
 func sync(_ b:[String:Any]){guard let web=web else{return};let show=(b["show"] as? Bool ?? false) && (b["w"] as? CGFloat ?? 0)>100 && (b["y"] as? CGFloat ?? 0)>web.safeAreaInsets.top
 if !show{surface.isHidden=true;input.resignFirstResponder();mode="";return}
 let m=b["mode"] as? String ?? "",a=b["account"] as? String ?? ""
 if mode != m || account != a{input.resignFirstResponder();mode=m;account=a;input.text=b["value"] as? String ?? ""}
 let value=b["value"] as? String ?? "";if value != remote{input.text=value;remote=value}
 mic.setImage(UIImage(systemName:(b["recording"] as? Bool ?? false) ? "stop.circle.fill":"mic"),for:.normal);mic.tintColor=(b["recording"] as? Bool ?? false) ? .systemRed:.label;mic.isHidden=m != "friend";permissions.isHidden=m != "ai";photo.accessibilityLabel=m=="friend" ? "Invia foto":"Aggiungi foto";surface.isHidden=false
 surface.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;input.textColor = .label
 row=CGRect(x:(b["x"] as? CGFloat ?? 10),y:(b["y"] as? CGFloat ?? 0),width:(b["w"] as? CGFloat ?? web.bounds.width-20),height:56);layout()
 }
 func layout(){guard let web=web else{return};var r=row;if keyboard>0{r.origin.y=min(r.origin.y,web.bounds.height-keyboard-64)};surface.frame=r;web.bringSubviewToFront(surface)}
 @objc func keyboardChanged(_ n:Notification){guard let web=web,let frame=n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else{return};let f=web.convert(frame,from:nil);keyboard=max(0,web.bounds.maxY-f.minY);layout()}
 func script(_ s:String){web?.evaluateJavaScript(s,completionHandler:nil)}
 func quoted(_ s:String)->String{String(data:try! JSONSerialization.data(withJSONObject:[s]),encoding:.utf8)!.dropFirst().dropLast().description}
 @objc func changed(){let text=String((input.text ?? "").prefix(mode=="friend" ? 4000:1500));if input.text != text{input.text=text};remote=text;script("window.__nativeComposerInput&&__nativeComposerInput("+quoted(mode)+","+quoted(text)+","+quoted(account)+")")}
 @objc func permission(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'permissions',"+quoted(account)+")")}
 var pickerOwner="",pickerMode="";weak var activePicker:PHPickerViewController?
 @objc func pick(){guard let web=web,var controller=web.window?.rootViewController else{return};while let presented=controller.presentedViewController{controller=presented};pickerOwner=account;pickerMode=mode;var config=PHPickerConfiguration();config.filter = .images;config.selectionLimit=1;let picker=PHPickerViewController(configuration:config);picker.delegate=self;activePicker=picker;controller.present(picker,animated:true)}
 func picker(_ picker:PHPickerViewController,didFinishPicking results:[PHPickerResult]){picker.dismiss(animated:true);guard let provider=results.first?.itemProvider,provider.canLoadObject(ofClass:UIImage.self) else{return};consumeImageProvider(provider)
 }
 func consumeImageProvider(_ provider:NSItemProvider){let owner=pickerOwner,m=pickerMode
 provider.loadObject(ofClass:UIImage.self){[weak self] image,_ in guard let self=self,let img=image as? UIImage else{return};let ratio=min(1,1600/max(img.size.width,img.size.height));let size=CGSize(width:img.size.width*ratio,height:img.size.height*ratio);let resized=UIGraphicsImageRenderer(size:size).image{_ in img.draw(in:CGRect(origin:.zero,size:size))};guard let data=resized.jpegData(compressionQuality:0.75) else{return};DispatchQueue.main.async{guard self.account==owner,self.mode==m else{return};self.script("window.__nativeComposerPhoto&&__nativeComposerPhoto("+self.quoted(m)+","+self.quoted(owner)+","+self.quoted(data.base64EncodedString())+")")}}
 }
 @objc func record(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'mic',"+quoted(account)+")")}
 @objc func submit(){guard !(input.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return};changed();script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'send',"+quoted(account)+")");input.text="";remote=""}
 func textFieldShouldReturn(_ textField:UITextField)->Bool{submit();return false}
}

@available(iOS 26.0, *)
final class NativeLensSegments:UISegmentedControl {
 var trackingEvent:((String,CGFloat)->Void)?
 override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool{let accepted=super.beginTracking(touch,with:event);if accepted{trackingEvent?("start",touch.location(in:self).x)};return accepted}
 override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool{let accepted=super.continueTracking(touch,with:event);trackingEvent?("move",touch.location(in:self).x);return accepted}
 override func endTracking(_ touch:UITouch?,with event:UIEvent?){super.endTracking(touch,with:event);trackingEvent?("end",touch?.location(in:self).x ?? 0)}
 override func cancelTracking(with event:UIEvent?){super.cancelTracking(with:event);trackingEvent?("cancel",0)}
}
@available(iOS 26.0, *)
final class NativeGlassNavigation:NSObject,UIGestureRecognizerDelegate {
 weak var web:WKWebView?;let surface=NativeLensSegments(items:[]);let backdrop=UIVisualEffectView(effect:UIGlassEffect(style:.regular));var dragStart=0;var selected=0;var avatarBinding="";var mapViews:[String:UIVisualEffectView]=[:];var mapButtons:[String:UIButton]=[:];var mapOwner=""
 init(web:WKWebView){super.init();self.web=web;surface.accessibilityIdentifier="nativeLiquidGlassNavigation"
 for(i,item)in [("house","Home"),("chart.bar","Voti"),("bubble.left.and.bubble.right","Chat"),("mappin","Mappa"),("person.crop.circle","Profilo")].enumerated(){
 let image=UIGraphicsImageRenderer(size:CGSize(width:60,height:46)).image{_ in
 UIImage(systemName:item.0,withConfiguration:UIImage.SymbolConfiguration(pointSize:22,weight:.regular))?.withTintColor(.white,renderingMode:.alwaysOriginal).draw(in:CGRect(x:17,y:0,width:26,height:26))
 let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:10,weight:.semibold),.foregroundColor:UIColor.white];let text=item.1 as NSString;let size=text.size(withAttributes:attrs);text.draw(at:CGPoint(x:(60-size.width)/2,y:30),withAttributes:attrs)
 }.withRenderingMode(.alwaysTemplate)
 surface.insertSegment(with:image,at:i,animated:false);surface.accessibilityLabel="Navigazione"
 }
 backdrop.isUserInteractionEnabled=false;backdrop.cornerConfiguration = .capsule();backdrop.clipsToBounds=false;web.addSubview(backdrop);backdrop.isHidden=true
 surface.trackingEvent={[weak self] phase,x in guard let self=self else{return};if phase=="start"{self.dragStart=self.selected}
 let position=max(0,min(4,x/(self.surface.bounds.width/5)-0.5)),delta=(CGFloat(self.dragStart)-position)*(self.web?.bounds.width ?? 390)*0.25
 if phase=="cancel"{self.web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(self.dragStart))",completionHandler:nil);return}
 if phase=="end"{self.web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(max(0,self.surface.selectedSegmentIndex)))",completionHandler:nil);return}
 // Native lens tracks touch, content stays on its current page until release.
 }
 let observer=UILongPressGestureRecognizer(target:self,action:#selector(observeDrag(_:)));observer.minimumPressDuration=0;observer.allowableMovement=10000;observer.cancelsTouchesInView=false;observer.delaysTouchesBegan=false;observer.delaysTouchesEnded=false;observer.delegate=self;surface.addGestureRecognizer(observer)
 surface.addTarget(self,action:#selector(changed),for:.valueChanged);web.addSubview(surface);surface.isHidden=true
 }
 @objc func mapTap(_ sender:UIButton){guard let id=sender.accessibilityIdentifier else{return};let o=(try? JSONSerialization.data(withJSONObject:[mapOwner])).flatMap{String(data:$0,encoding:.utf8)} ?? "[\"\"]";let owner=String(o.dropFirst().dropLast());web?.evaluateJavaScript("window.__nativeMapAction&&__nativeMapAction('\(id)',\(owner))",completionHandler:nil)}
 func syncMap(_ b:[String:Any]){guard let web=web else{return};mapOwner=b["account"] as? String ?? "";let show=b["mapShow"] as? Bool ?? false
 for item in b["mapRects"] as? [[String:Any]] ?? []{guard let id=item["id"] as? String else{continue};let v:UIVisualEffectView,button:UIButton
 if let old=mapViews[id],let oldButton=mapButtons[id]{v=old;button=oldButton}else{let effect=UIGlassEffect(style:.clear);effect.isInteractive=true;v=UIVisualEffectView(effect:effect);v.cornerConfiguration = .capsule();button=UIButton(type:.system);button.accessibilityIdentifier=id;button.addTarget(self,action:#selector(mapTap(_:)),for:.touchUpInside);v.contentView.addSubview(button);web.addSubview(v);mapViews[id]=v;mapButtons[id]=button}
 let r=CGRect(x:item["x"] as? CGFloat ?? 0,y:item["y"] as? CGFloat ?? 0,width:item["w"] as? CGFloat ?? 0,height:item["h"] as? CGFloat ?? 0);v.frame=r;button.frame=v.bounds;v.isHidden = !show || r.width<20 || r.height<20;v.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light
 let symbol=id=="mapSh" ? "ghost" : id=="mapOptions" ? "gearshape" : "location.fill";button.setImage(UIImage(systemName:symbol,withConfiguration:UIImage.SymbolConfiguration(pointSize:24)),for:.normal);if id=="mapSh"{let image=UIGraphicsImageRenderer(size:CGSize(width:28,height:28)).image{ctx in UIColor.white.setStroke();let p=UIBezierPath();p.move(to:CGPoint(x:5,y:25));p.addLine(to:CGPoint(x:5,y:12));p.addArc(withCenter:CGPoint(x:14,y:12),radius:9,startAngle:.pi,endAngle:0,clockwise:true);p.addLine(to:CGPoint(x:23,y:25));p.addLine(to:CGPoint(x:18,y:22));p.addLine(to:CGPoint(x:14,y:25));p.addLine(to:CGPoint(x:10,y:22));p.close();p.lineWidth=1.8;p.stroke();UIColor.white.setFill();UIBezierPath(ovalIn:CGRect(x:9,y:10,width:3,height:4)).fill();UIBezierPath(ovalIn:CGRect(x:16,y:10,width:3,height:4)).fill()}.withRenderingMode(.alwaysTemplate);button.setImage(image,for:.normal)};button.tintColor = .label;button.accessibilityLabel=id=="mapSh" ? ((b["mapGhost"] as? Bool ?? false) ? "Fantasma attivo":"Visibile agli amici") : id=="mapOptions" ? "Impostazioni mappa":"Centra la mia posizione";if !v.isHidden{web.bringSubviewToFront(v)}
 }
 }
 func syncAvatar(_ b:[String:Any]){
 let account=b["account"] as? String ?? "",raw=b["avatar"] as? String ?? "",binding=account+":"+raw+":"+String(b["dark"] as? Bool ?? false)
 guard binding != avatarBinding else{return};avatarBinding=binding
 let dark=b["dark"] as? Bool ?? false;let ink:UIColor=dark ? .white:.black
 var photo:UIImage?=nil
 if !account.isEmpty,raw.count<=160000,raw.hasPrefix("data:image/"),let comma=raw.firstIndex(of:","),let data=Data(base64Encoded:String(raw[raw.index(after:comma)...])){photo=UIImage(data:data)}
 let image=UIGraphicsImageRenderer(size:CGSize(width:60,height:46)).image{ctx in
 if let photo=photo{ctx.cgContext.saveGState();UIBezierPath(ovalIn:CGRect(x:17,y:0,width:26,height:26)).addClip();photo.draw(in:CGRect(x:17,y:0,width:26,height:26));ctx.cgContext.restoreGState()}else{UIImage(systemName:"person.crop.circle",withConfiguration:UIImage.SymbolConfiguration(pointSize:22))?.withTintColor(ink,renderingMode:.alwaysOriginal).draw(in:CGRect(x:17,y:0,width:26,height:26))}
 let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:10,weight:.semibold),.foregroundColor:ink];let text="Profilo" as NSString;let size=text.size(withAttributes:attrs);text.draw(at:CGPoint(x:(60-size.width)/2,y:30),withAttributes:attrs)
 }.withRenderingMode(.alwaysOriginal)
 surface.setImage(image,forSegmentAt:4)
 }
 func sync(_ b:[String:Any]){syncMap(b);syncAvatar(b);surface.isHidden = !(b["show"] as? Bool ?? false);backdrop.isHidden=surface.isHidden;if surface.isHidden{return};backdrop.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;surface.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;surface.frame=CGRect(x:b["x"] as? CGFloat ?? 10,y:b["y"] as? CGFloat ?? 0,width:b["w"] as? CGFloat ?? 300,height:64);backdrop.frame=surface.frame;backdrop.layer.cornerRadius=32;selected=b["selected"] as? Int ?? 0;if !surface.isTracking{surface.selectedSegmentIndex=selected}}
 func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer)->Bool{return true}
 @objc func observeDrag(_ g:UILongPressGestureRecognizer){let phase:String;switch g.state{case .began:phase="start";case .changed:phase="move";case .ended:phase="end";case .cancelled,.failed:phase="cancel";default:return};surface.trackingEvent?(phase,g.location(in:surface).x)}
 @objc func changed(){if surface.isTracking{return};web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(surface.selectedSegmentIndex))",completionHandler:nil)}
}

// Real system switches sit over the opaque settings rows; the existing handlers own all state and permissions.
@available(iOS 26.0, *)
final class NativeSettingsControls:NSObject {
 weak var web:WKWebView?;var switches:[String:UISwitch]=[:];var owner="";var epoch=0;var shown=false
 let done=UIButton(type:.system)
 init(web:WKWebView){super.init();self.web=web;var c=UIButton.Configuration.glass();c.title="Fatto";done.configuration=c;done.accessibilityIdentifier="nativeSettingsDone";done.addTarget(self,action:#selector(closeSettings),for:.touchUpInside);done.isHidden=true;web.addSubview(done)}
 func quoted(_ value:String)->String{let d=try! JSONSerialization.data(withJSONObject:[value]);return String(String(data:d,encoding:.utf8)!.dropFirst().dropLast())}
 @objc func closeSettings(){guard shown else{return};web?.evaluateJavaScript("window.__nativeSettingsClose&&__nativeSettingsClose(\(quoted(owner)),\(epoch))",completionHandler:nil)}
 @objc func changed(_ sender:UISwitch){guard shown,let id=sender.accessibilityIdentifier else{return};sender.isEnabled=false;web?.evaluateJavaScript("window.__nativeSettingsToggle&&__nativeSettingsToggle(\(quoted(id)),\(quoted(owner)),\(epoch),\(!sender.isOn))",completionHandler:nil)}
 func sync(_ b:[String:Any]){guard let web=web else{return};shown=b["show"] as? Bool ?? false;owner=b["account"] as? String ?? "";epoch=b["epoch"] as? Int ?? 0;let dark=b["dark"] as? Bool ?? false;done.overrideUserInterfaceStyle=dark ? .dark:.light;done.isHidden = !shown
 if let r=b["done"] as? [String:Any]{done.frame=CGRect(x:r["x"] as? CGFloat ?? 0,y:r["y"] as? CGFloat ?? 0,width:r["w"] as? CGFloat ?? 76,height:r["h"] as? CGFloat ?? 44)}
 var active=Set<String>();for row in b["items"] as? [[String:Any]] ?? []{guard let id=row["id"] as? String else{continue};guard ["bHw","bIntro","bFid","bDiag","bNtfyPv","settingsWidget_wx","settingsWidget_bat","settingsWidget_cal","settingsWidget_task","settingsWidget_nx","settingsWidget_sp"].contains(id) else{continue};active.insert(id);let control:UISwitch;if let old=switches[id]{control=old}else{control=UISwitch();control.accessibilityIdentifier=id;control.addTarget(self,action:#selector(changed(_:)),for:.valueChanged);web.addSubview(control);switches[id]=control};control.overrideUserInterfaceStyle=dark ? .dark:.light;control.accessibilityLabel=row["label"] as? String;control.setOn(row["on"] as? Bool ?? false,animated:false);control.isEnabled = !(row["disabled"] as? Bool ?? false);control.frame.origin=CGPoint(x:row["x"] as? CGFloat ?? 0,y:row["y"] as? CGFloat ?? 0);control.isHidden = !shown || !(row["show"] as? Bool ?? false);if !control.isHidden{web.bringSubviewToFront(control)}}
 for(id,c)in switches where !active.contains(id){c.isHidden=true};if shown{web.bringSubviewToFront(done)}
 }
}

@available(iOS 26.0, *)
final class NativeStatusNotice:NSObject {
 weak var web:WKWebView?;let card=UIVisualEffectView(effect:UIGlassEffect(style:.clear));let label=UILabel();var dismissal:DispatchWorkItem?
 init(web:WKWebView){super.init();self.web=web;card.cornerConfiguration = .capsule();card.isUserInteractionEnabled=false;label.font = .preferredFont(forTextStyle:.body);label.adjustsFontForContentSizeCategory=true;label.numberOfLines=0;label.textAlignment = .center;label.textColor = .label;card.contentView.addSubview(label);card.accessibilityIdentifier="nativeCenteredStatus";card.isHidden=true;web.addSubview(card)}
 func show(_ b:[String:Any]){guard let web=web,let text=b["text"] as? String,!text.isEmpty else{return};dismissal?.cancel();label.text=String(text.prefix(1000));card.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;let width=min(web.bounds.width-40,360),size=label.sizeThatFits(CGSize(width:width-40,height:web.bounds.height*0.55));let height=min(max(64,size.height+36),web.bounds.height*0.65);card.frame=CGRect(x:(web.bounds.width-width)/2,y:(web.bounds.height-height)/2,width:width,height:height);label.frame=card.bounds.insetBy(dx:20,dy:18);card.layer.cornerRadius=min(32,height/2);card.isHidden=false;card.alpha=1;web.bringSubviewToFront(card);UIAccessibility.post(notification:.announcement,argument:text);let work=DispatchWorkItem{[weak self] in self?.card.isHidden=true};dismissal=work;DispatchQueue.main.asyncAfter(deadline:.now()+5,execute:work)}
}
