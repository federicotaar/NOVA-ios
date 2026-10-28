import SwiftUI
import CoreLocation
import Combine

// Bound to the Swift archive. No permission request occurs from bind or appearance.
@MainActor final class NOVASwiftBackgroundLocation:NSObject,ObservableObject,@preconcurrency CLLocationManagerDelegate {
    static let shared=NOVASwiftBackgroundLocation()
    @Published private(set) var status=""
    private let manager=CLLocationManager()
    private weak var store:NOVASwiftStore?
    private var observation:AnyCancellable?
    private var jobs:[URLSessionDataTask]=[]
    private var consentSession:NOVASession?
    private var requesting=false
    private override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters}
    func bind(_ store:NOVASwiftStore){if self.store===store,observation != nil{reconcile();return};self.store=store;observation=store.$archive.sink{[weak self] _ in Task{@MainActor in self?.reconcile()}};reconcile()}
    func unbind(){stop(clear:false);observation=nil;store=nil}
    func enabled(_ on:Bool,_ store:NOVASwiftStore){
        bind(store)
        guard on else{stop(clear:true);return}
        guard let state=store.archive?.active,let session=NOVASession(state),NOVASwiftLocationConsent.sharing(state.object ?? [:]),state.object?["locSessionToken"]?.string==session.token,!(state.object?["locSession"]?.string ?? "").isEmpty else{status="Attiva prima la condivisione sulla mappa.";return}
        consentSession=session;requesting=true
        switch manager.authorizationStatus {
        case .authorizedAlways:activate()
        case .notDetermined:manager.requestWhenInUseAuthorization();status="Consenti la posizione, poi scegli Sempre nelle impostazioni di iOS."
        case .authorizedWhenInUse:manager.requestAlwaysAuthorization();status="Per gli aggiornamenti a app chiusa scegli Sempre nelle impostazioni di iOS."
        default:requesting=false;status="Posizione non autorizzata. Apri le impostazioni di iOS."
        }
    }
    private func activate(){guard let store=store,let state=store.archive?.active,let owner=NOVASession(state),consentSession==owner,NOVASwiftLocationConsent.sharing(state.object ?? [:]),manager.authorizationStatus == .authorizedAlways else{stop(clear:false);return};do{try store.update(owner:store.archive!.owner){$0["bgLoc"] = .number(1);$0["bgConsentV2"] = $0["locSession"]};requesting=false;reconcile();status="Aggiornamenti ai grandi spostamenti attivi. Non sono un tracciamento continuo."}catch{stop(clear:false);status="Scelta non salvata. Riprova."}}
    private func reconcile(){
        if requesting,let store=store,store.archive.flatMap({NOVASession($0.active)})==consentSession,store.archive?.active.object?["locShare"]?.flag==true{return}
        guard let store=store,let root=store.archive?.active.object,let owner=store.archive.flatMap({NOVASession($0.active)}),NOVASwiftLocationConsent.background(root),root["locSessionToken"]?.string==owner.token,!(root["locSession"]?.string ?? "").isEmpty,manager.authorizationStatus == .authorizedAlways else{stop(clear:false);return}
        consentSession=owner;manager.allowsBackgroundLocationUpdates=true;manager.pausesLocationUpdatesAutomatically=true;manager.startMonitoringSignificantLocationChanges()
    }
    func stop(clear:Bool){requesting=false;jobs.forEach{$0.cancel()};jobs=[];manager.stopMonitoringSignificantLocationChanges();manager.allowsBackgroundLocationUpdates=false
        let defaults=UserDefaults.standard;defaults.set(false,forKey:"nova.bgLoc.on");for key in ["nova.bgLoc.session","nova.bgLoc.token","nova.bgLoc.sharing"]{defaults.removeObject(forKey:key)}
        if clear,let store=store{try? store.update(owner:store.archive?.owner ?? ""){$0["bgLoc"] = .number(0);$0["bgConsentV2"] = .string("")};status="Aggiornamenti a app chiusa disattivati."}
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){if requesting,manager.authorizationStatus == .authorizedAlways{activate()}else if [.denied,.restricted].contains(manager.authorizationStatus){stop(clear:true);status="Posizione non autorizzata."}else if !requesting{reconcile()}}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){
        guard let store=store,let state=store.archive?.active,let root=state.object,let owner=NOVASession(state),owner==consentSession,NOVASwiftLocationConsent.background(root),root["locSessionToken"]?.string==owner.token,let session=root["locSession"]?.string,!session.isEmpty,manager.authorizationStatus == .authorizedAlways,let fix=locations.last,fix.horizontalAccuracy>=0,abs(fix.timestamp.timeIntervalSinceNow)<60 else{return}
        var request=URLRequest(url:URL(string:"https://api.federicotaranu.site/location")!);request.httpMethod="PUT";request.timeoutInterval=25;request.setValue("Bearer "+owner.token,forHTTPHeaderField:"Authorization");request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try? JSONEncoder().encode(NOVAJSON.object(["lat":.number(fix.coordinate.latitude),"lon":.number(fix.coordinate.longitude),"sharing":.bool(true),"session":.string(session)]));jobs.removeAll{$0.state == .completed || $0.state == .canceling};let task=URLSession.shared.dataTask(with:request);jobs.append(task);task.resume()
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){if (error as? CLError)?.code != .locationUnknown{status="Aggiornamento posizione non riuscito. iOS può sospendere gli aggiornamenti in background."}}
}

