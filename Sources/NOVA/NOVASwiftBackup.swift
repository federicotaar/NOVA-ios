import SwiftUI
import CoreLocation

// Same private-field allowlist as the existing account backup. Device secrets stay local.
enum NOVASwiftBackupData {
    static let fields=["name","theme","sb","hwn","w","tt","tasks","chat","gr","agentMd","aiAct","city","introEvery","introOff","done","ob","ttSeeded","profDone"]
    static let profileFields=["username","avatar","study","skills","hobbies","song","badges"]
    static func snapshot(_ active:NOVAJSON)->NOVAJSON {
        let state=active.object ?? [:];var result:[String:NOVAJSON]=[:]
        for key in fields{if let value=state[key]{result[key]=value}}
        let profile=state["prof"]?.object ?? [:];var privateProfile:[String:NOVAJSON]=[:]
        for key in profileFields{if let value=profile[key]{privateProfile[key]=value}}
        result["prof"] = .object(privateProfile);return .object(result)
    }
    static func apply(_ data:NOVAJSON,to root:inout [String:NOVAJSON]) {
        guard let remote=data.object else{return}
        for key in fields{if let value=remote[key]{root[key]=value}}
        var profile=root["prof"]?.object ?? [:]
        for key in profileFields{if let value=remote["prof"]?.object?[key]{profile[key]=value}}
        root["prof"] = .object(profile)
        if !["always","ask","deny"].contains(root["aiAct"]?.string ?? ""){root["aiAct"] = .string("ask")}
        root["chat"] = .array((root["chat"]?.array ?? []).map{message in
            guard var m=message.object else{return message}
            if let actions=m["acts"]{m["acts"] = .array(actions.array.map{action in guard var a=action.object else{return action};if ["wait","go","pending"].contains(a["st"]?.string ?? ""){a["st"] = .string("no");a["note"] = .string("Non rieseguita dopo il ripristino")};return .object(a)})}
            return .object(m)
        })
        // Importing a cloud snapshot never enables location or services.
        root["locShare"] = .number(0);root["bgLoc"] = .number(0);root["locSession"] = .string("");root["locSessionToken"] = .string("")
    }
    static func recovery(_ active:NOVAJSON) throws {
        let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("NOVASwift/recovery",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let url=directory.appendingPathComponent(UUID().uuidString+".json")
        let data=try JSONEncoder().encode(active);try data.write(to:url,options:[.atomic,.completeFileProtection])
        guard try JSONDecoder().decode(NOVAJSON.self,from:Data(contentsOf:url))==active else{throw CocoaError(.fileWriteUnknown)}
    }
}
@MainActor final class NOVASwiftBackupModel:ObservableObject {
    @Published private(set) var remote:NOVAJSON?
    @Published private(set) var status="Backup online non ancora verificato."
    @Published private(set) var busy=false
    @Published private(set) var conflict=false
    private var generation=0
    private var session:NOVASession?
    private var localAtRead:NOVAJSON?
    func cancel(){generation += 1;busy=false;remote=nil;session=nil;localAtRead=nil;conflict=false}
    func inspect(_ store:NOVASwiftStore) async {
        guard !busy,let active=store.archive?.active,let owner=NOVASession(active) else{return}
        generation += 1;let epoch=generation;session=owner;busy=true;defer{if epoch==generation{busy=false}}
        do{
            let result=try await NOVAAccountService(session:owner).account()
            guard epoch==generation,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            remote=result;localAtRead=NOVASwiftBackupData.snapshot(store.archive!.active)
            let cloud=result.object?["data"]
            conflict=cloud != nil && cloud != .null && cloud != localAtRead
            status=conflict ? "Le copie sono diverse. Nessuna scelta è automatica.":"Copia letta. Puoi salvare i dati di questo telefono."
        }catch{if epoch==generation{status="Backup non verificato. I dati restano su questo telefono."}}
    }
    func chooseCloud(_ store:NOVASwiftStore) async {
        guard !busy,let archive=store.archive,let owner=session,NOVASession(archive.active)==owner,
              let cloud=remote?.object?["data"],cloud.object != nil else{return}
        // Stop if a local edit occurred after the comparison was shown.
        guard NOVASwiftBackupData.snapshot(archive.active)==localAtRead else{status="La copia locale è cambiata. Confronta di nuovo prima di scegliere.";return}
        busy=true;let epoch=generation;defer{if generation==epoch{busy=false}}
        do{
            let fresh=try await NOVAAccountService(session:owner).account()
            guard generation==epoch,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            guard fresh.object?["rev"]==remote?.object?["rev"],fresh.object?["data"]==cloud,
                  NOVASwiftBackupData.snapshot(store.archive!.active)==localAtRead else{status="Una copia è cambiata. Confronta di nuovo prima di scegliere.";return}
            try NOVASwiftBackupData.recovery(archive.active)
            try store.update(owner:archive.owner){NOVASwiftBackupData.apply(cloud,to:&$0)}
            let defaults=UserDefaults.standard
            defaults.set(false,forKey:"nova.bgLoc.on");defaults.removeObject(forKey:"nova.bgLoc.session");defaults.removeObject(forKey:"nova.bgLoc.token");defaults.set(false,forKey:"nova.bgLoc.sharing")
            let background=CLLocationManager();background.stopMonitoringSignificantLocationChanges()
            localAtRead=NOVASwiftBackupData.snapshot(store.archive!.active);conflict=false
            status="Copia online importata. Recupero locale conservato; nessuna azione IA rieseguita."
        }catch{status="Ripristino fermato. Dati locali conservati."}
    }
    func saveLocal(_ store:NOVASwiftStore) async {
        guard !busy,let archive=store.archive,let owner=session,NOVASession(archive.active)==owner,let previous=remote else{status="Confronta prima il backup online.";return}
        guard NOVASwiftBackupData.snapshot(archive.active)==localAtRead else{status="La copia locale è cambiata. Confronta di nuovo prima di salvare.";return}
        let epoch=generation;busy=true;defer{if epoch==generation{busy=false}}
        do{
            try NOVASwiftBackupData.recovery(archive.active)
            let data=NOVASwiftBackupData.snapshot(archive.active)
            let response=try await NOVAAccountService(session:owner).request("account-data",method:"PUT",body:.object(["rev":previous.object?["rev"] ?? .null,"data":data]))
            guard epoch==generation,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            remote = .object(["rev":response.object?["rev"] ?? .null,"data":data]);localAtRead=data;conflict=false
            status=NOVASwiftBackupData.snapshot(store.archive!.active)==data ? "Backup online confermato.":"Backup confermato per la copia inviata; nuove modifiche locali da salvare."
        }catch NOVAServiceError.http(let code,_) where code==409{if epoch==generation{remote=nil;conflict=true;status="Un altro dispositivo ha modificato il backup. Confronta di nuovo."}}
        catch{if epoch==generation{status="Non salvato online. I dati restano su questo telefono."}}
    }
}
@MainActor struct NOVASwiftBackup:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var model=NOVASwiftBackupModel()
    @State private var cloudConfirmation=false
    @State private var localConfirmation=false
    var body:some View {
        Form {
            Section("Account NOVA"){
                Text(store.archive?.active.object?["acct"]?.object?["email"]?.string ?? "Nessun account collegato")
                Text(model.status).font(.footnote).foregroundStyle(.secondary)
                Button("Confronta backup"){Task{await model.inspect(store)}}.disabled(model.busy || store.archive.flatMap({NOVASession($0.active)})==nil)
            }
            if let data=model.remote?.object?["data"],data.object != nil{
                Section("Copia online"){
                    Text(data.object?["name"]?.string ?? "Senza nome")
                    Text("\(data.object?["tasks"]?.array.count ?? 0) compiti · \(data.object?["chat"]?.array.count ?? 0) messaggi IA")
                    Button("Usa copia online"){cloudConfirmation=true}.disabled(model.busy)
                }
            }
            if model.remote != nil{
                Section("Questo telefono"){
                    Button("Salva questa copia online"){localConfirmation=true}.disabled(model.busy)
                    Text("Una copia di recupero viene conservata prima della scelta. Password, chiavi, permessi e collegamenti servizi non entrano nel backup.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Backup account")
        .confirmationDialog("Usare la copia online?",isPresented:$cloudConfirmation,titleVisibility:.visible){Button("Usa copia online"){Task{await model.chooseCloud(store)}};Button("Annulla",role:.cancel){}}
        .confirmationDialog("Salvare questa copia al posto di quella online?",isPresented:$localConfirmation,titleVisibility:.visible){Button("Salva questa copia"){Task{await model.saveLocal(store)}};Button("Annulla",role:.cancel){}}
        .onDisappear{model.cancel()}
    }
}
