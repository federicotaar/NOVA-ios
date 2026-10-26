import SwiftUI
import MapKit
import CoreLocation

// Independent Swift map. No location permission or sharing is enabled on appearance.
@MainActor final class NOVASwiftPosition: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var status = ""
    @Published private(set) var fixVersion=0
    private let manager = CLLocationManager()
    private var waiting = false
    private var generation = 0
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func read() {
        generation += 1; waiting = true; coordinate=nil; status = "Lettura posizione…"
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: start()
        default: waiting = false; status = "Posizione non autorizzata. Puoi cambiarla nelle impostazioni di iOS."
        }
    }
    private func start() {
        manager.startUpdatingLocation(); let expected = generation
        Task { try? await Task.sleep(for:.seconds(25)); guard waiting, expected == generation else{return}; stop(); status = "Posizione non disponibile. Riprova." }
    }
    func stop() { generation += 1; waiting = false; manager.stopUpdatingLocation() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waiting else{return}
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse: start()
        case .denied,.restricted: stop(); status = "Posizione non autorizzata."
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard waiting, let fix=locations.last, fix.horizontalAccuracy >= 0, abs(fix.timestamp.timeIntervalSinceNow) < 900 else{return}
        coordinate=fix.coordinate;fixVersion += 1;status="Ultima lettura: "+fix.timestamp.formatted(date:.abbreviated,time:.standard);stop()
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) {
        if (error as? CLError)?.code == .locationUnknown{return};stop();status="Lettura posizione non riuscita. Riprova."
    }
}
struct NOVASwiftMapFriend:Identifiable {
    let id:String
    let coordinate:CLLocationCoordinate2D
    let timestamp:Date
    static func parse(_ value:NOVAJSON,now:Date=Date())->NOVASwiftMapFriend? {
        guard let o=value.object,let username=o["username"]?.string,
              case .number(let lat)?=o["lat"],case .number(let lon)?=o["lon"],case .number(let milliseconds)?=o["ts"],
              lat.isFinite,lon.isFinite,abs(lat)<=90,abs(lon)<=180 else{return nil}
        let time=Date(timeIntervalSince1970:milliseconds/1000)
        guard now.timeIntervalSince(time)>=(-60),now.timeIntervalSince(time)<1800 else{return nil}
        return Self(id:username,coordinate:CLLocationCoordinate2D(latitude:lat,longitude:lon),timestamp:time)
    }
}
@MainActor final class NOVASwiftMapModel:ObservableObject {
    @Published private(set) var friends:[NOVASwiftMapFriend]=[]
    @Published private(set) var status=""
    @Published private(set) var changing=false
    private var generation=0
    func cancel() { generation += 1;changing=false;friends=[] }
    func refresh(_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{friends=[];status="Collega il tuo account NOVA per vedere gli amici sulla mappa.";return}
        let expected=generation
        do {
            let result=try await NOVAAccountService(session:owner).request("map")
            guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            friends=(result.object?["friends"]?.array ?? []).compactMap{NOVASwiftMapFriend.parse($0)}
            status=friends.isEmpty ? "Nessun amico ha una posizione recente condivisa.":"Posizioni recenti, non tracciamento continuo."
        }catch{guard generation==expected else{return};friends=[];status="Mappa amici non aggiornata. Riprova."}
    }
    func sharing(_ enabled:Bool,_ store:NOVASwiftStore) async {
        guard let archive=store.archive,let owner=NOVASession(archive.active) else{status="Collega prima il tuo account NOVA.";return}
        generation += 1;let expected=generation;changing=enabled
        if !enabled {
            // Stop local visibility immediately. No further location upload is allowed.
            do{try store.update(owner:archive.owner){$0["locShare"] = .number(0);$0["locSession"] = .string("");$0["bgLoc"] = .number(0)}}catch{status="Impossibile salvare Fantasma. Nessuna nuova posizione inviata.";changing=false;return}
            // Stop legacy significant-change monitoring before any network wait.
            let defaults=UserDefaults.standard
            defaults.set(false,forKey:"nova.bgLoc.on");defaults.removeObject(forKey:"nova.bgLoc.session");defaults.removeObject(forKey:"nova.bgLoc.token");defaults.set(false,forKey:"nova.bgLoc.sharing")
            let background=CLLocationManager();background.stopMonitoringSignificantLocationChanges()
            status="Spegnimento della condivisione in corso…"
        }
        do {
            let service=NOVAAccountService(session:owner)
            if enabled {
                let revision=try await service.request("location/session")
                guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
                let result=try await service.request("location/session",method:"POST",body:.object(["rev":revision.object?["rev"] ?? .null]))
                guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner,let session=result.object?["session"]?.string,!session.isEmpty else{return}
                try store.update(owner:archive.owner){$0["locSession"] = .string(session);$0["locSessionToken"] = .string(owner.token);$0["locShare"] = .number(1)}
                status="Condivisione attiva. Leggi la posizione per inviare un aggiornamento."
            }else{
                _ = try await service.request("location",method:"PUT",body:.object(["sharing":.bool(false)]))
                guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
                status="Condivisione spenta sul server."
            }
        }catch{guard generation==expected else{return};status=enabled ? "Condivisione non attivata. Riprova.":"Offline: spegnimento sul server non confermato. Riprova appena sei online."}
        if generation==expected{changing=false}
    }
    func upload(_ coordinate:CLLocationCoordinate2D,_ store:NOVASwiftStore) async {
        guard let archive=store.archive,let owner=NOVASession(archive.active),let root=archive.active.object,
              root["locShare"]?.flag==true,root["locSessionToken"]?.string==owner.token,let session=root["locSession"]?.string,!session.isEmpty else{return}
        let expected=generation
        do {
            _ = try await NOVAAccountService(session:owner).request("location",method:"PUT",body:.object(["lat":.number(coordinate.latitude),"lon":.number(coordinate.longitude),"sharing":.bool(true),"session":.string(session)]))
            guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            status="Posizione aggiornata. Gli amici vedono l'ultima lettura recente."
        }catch{if generation==expected{status="Posizione non inviata. Riprova."}}
    }
}
@MainActor struct NOVASwiftMap:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var model=NOVASwiftMapModel()
    @StateObject private var position=NOVASwiftPosition()
    @State private var camera:MapCameraPosition = .region(MKCoordinateRegion(center:CLLocationCoordinate2D(latitude:20,longitude:0),span:MKCoordinateSpan(latitudeDelta:140,longitudeDelta:300)))
    var sharing:Bool {store.archive?.active.object?["locShare"]?.flag==true}
    var body:some View {
        NavigationStack {
            VStack(spacing:12) {
                Map(position:$camera){
                    if let coordinate=position.coordinate{Annotation("Tu",coordinate:coordinate){Image(systemName:"person.circle.fill").font(.largeTitle).foregroundStyle(.blue).background(.background,in:Circle())}}
                    ForEach(model.friends){friend in Annotation("@"+friend.id,coordinate:friend.coordinate){VStack(spacing:3){Image(systemName:"person.circle.fill").font(.title);Text("@"+friend.id).font(.caption.bold());Text(friend.timestamp,style:.relative).font(.caption2)}.padding(6).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12))}}
                }.mapControls{MapCompass();MapScaleView()}.frame(minHeight:240)
                VStack(alignment:.leading,spacing:12){
                    Text(sharing ? "Posizione condivisa con gli amici. Aggiornamenti quando leggi la posizione.":"Fantasma: nessuna nuova posizione viene condivisa.").font(.footnote)
                    if !model.status.isEmpty{Text(model.status).font(.footnote).foregroundStyle(.secondary)}
                    if !position.status.isEmpty{Text(position.status).font(.footnote).foregroundStyle(.secondary)}
                    HStack {
                        Button{Task{await model.sharing(!sharing,store)}}label:{Label(sharing ? "Attiva Fantasma":"Condividi",systemImage:"eye.slash")}
                        Spacer()
                        Button{position.read()}label:{Image(systemName:"location.fill")}.accessibilityLabel("Leggi la mia posizione")
                        Button{Task{await model.refresh(store)}}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("Aggiorna amici")
                    }.buttonStyle(.bordered)
                    Text("Le posizioni degli amici oltre 30 minuti non sono mostrate. Lo spegnimento offline richiede conferma del server. Aggiornamenti in background ancora in verifica.").font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal).padding(.bottom)
            }.navigationTitle("Mappa").task{await model.refresh(store)}
            .onChange(of:position.fixVersion){_,_ in guard let coordinate=position.coordinate else{return};camera = .region(MKCoordinateRegion(center:coordinate,span:MKCoordinateSpan(latitudeDelta:0.04,longitudeDelta:0.04)));Task{await model.upload(coordinate,store)}}
            .onDisappear{position.stop();model.cancel()}
        }
    }
}
