import SwiftUI
import CoreLocation
import Combine

// Bound to the Swift archive. No permission request occurs from bind or appearance.
@MainActor final class NOVASwiftBackgroundLocation:NSObject,ObservableObject,CLLocationManagerDelegate {
    static let shared=NOVASwiftBackgroundLocation()
    @Published private(set) var status=""
    private let manager=CLLocationManager()
    private weak var store:NOVASwiftStore?
    private var observation:AnyCancellable?
    private var jobs:[URLSessionDataTask]=[]
    private var consentSession:NOVASession?
    private var requesting=false
    private override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters}
    func bind(_ store:NOVASwiftStore){self.store=store;observation=store.$archive.sink{[weak self] _ in Task{@MainActor in self?.reconcile()}};reconcile()}
    func unbind(){stop(clear:false);observation=nil;store=nil}
    func enabled(_ on:Bool,_ store:NOVASwiftStore){
        bind(store)
        guard on else{stop(clear:true);return}
        guard let state=store.archive?.active,let session=NOVASession(state),state.object?["locShare"]?.flag==true,state.object?["locSessionToken"]?.string==session.token,!(state.object?["locSession"]?.string ?? "").isEmpty else{status="Attiva prima la condivisione sulla mappa.";return}
        consentSession=session;requesting=true
        switch manager.authorizationStatus {
        case .authorizedAlways:activate()
        case .notDetermined:manager.requestWhenInUseAuthorization();status="Consenti la posizione, poi scegli Sempre nelle impostazioni di iOS."
        case .authorizedWhenInUse:manager.requestAlwaysAuthorization();status="Per gli aggiornamenti a app chiusa scegli Sempre nelle impostazioni di iOS."
        default:requesting=false;status="Posizione non autorizzata. Apri le impostazioni di iOS."
        }
    }
    private func activate(){guard let store=store,let state=store.archive?.active,let owner=NOVASession(state),consentSession==owner,state.object?["locShare"]?.flag==true,manager.authorizationStatus == .authorizedAlways else{stop(clear:false);return};do{try store.update(owner:store.archive!.owner){$0["bgLoc"] = .number(1)};requesting=false;reconcile();status="Aggiornamenti ai grandi spostamenti attivi. Non sono un tracciamento continuo."}catch{stop(clear:false);status="Scelta non salvata. Riprova."}}
    private func reconcile(){
        guard let store=store,let root=store.archive?.active.object,let owner=store.archive.flatMap({NOVASession($0.active)}),root["bgLoc"]?.flag==true,root["locShare"]?.flag==true,root["locSessionToken"]?.string==owner.token,!(root["locSession"]?.string ?? "").isEmpty,manager.authorizationStatus == .authorizedAlways else{stop(clear:false);return}
        consentSession=owner;manager.allowsBackgroundLocationUpdates=true;manager.pausesLocationUpdatesAutomatically=true;manager.startMonitoringSignificantLocationChanges()
    }
    func stop(clear:Bool){requesting=false;jobs.forEach{$0.cancel()};jobs=[];manager.stopMonitoringSignificantLocationChanges();manager.allowsBackgroundLocationUpdates=false
        let defaults=UserDefaults.standard;defaults.set(false,forKey:"nova.bgLoc.on");for key in ["nova.bgLoc.session","nova.bgLoc.token","nova.bgLoc.sharing"]{defaults.removeObject(forKey:key)}
        if clear,let store=store{try? store.update(owner:store.archive?.owner ?? ""){$0["bgLoc"] = .number(0)};status="Aggiornamenti a app chiusa disattivati."}
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){if requesting,manager.authorizationStatus == .authorizedAlways{activate()}else if [.denied,.restricted].contains(manager.authorizationStatus){stop(clear:true);status="Posizione non autorizzata."}else{reconcile()}}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){
        guard let store=store,let state=store.archive?.active,let root=state.object,let owner=NOVASession(state),owner==consentSession,root["bgLoc"]?.flag==true,root["locShare"]?.flag==true,root["locSessionToken"]?.string==owner.token,let session=root["locSession"]?.string,!session.isEmpty,manager.authorizationStatus == .authorizedAlways,let fix=locations.last,fix.horizontalAccuracy>=0,abs(fix.timestamp.timeIntervalSinceNow)<60 else{return}
        var request=URLRequest(url:URL(string:"https://api.federicotaranu.site/location")!);request.httpMethod="PUT";request.timeoutInterval=25;request.setValue("Bearer "+owner.token,forHTTPHeaderField:"Authorization");request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try? JSONEncoder().encode(NOVAJSON.object(["lat":.number(fix.coordinate.latitude),"lon":.number(fix.coordinate.longitude),"sharing":.bool(true),"session":.string(session)]));jobs.removeAll{$0.state == .completed || $0.state == .canceling};let task=URLSession.shared.dataTask(with:request);jobs.append(task);task.resume()
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){if (error as? CLError)?.code != .locationUnknown{status="Aggiornamento posizione non riuscito. iOS può sospendere gli aggiornamenti in background."}}
}