// Live mode has new explicit consent. Cached one-shot/background flags never enable it.
enum NOVASwiftLivePolicy {
    // Consent never follows cached legacy flags. Server budget remains separately fail-closed.
    static let released=true
    static func consent(_ root:[String:NOVAJSON],background:Bool=false)->Bool {
        guard released,NOVASwiftLocationConsent.sharing(root),let session=root["locSession"]?.string,!session.isEmpty,root["liveConsentV2"]?.string==session else{return false}
        return !background || root["liveBackgroundConsentV1"]?.string==session
    }
    static func sameStart(root:[String:NOVAJSON],current:NOVASession?,started:NOVASession?,sharing:String)->Bool{guard let current=current,let started=started else{return false};return current==started && root["locSessionToken"]?.string==current.token && root["locSession"]?.string==sharing && consent(root)}
    static func runtimeAllowed(root:[String:NOVAJSON],current:NOVASession,started:NOVASession?,sharing:String,locallyStarted:Bool,now:Date,deadline:Date?)->Bool{locallyStarted && sameStart(root:root,current:current,started:started,sharing:sharing)}
    static func upload(now:Date,fix:CLLocation,previous:CLLocation?,sentAt:Date?)->Bool {
        guard fix.horizontalAccuracy>=0,fix.horizontalAccuracy<=200,now.timeIntervalSince(fix.timestamp)>=(-5),now.timeIntervalSince(fix.timestamp)<30 else{return false}
        if let sentAt=sentAt,now.timeIntervalSince(sentAt)<15{return false}
        guard let previous=previous,let sentAt=sentAt else{return true}
        let elapsed=now.timeIntervalSince(sentAt)
        return elapsed>=15 && (fix.distance(from:previous)>=15 || elapsed>=120)
    }
}
@MainActor final class NOVASwiftLiveLocation:NSObject,ObservableObject,@preconcurrency CLLocationManagerDelegate {
    static let shared=NOVASwiftLiveLocation()
    @Published private(set) var status=""
    @Published private(set) var lastSent:Date?
    @Published private(set) var running=false
    private weak var store:NOVASwiftStore?
    private var observation:AnyCancellable?
    private var stream:Task<Void,Never>?
    private var upload:Task<Void,Never>?
    private var resume:Task<Void,Never>?
    private var backgroundSession:CLBackgroundActivitySession?
    
    
    
