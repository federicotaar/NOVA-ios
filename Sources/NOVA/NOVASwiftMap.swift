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
    typealias Request=(NOVASession,String,String,NOVAJSON?) async throws -> NOVAJSON
    private let request:Request
    init(request:Request?=nil){self.request=request ?? {session,path,method,body in try await NOVAAccountService(session:session).request(path,method:method,body:body)}}
    func cancel() { generation += 1;changing=false;friends=[] }
    func refresh(_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{friends=[];status="Collega il tuo account NOVA per vedere gli amici sulla mappa.";return}
        let expected=generation
        do {
            let result=try await request(owner,"map","GET",nil)
            guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            friends=(result.object?["friends"]?.array ?? []).compactMap{NOVASwiftMapFriend.parse($0)}
            status=friends.isEmpty ? "Nessun amico ha una posizione recente condivisa.":"Posizioni recenti, non tracciamento continuo."
        }catch{guard generation==expected else{return};friends=[];status="Mappa amici non aggiornata. Riprova."}
    }
    func sharing(_ enabled:Bool,_ store:NOVASwiftStore) async {
        guard let archive=store.archive,let owner=NOVASession(archive.active) else{status="Collega prima il tuo account NOVA.";return}
        generation += 1;let expected=generation;changing=enabled
        if !enabled {
            NOVASwiftBackgroundLocation.shared.stop(clear:true)
            // Stop local visibility immediately. No further location upload is allowed.
            do{try store.update(owner:archive.owner){$0["locShare"] = .number(0);$0["locSession"] = .string("");$0["locConsentV2"] = .string("");$0["bgConsentV2"] = .string("");$0["bgLoc"] = .number(0)}}catch{status="Impossibile salvare Fantasma. Nessuna nuova posizione inviata.";changing=false;return}
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
                try store.update(owner:archive.owner){$0["locSession"] = .string(session);$0["locSessionToken"] = .string(owner.token);$0["locConsentV2"] = .string(session);$0["locShare"] = .number(1)}
                status="Condivisione attiva. Leggi la posizione per inviare un aggiornamento."
            }else{
                let response=try await service.request("location",method:"PUT",body:.object(["sharing":.bool(false)]));guard response.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse}
                guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
                status="Condivisione spenta sul server."
            }
        }catch{guard generation==expected else{return};status=enabled ? "Condivisione non attivata. Riprova.":"Offline: spegnimento sul server non confermato. Riprova appena sei online."}
        if generation==expected{changing=false}
    }
    func upload(_ coordinate:CLLocationCoordinate2D,_ store:NOVASwiftStore) async {
        guard let archive=store.archive,let owner=NOVASession(archive.active),let root=archive.active.object,
              NOVASwiftLocationConsent.sharing(root),root["locSessionToken"]?.string==owner.token,let session=root["locSession"]?.string,!session.isEmpty else{return}
        let expected=generation
        do {
            let response=try await NOVAAccountService(session:owner).request("location",method:"PUT",body:.object(["lat":.number(coordinate.latitude),"lon":.number(coordinate.longitude),"sharing":.bool(true),"session":.string(session)]));guard response.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse}
            guard generation==expected,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            status="Posizione aggiornata. Gli amici vedono l'ultima lettura recente."
        }catch{if generation==expected{status="Posizione non inviata. Riprova."}}
    }
}

