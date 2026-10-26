import SwiftUI

@MainActor enum NOVASwiftSchoolImport {
    static func apply(_ response:NOVAJSON,_ store:NOVASwiftStore,owner:String) throws {
        guard response.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse}
        try store.update(owner:owner){root in
            var tasks=root["tasks"]?.array ?? [],seen=Set<String>()
            let events=response.object?["events"]?.array ?? []
            for event in events {let item=event.object ?? [:];guard let original=item["id"]?.string,let date=item["date"]?.string,date.count==10 else{continue};let id="cv"+original;seen.insert(id)
                var fields:[String:NOVAJSON]=["title":item["title"] ?? .string("Compito"),"note":item["note"] ?? .string(""),"due":.string(date+"T08:00"),"kind":item["kind"] ?? .string("hw"),"subj":item["subj"] ?? .string(""),"teacher":item["teacher"] ?? .string("")]
                if let index=tasks.firstIndex(where:{$0.object?["id"]?.string==id}){if var old=tasks[index].object,old["src"]?.string=="cv"{old.merge(fields){_,new in new};tasks[index] = .object(old)}}else{fields.merge(["id":.string(id),"pr":.string("media"),"rem":.number(0),"done":.number(0),"fired":.number(0),"src":.string("cv")]){old,_ in old};tasks.append(.object(fields))}
            }
            if !events.isEmpty{tasks=tasks.filter{$0.object?["src"]?.string != "cv" || seen.contains($0.object?["id"]?.string ?? "") || $0.object?["done"]?.flag==true}}
            root["tasks"] = .array(tasks);if let grades=response.object?["grades"]{root["gr"] = grades};root["cv"] = .object(["on":.number(1),"name":response.object?["name"] ?? .string("")])
        }
    }
}
@MainActor final class NOVASwiftServicesModel:ObservableObject {
    @Published private(set) var status=""
    @Published private(set) var busy=false
    @Published private(set) var choices:[NOVAJSON]=[]
    @Published private(set) var spotify:NOVAJSON?
    @Published private(set) var spotifyConnected=false
    @Published private(set) var spotifyClient=false
    @Published private(set) var hasGroq=false
    private var epoch=0
    typealias Handler=([String:Any]) async -> [String:Any]
    private let school:Handler
    private let music:Handler
    private let ai:Handler
    init(school:Handler?=nil,music:Handler?=nil,ai:Handler?=nil){self.school=school ?? {await ClasseViva.handle($0)};self.music=music ?? {await Spotify.handle($0)};self.ai=ai ?? {await Groq.handle($0)}}
    static func json(_ value:[String:Any])->NOVAJSON?{guard let data=try? JSONSerialization.data(withJSONObject:value) else{return nil};return try? JSONDecoder().decode(NOVAJSON.self,from:data)}
    func cancel(){epoch+=1;busy=false;choices=[];spotify=nil}
    func load() async {let expected=epoch;let result=await music(["op":"status"]);guard expected==epoch else{return};spotifyConnected=result["conn"] as? Bool ?? (result["conn"] as? Int==1);spotifyClient=result["cid"] as? Bool ?? (result["cid"] as? Int==1);hasGroq=(await ai(["op":"has"]))["has"] as? Bool ?? false}
    func schoolRequest(_ op:String,uid:String="",password:String="",ident:String="",_ store:NOVASwiftStore) async {
        guard !busy,let archive=store.archive else{return};busy=true;let expected=epoch,owner=archive.owner,session=NOVASession(archive.active)
        var body:[String:Any]=["op":op];if op=="login"{guard !uid.isEmpty,!password.isEmpty,password==password.trimmingCharacters(in:.whitespacesAndNewlines) else{busy=false;status="Controlla codice utente e spazi nella password.";return};body["uid"]=uid;body["pass"]=password;if !ident.isEmpty{body["ident"]=ident}}
        let raw=await school(body);guard expected==epoch,store.archive?.owner==owner,store.archive.flatMap({NOVASession($0.active)})==session else{return};busy=false
        guard let response=Self.json(raw) else{status="Risposta ClasseViva non valida.";return}
        if response.object?["needChoice"]?.flag==true{choices=response.object?["choices"]?.array ?? [];status="Scegli il profilo studente.";return}
        guard response.object?["ok"]?.flag==true else{choices=[];status="ClasseViva non aggiornato. Controlla credenziali e connessione. Nessun dato precedente è stato cancellato.";return}
        do{if op=="logout"{try store.update(owner:owner){root in root["cv"] = .object(["on":.number(0)])};choices=[];status="ClasseViva scollegato. Compiti e voti importati conservati.";return};try NOVASwiftSchoolImport.apply(response,store,owner:owner);choices=[];status="ClasseViva aggiornato.";_ = await NOVASwiftTaskSync.apply(store)}catch{status="Dati ClasseViva ricevuti ma non salvati."}
    }
    func musicRequest(_ op:String,client:String="") async {guard !busy else{return};busy=true;let expected=epoch;var body:[String:Any]=["op":op];if op=="setcid"{body["cid"]=client};let result=await music(body);guard expected==epoch else{return};busy=false;if result["ok"] as? Int==1{status="Spotify aggiornato.";if op=="state"{spotify=Self.json(result)};await load()}else{let error=result["err"] as? String ?? "";status=error=="premium" ? "Per controllare Spotify serve Premium.":error=="nodevice" ? "Apri Spotify e avvia una canzone sul telefono.":error=="auth" ? "Ricollega Spotify dalle impostazioni.":"Spotify non aggiornato: "+error}}
    func groq(_ op:String,key:String="") async {guard !busy else{return};busy=true;let expected=epoch;let result=await ai(["op":op,"key":key]);guard expected==epoch else{return};busy=false;hasGroq=Secret.get("groq") != nil;status=result["ok"] as? Int==1 ? "Chiave Groq aggiornata nel Portachiavi.":"Chiave non salvata. Controlla formato Groq e connessione."}
}
@MainActor struct NOVASwiftServices:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var model:NOVASwiftServicesModel
    init(store:NOVASwiftStore,model:NOVASwiftServicesModel?=nil){self.store=store;_model=StateObject(wrappedValue:model ?? NOVASwiftServicesModel())}
    @State private var uid=""
    @State private var password=""
    @State private var key=""
    @State private var client=""
    @State private var confirmSchool=false
    @State private var confirmGroq=false
    @State private var confirmMusic=false
    var body:some View{Form{
        Section("ClasseViva"){
            if store.archive?.active.object?["cv"]?.object?["on"]?.flag==true{Text("Collegato: "+(store.archive?.active.object?["cv"]?.object?["name"]?.string ?? ""));Button("Aggiorna registro"){Task{await model.schoolRequest("refresh",store)}};Button("Scollega ClasseViva",role:.destructive){confirmSchool=true}}
            TextField("Codice utente o email",text:$uid).textInputAutocapitalization(.never).autocorrectionDisabled();SecureField("Password",text:$password)
            Button("Collega ClasseViva"){Task{await model.schoolRequest("login",uid:uid,password:password,store);if model.choices.isEmpty{password=""}}}.disabled(model.busy||uid.isEmpty||password.isEmpty)
            ForEach(Array(model.choices.enumerated()),id:\.offset){_,choice in Button((choice.object?["name"]?.string ?? "Studente")+" · "+(choice.object?["school"]?.string ?? "")){Task{await model.schoolRequest("login",uid:uid,password:password,ident:choice.object?["ident"]?.string ?? "",store);if model.choices.isEmpty{password=""}}}}
            Text("Password salvata nel Portachiavi di questo iPhone. I dati già importati restano conservati se l'aggiornamento fallisce.").font(.footnote).foregroundStyle(.secondary)
        }
        Section("Assistente Groq"){
            Text(model.hasGroq ? "Chiave già presente nel Portachiavi.":"Serve una chiave Groq personale.")
            SecureField("gsk_…",text:$key).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Verifica e salva chiave"){let value=key;key="";Task{await model.groq("set",key:value)}}.disabled(model.busy||key.isEmpty)
            Link("Crea una chiave Groq gratuita",destination:URL(string:"https://console.groq.com/keys")!)
            if model.hasGroq{Button("Rimuovi chiave",role:.destructive){confirmGroq=true}}
        }
        Section("Spotify"){
            Text(model.spotifyConnected ? "Spotify collegato.":"Spotify non collegato.")
            TextField("Client ID Spotify",text:$client).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Salva Client ID"){confirmMusic=true}.disabled(model.busy||client.isEmpty)
            if model.spotifyClient{Button("Collega Spotify"){Task{await model.musicRequest("login")}}}
            if model.spotifyConnected{Button("Aggiorna riproduzione"){Task{await model.musicRequest("state")}};Button("Scollega Spotify",role:.destructive){Task{await model.musicRequest("logout")}}}
            Text("Controlli di riproduzione: richiedono Spotify Premium. Redirect da configurare nella tua app Spotify: nova://spotify-callback").font(.footnote).foregroundStyle(.secondary)
        }
        if !model.status.isEmpty{Text(model.status).font(.footnote)}
    }.navigationTitle("Servizi").task{await model.load()}.onDisappear{password="";key="";model.cancel()}.onChange(of:store.archive?.owner){_,_ in password="";key="";model.cancel()}
    .confirmationDialog("Scollegare ClasseViva da questo iPhone? Compiti e voti gia importati restano salvati.",isPresented:$confirmSchool,titleVisibility:.visible){Button("Scollega",role:.destructive){password="";Task{await model.schoolRequest("logout",store)}};Button("Annulla",role:.cancel){}}
    .confirmationDialog("Rimuovere la chiave Groq da questo iPhone?",isPresented:$confirmGroq,titleVisibility:.visible){Button("Rimuovi",role:.destructive){Task{await model.groq("clear")}};Button("Annulla",role:.cancel){}}
    .confirmationDialog("Salvare il Client ID e scollegare la sessione Spotify attuale?",isPresented:$confirmMusic,titleVisibility:.visible){Button("Salva"){Task{await model.musicRequest("setcid",client:client)}};Button("Annulla",role:.cancel){}}
    }
}
@MainActor struct NOVASwiftMusicCard:View {
    @StateObject private var model:NOVASwiftServicesModel
    init(model:NOVASwiftServicesModel?=nil){_model=StateObject(wrappedValue:model ?? NOVASwiftServicesModel())}
    var body:some View{VStack(alignment:.leading,spacing:10){if let o=model.spotify?.object,o["idle"]?.flag != true{Text(o["track"]?.string ?? "").font(.headline);Text(o["artist"]?.string ?? "").foregroundStyle(.secondary)}else{Text(model.spotifyConnected ? "Niente in riproduzione. Avvia Spotify sul telefono.":"Collega Spotify dalle impostazioni.")};HStack{Button{Task{await model.musicRequest("prev");await model.musicRequest("state")}}label:{Image(systemName:"backward.end.fill")}.accessibilityLabel("Precedente");Button{Task{await model.musicRequest(model.spotify?.object?["playing"]?.flag==true ? "pause":"play");await model.musicRequest("state")}}label:{Image(systemName:model.spotify?.object?["playing"]?.flag==true ? "pause.fill":"play.fill")}.accessibilityLabel("Play o pausa");Button{Task{await model.musicRequest("next");await model.musicRequest("state")}}label:{Image(systemName:"forward.end.fill")}.accessibilityLabel("Successivo");Spacer();Button{Task{await model.musicRequest("state")}}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("Aggiorna Spotify")}.buttonStyle(.bordered).disabled(!model.spotifyConnected||model.busy);if !model.status.isEmpty{Text(model.status).font(.footnote).foregroundStyle(.secondary)}}.task{await model.load();if model.spotifyConnected{await model.musicRequest("state")}}.onDisappear{model.cancel()}}

}