    private var locallyStarted=false
    private var startedOwner:NOVASession?
    private var startedSharing=""
    private let permission=CLLocationManager()
    private let deviceServices:Bool
    private let request:(NOVASession,NOVAJSON)async throws->NOVAJSON
    private var owner:NOVASession?
    private var liveSession=""
    private var runningBackground=false
    private var generation=0
    private var previous:CLLocation?
    private var sentAt:Date?
    private var retryAfter=Date.distantPast
    private var failureCount=0
    private var suspendedSharing=""
    private var active=UIApplication.shared.applicationState == .active
    private var notificationTokens:[NSObjectProtocol]=[]
    init(deviceServices:Bool=true,request:((NOVASession,NOVAJSON)async throws->NOVAJSON)?=nil){self.deviceServices=deviceServices;self.request=request ?? {session,body in try await NOVAAccountService(session:session).request("location",method:"PUT",body:body)};super.init();permission.delegate=self;for name in [UIApplication.didBecomeActiveNotification,UIApplication.willResignActiveNotification]{notificationTokens.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main){[weak self] _ in Task{@MainActor in self?.active = name == UIApplication.didBecomeActiveNotification;self?.reconcile()}})}}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){reconcile()}
    func bind(_ store:NOVASwiftStore){if self.store===store,observation != nil{reconcile();return};stop();self.store=store;restoreEnabledPreference();observation=store.$archive.sink{[weak self] _ in Task{@MainActor in self?.reconcile()}};reconcile()}
    private func restoreEnabledPreference(){guard let archive=store?.archive,let root=archive.active.object,let current=NOVASession(archive.active),NOVASwiftLivePolicy.consent(root),root["locSessionToken"]?.string==current.token else{return};locallyStarted=true;startedOwner=current;startedSharing=root["locSession"]?.string ?? ""}
    func unbind(){locallyStarted=false;stop();observation=nil;store=nil}
    func choose(_ enabled:Bool,background:Bool=false,_ store:NOVASwiftStore){
        bind(store)
        suspendedSharing=""
        guard let archive=store.archive,let root=archive.active.object,NOVASwiftLocationConsent.sharing(root),let session=root["locSession"]?.string else{status="Attiva prima la condivisione.";return}
        if !background{locallyStarted=enabled}
        if enabled && !background{startedOwner=NOVASession(archive.active);startedSharing=session}
        if background && enabled{guard locallyStarted,NOVASwiftLivePolicy.sameStart(root:root,current:NOVASession(archive.active),started:startedOwner,sharing:startedSharing) else{status="Scegli prima Avvia live.";return}}
        do{try store.update(owner:archive.owner){state in
            if background{state["liveBackgroundConsentV1"] = .string(enabled ? session:"")}
            else{state["liveConsentV2"] = .string(enabled ? session:"");if !enabled{state["liveBackgroundConsentV1"] = .string("")}}
        };if enabled && deviceServices{NOVASwiftBackgroundLocation.shared.stop(clear:true);if permission.authorizationStatus == .notDetermined{permission.requestWhenInUseAuthorization()}};reconcile()}catch{status="Scelta live non salvata. Riprova."}
    }
    func stopNow(){locallyStarted=false;startedOwner=nil;startedSharing="";suspendedSharing=liveSession;stop();if let store=store,let archive=store.archive{try? store.update(owner:archive.owner){$0["liveConsentV2"] = .string("");$0["liveBackgroundConsentV1"] = .string("")}};status="Live fermato. Nessun nuovo invio live."}
    private func stop(){resume?.cancel();resume=nil;running=false;generation+=1;stream?.cancel();stream=nil;upload?.cancel();upload=nil;backgroundSession?.invalidate();backgroundSession=nil;owner=nil;liveSession="";runningBackground=false;previous=nil;sentAt=nil;lastSent=nil;retryAfter = .distantPast;failureCount=0}
    private func reconcile(){
        // Crossing an account/token/sharing boundary revokes the local start permanently.
        // Switching back must never resume a previous session without another Start.
        if locallyStarted,startedOwner != nil{let root=store?.archive?.active.object ?? [:];let current=store?.archive.flatMap{NOVASession($0.active)};if !NOVASwiftLivePolicy.sameStart(root:root,current:current,started:startedOwner,sharing:startedSharing){locallyStarted=false;startedOwner=nil;startedSharing="";stop();status="Live fermato: account o condivisione cambiati. Scegli Avvia live per ripartire.";return}}
        guard locallyStarted,let store=store,let root=store.archive?.active.object,let session=store.archive.flatMap({NOVASession($0.active)}),NOVASwiftLivePolicy.runtimeAllowed(root:root,current:session,started:startedOwner,sharing:startedSharing,locallyStarted:locallyStarted,now:Date(),deadline:nil) else{stop();return}
        guard suspendedSharing != root["locSession"]?.string else{return}
        let bg=NOVASwiftLivePolicy.consent(root,background:true)
        guard active || bg else{stop();status="Live in pausa: app non attiva.";return}
        if (stream != nil || (!deviceServices && running)),owner==session,liveSession==root["locSession"]?.string,runningBackground==bg{return}
        // A saved V2 choice can rejoin its outstanding background activity after system relaunch.
        // The first choice is only written by the foreground confirmation button.
        guard !deviceServices || permission.authorizationStatus != .notDetermined else{stop();status="Live abilitato, apri le opzioni e conferma il permesso posizione.";return}
        guard !deviceServices || ![.denied,.restricted].contains(permission.authorizationStatus) else{stop();status="Live abilitato ma posizione non autorizzata. Controlla le impostazioni iOS.";return}
        stop();owner=session;liveSession=root["locSession"]?.string ?? "";runningBackground=bg
        if bg && deviceServices{backgroundSession=CLBackgroundActivitySession()}
        running=true
        status="Live attivo fino a Ferma live. In attesa di una posizione recente."
        guard deviceServices else{return}
        stream=Task{[weak self] in
            do{for try await update in CLLocationUpdate.liveUpdates(){
                guard !Task.isCancelled,let self=self else{break}
                guard self.owner==session,let current=self.store?.archive?.active.object,NOVASwiftLivePolicy.consent(current),self.store?.archive.flatMap({NOVASession($0.active)})==session else{self.stop();break}
                if update.isStationary{self.status="Live: dispositivo fermo, aggiornamenti ridotti."}
                if let fix=update.location{self.receive(fix,session)}
            }}catch{guard !Task.isCancelled else{return};self?.pauseAndResume(after:60,status:"Live abilitato, in pausa: iOS o posizione non disponibile.")}
        }
    }
    #if DEBUG
    func testFix(_ fix:CLLocation){if let owner=owner{receive(fix,owner)}}
    func testActive(_ on:Bool){active=on;reconcile()}
    var testHasUpload:Bool{upload != nil}
    #endif
    private func pauseAndResume(after seconds:Double,status message:String){stop();status=message;suspendedSharing=startedSharing;resume=Task{[weak self] in do{try await Task.sleep(for:.seconds(seconds))}catch{return};guard !Task.isCancelled,let self=self else{return};self.suspendedSharing="";self.reconcile()}}
    private func receive(_ fix:CLLocation,_ session:NOVASession){
        guard Date()>=retryAfter,upload==nil,NOVASwiftLivePolicy.upload(now:Date(),fix:fix,previous:previous,sentAt:sentAt),let store=store,let root=store.archive?.active.object,NOVASwiftLivePolicy.consent(root),root["locSessionToken"]?.string==session.token,let sharing=root["locSession"]?.string,sharing==liveSession else{return}
        let epoch=generation
        upload=Task{[weak self] in
            guard let self=self else{return};defer{if self.generation==epoch{self.upload=nil}}
            do{let result=try await self.request(session,.object(["lat":.number(fix.coordinate.latitude),"lon":.number(fix.coordinate.longitude),"sharing":.bool(true),"session":.string(sharing),"fix_ts":.number(fix.timestamp.timeIntervalSince1970*1000)]))
                guard !Task.isCancelled,self.generation==epoch,self.owner==session,self.liveSession==sharing,self.store?.archive.flatMap({NOVASession($0.active)})==session else{return}
                guard result.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse}
                self.failureCount=0;self.retryAfter = .distantPast;self.previous=fix;self.sentAt=Date();self.lastSent=fix.timestamp;self.status="Live: ultima posizione inviata "+fix.timestamp.formatted(date:.omitted,time:.standard)
            }catch{guard !Task.isCancelled,self.generation==epoch,self.owner==session else{return}
                if case NOVAServiceError.http(let code,_)=error{
                    if [401,403,409].contains(code){self.stopNow();self.status="Live fermato: account o condivisione da riconfermare.";return}
                    if [429,503].contains(code){let calendar=Calendar(identifier:.gregorian);var utc=calendar;utc.timeZone=TimeZone(secondsFromGMT:0)!;let nextDay=utc.date(byAdding:.day,value:1,to:utc.startOfDay(for:Date()))!;self.pauseAndResume(after:max(60,nextDay.timeIntervalSinceNow+5),status:"Live abilitato, invii in pausa fino al prossimo giorno UTC per proteggere il limite gratuito.");return}
                }
                self.failureCount=min(self.failureCount+1,5);self.retryAfter=Date().addingTimeInterval(min(900,30*pow(2,Double(self.failureCount-1))));self.status="Live non aggiornato: nuovo tentativo ridotto per rete o servizio non disponibile. Nessuna posizione simulata.";self.sentAt=Date()
            }
        }
    }
}

@MainActor enum NOVASwiftPersistentServices {
    static let store=NOVASwiftStore()
    static func restore(){NOVASwiftLiveLocation.shared.bind(store)}
}
@MainActor final class NOVASwiftLocationAppDelegate:NSObject,UIApplicationDelegate {
    func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey:Any]?=nil)->Bool{NOVASwiftPersistentServices.restore();return true}
}