enum NOVASwiftLocationConsent {
    static func sharing(_ root:[String:NOVAJSON])->Bool {root["locShare"]?.flag==true && !(root["locSession"]?.string ?? "").isEmpty && root["locConsentV2"]?.string==root["locSession"]?.string}
    static func background(_ root:[String:NOVAJSON])->Bool {sharing(root) && root["bgLoc"]?.flag==true && root["bgConsentV2"]?.string==root["locSession"]?.string}
}
@MainActor struct NOVASwiftMap:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var model:NOVASwiftMapModel
    init(store:NOVASwiftStore,model:NOVASwiftMapModel?=nil){self.store=store;_model=StateObject(wrappedValue:model ?? NOVASwiftMapModel())}
    @StateObject private var position=NOVASwiftPosition()
    @ObservedObject private var background=NOVASwiftBackgroundLocation.shared
    @State private var camera:MapCameraPosition = .automatic
    @State private var expanded=false
    @State private var confirmShare=false
    @State private var confirmBackground=false
    var root:[String:NOVAJSON]{store.archive?.active.object ?? [:]}
    var sharing:Bool {NOVASwiftLocationConsent.sharing(root)}
    var unconfirmed:Bool {root["locShare"]?.flag==true && !sharing}
    var body:some View {
        GeometryReader{geometry in
            ZStack(alignment:.bottom){
                Map(position:$camera){
                    if let coordinate=position.coordinate{Annotation("Tu",coordinate:coordinate){Image(systemName:"person.circle.fill").font(.largeTitle).foregroundStyle(.blue).background(.background,in:Circle())}}
                    ForEach(model.friends){friend in Annotation("@"+friend.id,coordinate:friend.coordinate){VStack(spacing:3){Image(systemName:"person.circle.fill").font(.title);Text("@"+friend.id).font(.caption.bold());Text(friend.timestamp,style:.relative).font(.caption2)}.padding(6).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12))}}
                }.mapStyle(.standard).mapControls{MapCompass();MapScaleView()}.ignoresSafeArea()
                VStack{
                    HStack{Spacer();VStack(spacing:18){
                        Button{withAnimation(.snappy){expanded.toggle()}}label:{Image(systemName:"slider.horizontal.3")}.accessibilityLabel("Opzioni mappa")
                        Button{position.read()}label:{Image(systemName:"location.fill")}.accessibilityLabel("Leggi la mia posizione")
                        Button{Task{await model.refresh(store)}}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("Aggiorna amici")
                    }.font(.title3).padding(15).background(.regularMaterial,in:Capsule()).padding(.trailing,18)}.padding(.top,14)
                    Spacer()
                }
                VStack(spacing:10){
                    Button{withAnimation(.snappy){expanded.toggle()}}label:{VStack(spacing:8){Capsule().fill(.secondary).frame(width:36,height:5);HStack{Image(systemName:sharing ? "person.2.fill":"eye.slash.fill");Text("Persone").font(.headline);Spacer();Text(sharing ? "Condivisione attiva":"Fantasma").font(.caption);Image(systemName:expanded ? "chevron.down":"chevron.up").font(.caption.bold())}}}.buttonStyle(.plain).accessibilityIdentifier("swiftMapExpand")
                    if unconfirmed{Text("Condivisione precedente non confermata. Nuovi invii sospesi su questo telefono; usa Fantasma per confermare lo spegnimento sul server.").font(.caption).foregroundStyle(.orange)}
                    if !position.status.isEmpty{Text(position.status).font(.caption).foregroundStyle(.secondary)}
                    if expanded{
                        ScrollView{VStack(alignment:.leading,spacing:14){
                            Text(sharing ? "Condivisione attiva: gli amici vedono l'ultima lettura recente.":"Nessuna nuova posizione viene inviata da questo telefono.").font(.footnote)
                            if !model.status.isEmpty{Text(model.status).font(.footnote).foregroundStyle(.secondary)}
                            ForEach(model.friends){friend in HStack{Label("@"+friend.id,systemImage:"person.circle.fill");Spacer();Text(friend.timestamp,style:.relative).font(.caption)}.onTapGesture{camera = .region(MKCoordinateRegion(center:friend.coordinate,span:MKCoordinateSpan(latitudeDelta:0.04,longitudeDelta:0.04)))}}
                            Button{if sharing || unconfirmed{Task{await model.sharing(false,store)}}else{confirmShare=true}}label:{Label(sharing || unconfirmed ? "Attiva Fantasma":"Condividi posizione",systemImage:"eye.slash")}.buttonStyle(.bordered)
                            Toggle("Anche a app chiusa",isOn:Binding(get:{NOVASwiftLocationConsent.background(root)},set:{on in if on{confirmBackground=true}else{background.enabled(false,store)}})).disabled(!sharing)
                            if !background.status.isEmpty{Text(background.status).font(.caption).foregroundStyle(.secondary)}
                            Text("Le posizioni degli amici oltre 30 minuti non sono mostrate. Lo spegnimento offline richiede conferma del server. A app chiusa gli aggiornamenti avvengono ai grandi spostamenti: iOS può ritardarli o sospenderli.").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth:.infinity,alignment:.leading)}.frame(maxHeight:min(260,geometry.size.height*0.35))
                    }
                }.padding(16).background(.regularMaterial,in:RoundedRectangle(cornerRadius:28)).padding(.horizontal,16).padding(.bottom,86).accessibilityIdentifier("swiftMapPanel")
            }
        }.task{await model.refresh(store)}
        .confirmationDialog("Condividere la tua posizione con gli amici NOVA?",isPresented:$confirmShare,titleVisibility:.visible){Button("Condividi"){Task{await model.sharing(true,store)}};Button("Annulla",role:.cancel){}}message:{Text("Verrà inviata solo quando richiedi una lettura. Gli aggiornamenti a app chiusa richiedono una scelta separata.")}
        .confirmationDialog("Aggiornare anche a app chiusa?",isPresented:$confirmBackground,titleVisibility:.visible){Button("Attiva aggiornamenti"){background.enabled(true,store)};Button("Annulla",role:.cancel){}}message:{Text("iOS usa i grandi spostamenti con il permesso Sempre. Puoi disattivare questa scelta o attivare Fantasma in qualsiasi momento.")}
        .onChange(of:position.fixVersion){_,_ in guard let coordinate=position.coordinate else{return};camera = .region(MKCoordinateRegion(center:coordinate,span:MKCoordinateSpan(latitudeDelta:0.04,longitudeDelta:0.04)));Task{await model.upload(coordinate,store)}}
        .onChange(of:store.archive?.owner){_,_ in position.stop();model.cancel()}
        .onDisappear{position.stop();model.cancel()}
    }
}
