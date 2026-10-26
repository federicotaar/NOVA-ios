import SwiftUI
import PhotosUI
import UIKit
import WebKit
import UserNotifications
// Swift-owned state foundation. Not activated until screen/service parity is verified.
// Unknown JSON keys survive import and every write. Legacy storage is never deleted.
indirect enum NOVAJSON: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([NOVAJSON]), object([String:NOVAJSON])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([NOVAJSON].self) { self = .array(v) }
        else { self = .object(try c.decode([String:NOVAJSON].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    var object: [String:NOVAJSON]? { if case .object(let o) = self { return o }; return nil }
    var string: String? { if case .string(let s) = self { return s }; return nil }
}
struct NOVASwiftArchive: Codable {
    let version: Int
    let importedAt: Date
    var localStorage: [String:String]
    var active: NOVAJSON
    var owner: String {
        active.object?["acct"]?.object?["email"]?.string?.lowercased() ?? "local"
    }
    static func imported(_ values: [String:String]) throws -> NOVASwiftArchive {
        guard let source = values["nova.v1"], let bytes = source.data(using:.utf8),
              let state = try? JSONDecoder().decode(NOVAJSON.self, from:bytes), state.object != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return NOVASwiftArchive(version:1, importedAt:Date(), localStorage:values, active:state)
    }
}
@MainActor final class NOVASwiftStore: ObservableObject {
    @Published private(set) var archive: NOVASwiftArchive?
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("NOVASwift",isDirectory:true)
        let url = self.directory.appendingPathComponent("state-v1.json")
        if let data = try? Data(contentsOf:url) { archive = try? JSONDecoder().decode(NOVASwiftArchive.self,from:data) }
    }
    // Called only after the user reviews the one-time migration offer.
    func importOnce(_ values: [String:String]) throws {
        guard archive == nil else { throw CocoaError(.fileWriteFileExists) }
        let imported = try NOVASwiftArchive.imported(values)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(imported)
        // Keep an immutable recovery copy before activating the new state.
        try data.write(to:directory.appendingPathComponent("legacy-import-v1.json"),options:[.atomic,.completeFileProtection])
        try data.write(to:directory.appendingPathComponent("state-v1.json"),options:[.atomic,.completeFileProtection])
        let readBack = try JSONDecoder().decode(NOVASwiftArchive.self,from:Data(contentsOf:directory.appendingPathComponent("state-v1.json")))
        guard readBack.active == imported.active, readBack.localStorage == imported.localStorage else { throw CocoaError(.fileWriteUnknown) }
        archive = readBack
    }
    func update(owner: String, _ edit: (inout [String:NOVAJSON]) throws -> Void) throws {
        guard var current = archive, current.owner == owner, var state = current.active.object else { throw CocoaError(.userCancelled) }
        let previousOwner = current.owner
        try edit(&state); current.active = .object(state)
        // Account transitions use a separate reviewed transaction, never an ordinary field update.
        guard current.owner == previousOwner else { throw CocoaError(.userCancelled) }
        let data = try JSONEncoder().encode(current)
        try data.write(to:directory.appendingPathComponent("state-v1.json"),options:[.atomic,.completeFileProtection])
        archive = current
    }
}
// Swift-only screens under parity review. No DOM, JavaScript models or action callbacks.
extension NOVAJSON {
    var array: [NOVAJSON] { if case .array(let a) = self { return a }; return [] }
    var integer: Int { if case .number(let n) = self { return Int(n) }; return 0 }
    var flag: Bool { if case .bool(let b) = self { return b }; return integer != 0 }
}
struct NOVALessonDraft: Identifiable {
    let id = UUID()
    var day: Int = 2
    var start: Int = 540
    var end: Int = 600
    var subject = ""
    var room = ""
    var extra: [String:NOVAJSON] = [:]
    init(_ value: NOVAJSON) {
        extra = value.object ?? [:]; day = extra["d"]?.integer ?? 2
        start = extra["s"]?.integer ?? 540; end = extra["e"]?.integer ?? 600
        subject = extra["n"]?.string ?? ""; room = extra["r"]?.string ?? ""
    }
    init(day:Int) { self.day = day }
    var json: NOVAJSON {
        var o = extra
        o["d"] = .number(Double(day)); o["s"] = .number(Double(start)); o["e"] = .number(Double(end))
        o["n"] = .string(subject.trimmingCharacters(in:.whitespacesAndNewlines).prefix(14).uppercased())
        o["r"] = .string(String(room.trimmingCharacters(in:.whitespacesAndNewlines).prefix(10)))
        return .object(o)
    }
}
@MainActor struct NOVASwiftTimetable: View {
    @ObservedObject var store: NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var lessons: [NOVALessonDraft] = []
    @State private var day = 2
    @State private var error = ""
    @State private var loaded = false
    @State private var owner = ""
    @State private var session:NOVASession?
    @State private var photo:PhotosPickerItem?
    @State private var importing=false
    @State private var importEpoch=0
    @State private var active=false
    let days = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Giorno") {
                    Picker("Giorno",selection:$day) { ForEach(2...7,id:\.self){Text(days[$0-2]).tag($0)} }
                        .pickerStyle(.segmented)
                }
                ForEach($lessons) { $lesson in
                    if lesson.day == day {
                        Section("Lezione") {
                            DatePicker("Inizio",selection:time($lesson.start),displayedComponents:.hourAndMinute)
                            DatePicker("Fine",selection:time($lesson.end),displayedComponents:.hourAndMinute)
                            TextField("Materia",text:$lesson.subject).textInputAutocapitalization(.characters)
                            TextField("Aula",text:$lesson.room)
                            Button("Elimina",role:.destructive) { lessons.removeAll{$0.id==lesson.id} }
                        }
                    }
                }
                if !lessons.contains(where:{$0.day==day}) { Text("Nessuna lezione per questo giorno.").foregroundStyle(.secondary) }
                Section {
                    PhotosPicker(importing ? "Lettura foto…":"Importa foto orario",selection:$photo,matching:.images).disabled(importing)
                    Button("Aggiungi lezione") { lessons.append(NOVALessonDraft(day:day)) }
                    Button("Svuota giorno",role:.destructive) { lessons.removeAll{$0.day==day} }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                Text("Le modifiche restano in bozza fino a Salva. I widget ricevono l'orario solo se la condivisione è disponibile.").font(.footnote).foregroundStyle(.secondary)
            }
            .environment(\.locale,Locale(identifier:"it_IT"))
            .navigationTitle("Il tuo orario")
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Annulla"){dismiss()} }
                ToolbarItem(placement:.confirmationAction) { Button("Salva"){save()} }
            }
        }
        .onAppear {
            active=true;guard !loaded else{return}; loaded=true; owner=store.archive?.owner ?? "";session=store.archive.flatMap({NOVASession($0.active)})
            lessons=(store.archive?.active.object?["tt"]?.object?["lessons"]?.array ?? []).map(NOVALessonDraft.init)
        }.onDisappear{active=false;importEpoch+=1;importing=false}.onChange(of:photo){_,item in importPhoto(item)}
    }
    func importPhoto(_ item:PhotosPickerItem?){importEpoch+=1;let epoch=importEpoch,session=store.archive.flatMap({NOVASession($0.active)});importing=true;error=""
        Task{defer{if epoch==importEpoch{importing=false}};guard let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data) else{if epoch==importEpoch{error="Foto non leggibile."};return};guard active,epoch==importEpoch,store.archive?.owner==owner,store.archive.flatMap({NOVASession($0.active)})==session else{return}
            let scale=min(1,1600/max(image.size.width,image.size.height)),size=CGSize(width:image.size.width*scale,height:image.size.height*scale);let jpeg=UIGraphicsImageRenderer(size:size).jpegData(withCompressionQuality:0.85){_ in image.draw(in:CGRect(origin:.zero,size:size))}
            let prompt="Estrai tutte le lezioni visibili in questo orario scolastico. Rispondi solo JSON: {\"lessons\":[{\"d\":1,\"h\":1,\"s\":\"08:10\",\"e\":\"09:00\",\"n\":\"MAT\"}]}. d=1 lunedi fino 6 sabato. h=numero ora. s/e=null se non visibili. Non inventare materie."
            let response=await Groq.handle(["op":"vision","img":"data:image/jpeg;base64,"+jpeg.base64EncodedString(),"prompt":prompt]);guard active,epoch==importEpoch,store.archive?.owner==owner,store.archive.flatMap({NOVASession($0.active)})==session else{return}
            do{guard response["ok"] as? Int==1,let text=response["text"] as? String else{throw NOVAServiceError.invalidResponse};let parsed=try NOVASwiftTimetablePhoto.parse(text);lessons=parsed.lessons;day=2;error=parsed.estimated ? "Foto letta. Orari mancanti stimati: controlla ogni giorno e salva solo dopo averli corretti.":"Foto letta. Controlla giorni, orari e materie, poi Salva."}catch{self.error="Orario non importato. Controlla la chiave Groq o prova una foto piu nitida. La bozza precedente resta conservata."}
        }
    }
    func time(_ value: Binding<Int>) -> Binding<Date> {
        Binding(get:{Calendar.current.startOfDay(for:Date()).addingTimeInterval(Double(value.wrappedValue*60))},set:{date in let c=Calendar.current.dateComponents([.hour,.minute],from:date);value.wrappedValue=(c.hour ?? 0)*60+(c.minute ?? 0)})
    }
    func save() {
        guard store.archive?.owner==owner,store.archive.flatMap({NOVASession($0.active)})==session else{error="Account cambiato. Chiudi e riapri l'orario.";return}
        guard lessons.allSatisfy({!$0.subject.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.start >= 0 && $0.end <= 1440 && $0.end > $0.start}) else {error="Controlla materia e orari: la fine deve essere dopo l'inizio.";return}
        do {
            let values=lessons.sorted{$0.day==$1.day ? $0.start<$1.start:$0.day<$1.day}.map(\.json)
            try store.update(owner:owner){root in var timetable=root["tt"]?.object ?? [:];timetable["lessons"] = .array(values);root["tt"] = .object(timetable)}
            // Same on-device widget file format, no web bridge.
            let object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(NOVAJSON.object(["v":.number(1),"lessons":.array(values)])))
            if let bytes=try? JSONSerialization.data(withJSONObject:object),let json=String(data:bytes,encoding:.utf8){_ = TT.save(json)}
            dismiss()
        } catch {self.error="Salvataggio non riuscito. La bozza resta aperta e i dati precedenti sono conservati."}
    }
}
@MainActor struct NOVASwiftOverview: View {
    @ObservedObject var store: NOVASwiftStore
    @State private var timetable = false
    @State private var taskEditor = false
    @State private var actionError = ""
    var root: [String:NOVAJSON] { store.archive?.active.object ?? [:] }
    static func deadline(_ value:String)->String {
        let parser=DateFormatter();parser.locale=Locale(identifier:"en_US_POSIX");parser.dateFormat="yyyy-MM-dd'T'HH:mm"
        guard let date=parser.date(from:value) else{return value}
        let output=DateFormatter();output.locale=Locale(identifier:"it_IT");output.dateFormat="EEE d MMM, HH:mm";return output.string(from:date)
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ciao "+(root["name"]?.string ?? "")).font(.largeTitle.bold())
                    Text("Anteprima Swift: dati locali importati. Servizi e altre schermate ancora in verifica.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Compiti") {
                    Button("Nuovo compito"){taskEditor=true}
                    let tasks=root["tasks"]?.array ?? []
                    if tasks.isEmpty {Text("Nessun compito")}
                    ForEach(Array(tasks.enumerated()),id:\.offset){_,task in
                        let o=task.object ?? [:]
                        HStack{Button{do{try NOVASwiftTaskActions.mutate(store,owner:store.archive?.owner ?? "",id:o["id"]?.string ?? "")}catch{actionError="Modifica non salvata"}}label:{Image(systemName:o["done"]?.flag == true ? "checkmark.circle.fill":"circle")}.buttonStyle(.plain);VStack(alignment:.leading){Text(o["title"]?.string ?? "Compito");Text(NOVASwiftOverview.deadline(o["due"]?.string ?? "")).font(.caption).foregroundStyle(.secondary)}}
                    }
                }
                Section("Orario") {
                    Button("Modifica orario"){timetable=true}
                    Text("\(root["tt"]?.object?["lessons"]?.array.count ?? 0) \((root["tt"]?.object?["lessons"]?.array.count ?? 0)==1 ? "lezione salvata":"lezioni salvate")")
                }
            if !actionError.isEmpty{Text(actionError).foregroundStyle(.red)}
            }.navigationTitle("NOVA")
        }.sheet(isPresented:$timetable){NOVASwiftTimetable(store:store)}.sheet(isPresented:$taskEditor){NOVASwiftTaskEditor(store:store)}
    }
}
// Swift transport preserves backend permissions; no privileged endpoints or invented defaults.
struct NOVASession: Equatable {
    let email: String
    let token: String
    init?(_ state: NOVAJSON) {
        guard let acct=state.object?["acct"]?.object,
              let email=acct["email"]?.string, let token=acct["token"]?.string,
              !email.isEmpty, !token.isEmpty else {return nil}
        self.email=email.lowercased();self.token=token
    }
}
enum NOVAServiceError: Error { case invalidResponse, http(Int,String), accountChanged }
struct NOVAAccountService {
    let session: NOVASession
    let base=URL(string:"https://api.federicotaranu.site")!
    func request(_ path:String,method:String="GET",body:NOVAJSON?=nil,query:[URLQueryItem]=[]) async throws -> NOVAJSON {
        var components=URLComponents(url:base.appendingPathComponent(path),resolvingAgainstBaseURL:false)!
        if !query.isEmpty{components.queryItems=query}
        var request=URLRequest(url:components.url!);request.httpMethod=method;request.timeoutInterval=25
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("Bearer "+session.token,forHTTPHeaderField:"Authorization")
        if let body=body{request.httpBody=try JSONEncoder().encode(body)}
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse else{throw NOVAServiceError.invalidResponse}
        let json=try JSONDecoder().decode(NOVAJSON.self,from:data)
        guard (200..<300).contains(response.statusCode) else{throw NOVAServiceError.http(response.statusCode,json.object?["error"]?.string ?? "Richiesta non riuscita")}
        return json
    }
    func account() async throws -> NOVAJSON { try await request("account-data") }
    func profile() async throws -> NOVAJSON { try await request("profile") }
    func friends() async throws -> NOVAJSON { try await request("friends") }
    func chats() async throws -> NOVAJSON { try await request("chats") }
}
@MainActor final class NOVASwiftAccountCoordinator: ObservableObject {
    @Published private(set) var remote: NOVAJSON?
    @Published private(set) var status=""
    private var generation=0
    // Read-only until conflict comparison and reviewed selection are available.
    func refresh(_ store:NOVASwiftStore) async {
        guard let archive=store.archive,let session=NOVASession(archive.active) else{return}
        generation+=1;let expected=generation
        status="Controllo backup account…"
        do {
            let response=try await NOVAAccountService(session:session).account()
            guard expected==generation,let active=store.archive?.active,NOVASession(active)==session else{return}
            remote=response;status="Copia online letta. Nessuna sovrascrittura automatica."
        }catch{
            guard expected==generation,let active=store.archive?.active,NOVASession(active)==session else{return}
            status="Copia online non verificata. Dati locali conservati."
        }
    }
    func invalidate(){generation+=1;remote=nil;status=""}
}
// One-time legacy reader. Used only by an explicit migration offer, never as a screen model.
@MainActor final class NOVALegacyReader: NSObject, WKNavigationDelegate {
    private var web: WKWebView?
    private var completion: ((Result<[String:String],Error>)->Void)?
    func read(_ completion:@escaping(Result<[String:String],Error>)->Void) {
        guard web==nil else{completion(.failure(CocoaError(.userCancelled)));return}
        self.completion=completion
        let config=WKWebViewConfiguration();config.websiteDataStore = .default()
        let view=WKWebView(frame:.zero,configuration:config);view.navigationDelegate=self;web=view
        #if SWIFT_PACKAGE
        let bundle=Bundle.module
        #else
        let bundle=Bundle.main
        #endif
        guard let source=bundle.url(forResource:"nova",withExtension:"html") else{finish(.failure(CocoaError(.fileNoSuchFile)));return}
        // Same origin as the old app, but no legacy scripts run and no network calls are made.
        view.loadHTMLString("<!doctype html><meta charset='utf-8'><title>Importazione</title>",baseURL:source)
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        webView.evaluateJavaScript("Object.fromEntries(Object.keys(localStorage).filter(k=>k.startsWith('nova.')).map(k=>[k,localStorage.getItem(k)]))"){[weak self] result,error in
            guard let self=self else{return};if let error=error{self.finish(.failure(error));return}
            guard let values=result as? [String:String],values["nova.v1"] != nil else{self.finish(.failure(CocoaError(.fileReadCorruptFile)));return}
            self.finish(.success(values))
        }
    }
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error){finish(.failure(error))}
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){finish(.failure(error))}
    private func finish(_ result:Result<[String:String],Error>){let callback=completion;completion=nil;web?.stopLoading();web?.navigationDelegate=nil;web=nil;callback?(result)}
}
@MainActor struct NOVASwiftMigrationOffer: View {
    @ObservedObject var store:NOVASwiftStore
    @State private var reader=NOVALegacyReader()
    @State private var busy=false
    @State private var error=""
    var body:some View {
        VStack(alignment:.leading,spacing:20){
            Text("Passa ai dati Swift").font(.largeTitle.bold())
            Text("Copia i dati già salvati su questo iPhone nel nuovo archivio Swift. La memoria precedente non viene cancellata. Conserviamo una copia di recupero e le cache dei tuoi account. Non vengono attivati permessi, posizione o servizi.")
            Text("Questa anteprima non sostituisce ancora tutte le funzioni. Non usarla come aggiornamento definitivo.").foregroundStyle(.secondary)
            if !error.isEmpty{Text(error).foregroundStyle(.red)}
            Button(busy ? "Copia in corso…":"Importa una volta"){busy=true;reader.read{result in busy=false;do{try store.importOnce(result.get())}catch{self.error="Importazione non completata. I dati precedenti non sono stati modificati."}}}.disabled(busy)
        }.padding(24)
    }
}
extension NOVAJSON {
    var double: Double { if case .number(let n)=self{return n};return 0 }
}
@MainActor enum NOVASwiftTaskActions {
    static func mutate(_ store:NOVASwiftStore,owner:String,id:String,remove:Bool=false) throws {
        try store.update(owner:owner){root in
            var items=root["tasks"]?.array ?? []
            guard let index=items.firstIndex(where:{$0.object?["id"]?.string==id}) else{throw CocoaError(.fileNoSuchFile)}
            if remove{items.remove(at:index)}else{var task=items[index].object!;task["done"] = .number(task["done"]?.flag == true ? 0:1);items[index] = .object(task)}
            root["tasks"] = .array(items)
        }
        Task{_ = await NOVASwiftTaskSync.apply(store)}
    }
    static func add(_ store:NOVASwiftStore,owner:String,title:String,note:String,due:Date,priority:String,reminder:Int) throws {
        let title=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !title.isEmpty,title.count<=120,note.count<=400 else{throw CocoaError(.validationMissingMandatoryProperty)}
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="yyyy-MM-dd'T'HH:mm"
        let date=f.string(from:due)
        try store.update(owner:owner){root in
            var items=root["tasks"]?.array ?? []
            guard !items.contains(where:{let o=$0.object ?? [:];return o["done"]?.flag != true && o["due"]?.string==date && o["title"]?.string?.lowercased()==title.lowercased()}) else{throw CocoaError(.validationMultipleErrors)}
            items.append(.object(["id":.string(UUID().uuidString),"title":.string(title),"note":.string(note.trimmingCharacters(in:.whitespacesAndNewlines)),"due":.string(date),"pr":.string(priority),"rem":.number(Double(reminder)),"done":.number(0),"fired":.number(0),"src":.string("manuale"),"kind":.string("man")]))
            root["tasks"] = .array(items)
        }
        Task{_ = await NOVASwiftTaskSync.apply(store)}
    }
}
@MainActor struct NOVASwiftTaskEditor:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var title=""
    @State private var note=""
    @State private var due=Calendar.current.date(bySettingHour:18,minute:0,second:0,of:Date().addingTimeInterval(86400)) ?? Date()
    @State private var priority="media"
    @State private var reminder=60
    @State private var owner=""
    @State private var error=""
    var body:some View {
        NavigationStack{Form{
            Section("Compito"){TextField("Cosa devi fare?",text:$title)}
            Section("Descrizione (facoltativa)"){TextEditor(text:$note).frame(minHeight:90)}
            Section("Scadenza"){DatePicker("Scadenza",selection:$due)}
            Section("Opzioni"){
                Picker("Priorità",selection:$priority){Text("Alta").tag("alta");Text("Media").tag("media");Text("Bassa").tag("bassa")}
                Picker("Promemoria",selection:$reminder){Text("Nessuno").tag(0);Text("10 minuti prima").tag(10);Text("1 ora prima").tag(60);Text("1 giorno prima").tag(1440)}
            }
            if !error.isEmpty{Text(error).foregroundStyle(.red)}
        }.environment(\.locale,Locale(identifier:"it_IT")).navigationTitle("Nuovo compito").toolbar{
            ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}}
            ToolbarItem(placement:.confirmationAction){Button("Aggiungi"){do{try NOVASwiftTaskActions.add(store,owner:owner,title:title,note:note,due:due,priority:priority,reminder:reminder);dismiss()}catch{self.error="Controlla titolo, descrizione e duplicati. Nessun dato precedente è stato modificato."}}}
        }}.onAppear{owner=store.archive?.owner ?? ""}
    }
}
@MainActor enum NOVASwiftTaskSync {
    static func apply(_ store:NOVASwiftStore) async -> Bool {
        guard let archive=store.archive else{return false}
        let owner=archive.owner,snapshot=archive.active
        let tasks=archive.active.object?["tasks"]?.array ?? []
        let homework=tasks.compactMap{task -> NOVAJSON? in
            let o=task.object ?? [:]
            guard o["done"]?.flag != true,o["kind"]?.string != "test",let due=o["due"]?.string else{return nil}
            return .object(["t":o["title"] ?? .string(""),"s":o["subj"] ?? .string(""),"d":.string(String(due.prefix(10)))])
        }
        if let data=try? JSONEncoder().encode(NOVAJSON.object(["v":.number(1),"items":.array(homework)])),let json=String(data:data,encoding:.utf8){_ = TT.saveHomework(json)}
        let center=UNUserNotificationCenter.current()
        let settings=await center.notificationSettings()
        guard store.archive?.owner==owner,store.archive?.active==snapshot else{return false}
        guard [.authorized,.provisional,.ephemeral].contains(settings.authorizationStatus) else{return false}
        // Remove first and await the read, avoiding the previous scheduling race.
        let pending=await center.pendingNotificationRequests()
        guard store.archive?.owner==owner,store.archive?.active==snapshot else{return false}
        center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter{$0.hasPrefix("rem.")})
        let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.dateFormat="yyyy-MM-dd'T'HH:mm"
        let reminders=tasks.compactMap{task -> (String,String,Date)? in
            let o=task.object ?? [:]
            guard o["done"]?.flag != true,let id=o["id"]?.string,let title=o["title"]?.string,
                  let due=o["due"]?.string,let date=formatter.date(from:due),let minutes=o["rem"]?.integer,minutes>0 else{return nil}
            let fire=date.addingTimeInterval(-Double(minutes*60));guard fire>Date() else{return nil};return(id,title,fire)
        }.sorted{$0.2<$1.2}.prefix(25)
        var success=true
        for (id,title,date) in reminders {
            guard store.archive?.owner==owner,store.archive?.active==snapshot else{return false}
            let content=UNMutableNotificationContent();content.title="NOVA · Promemoria";content.body=title;content.sound = .default
            let components=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second],from:date)
            do{try await center.add(UNNotificationRequest(identifier:"rem."+id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:components,repeats:false)))}catch{success=false}
        }
        return success
    }
}
@MainActor struct NOVASwiftAssistant:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var draft=""
    @State private var sending=false
    @State private var status=""
    @State private var generation=0
    @State private var owner=""
    @State private var photo:PhotosPickerItem?
    @State private var photoDraft:String?
    @State private var photoEpoch=0
    var messages:[NOVAJSON]{store.archive?.active.object?["chat"]?.array ?? []}
    var body:some View {
        NavigationStack {
            VStack(spacing:0){
                ScrollViewReader{proxy in ScrollView{LazyVStack(alignment:.leading,spacing:14){
                    if messages.isEmpty{Text("Chiedimi aiuto con lo studio. Serve la tua chiave Groq già salvata nelle impostazioni.").foregroundStyle(.secondary)}
                    ForEach(Array(messages.enumerated()),id:\.offset){index,message in
                        let o=message.object ?? [:]
                        VStack(alignment:.leading,spacing:8){
                            Text(o["r"]?.string=="user" ? "Tu":"NOVA").font(.caption.bold()).foregroundStyle(.secondary)
                            if let image=o["img"]?.string,let data=Data(base64Encoded:image.components(separatedBy:",").last ?? ""),let ui=UIImage(data:data){Image(uiImage:ui).resizable().scaledToFit().frame(maxHeight:200)}
                            Text(o["c"]?.string ?? "").textSelection(.enabled)
                            ForEach(Array((o["acts"]?.array ?? []).enumerated()),id:\.offset){action,value in
                                let item=value.object ?? [:],state=item["st"]?.string ?? ""
                                VStack(alignment:.leading){Text(item["a"]?.string=="open" ? "Apri: "+(item["page"]?.string ?? ""):"Aggiungi: "+(item["title"]?.string ?? ""));if state=="wait",item["swiftID"]?.string != nil{HStack{Button("Conferma"){Task{await NOVASwiftAssistantActions.run(store,owner:owner,message:index,action:action)}};Button("Annulla"){try? NOVASwiftAssistantActions.update(store,owner:owner,message:index,action:action,state:"no",note:"Annullata.")}}}else{Text(item["note"]?.string ?? (state=="pending" ? "Attendo conferma…":state=="off" ? "Azioni disattivate":"Azione conservata, non rieseguita.")).font(.caption).foregroundStyle(.secondary)}}
                            }
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(o["r"]?.string=="user" ? Color.blue.opacity(0.1):Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:20)).id(index)
                    }
                }.padding()}.onChange(of:messages.count){_,_ in if !messages.isEmpty{proxy.scrollTo(messages.count-1,anchor:.bottom)}}}
                if !status.isEmpty{Text(status).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)}
                if let photoDraft=photoDraft,let data=Data(base64Encoded:photoDraft.components(separatedBy:",").last ?? ""),let image=UIImage(data:data){HStack{Image(uiImage:image).resizable().scaledToFit().frame(height:90);Button("Rimuovi foto",role:.destructive){self.photoDraft=nil}}}
                HStack(alignment:.bottom){
                    PhotosPicker(selection:$photo,matching:.images){Image(systemName:"photo")}.accessibilityLabel("Allega foto")
                    TextField("Scrivi un messaggio",text:$draft,axis:.vertical).lineLimit(1...6).textFieldStyle(.plain)
                    Button{send()}label:{Image(systemName:sending ? "hourglass":"arrow.up").font(.headline).frame(width:36,height:36)}.buttonStyle(.borderedProminent).buttonBorderShape(.circle).disabled(sending || (draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && photoDraft==nil))
                }.modifier(NOVASwiftComposerSurface()).padding(.horizontal,12).padding(.bottom,8)
            }.navigationTitle("Assistente")
        }.onAppear{owner=store.archive?.owner ?? ""}.onDisappear{generation+=1;photoEpoch+=1;sending=false}
        .onChange(of:store.archive?.owner){_,_ in generation+=1;photoEpoch+=1;owner=store.archive?.owner ?? "";draft="";photoDraft=nil;sending=false}
        .onChange(of:photo){_,item in photoEpoch+=1;let epoch=photoEpoch,expectedOwner=owner;Task{guard let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data),epoch==photoEpoch,owner==expectedOwner,owner==store.archive?.owner else{return};let scale=min(1,1200/max(image.size.width,image.size.height)),size=CGSize(width:image.size.width*scale,height:image.size.height*scale);let jpeg=UIGraphicsImageRenderer(size:size).jpegData(withCompressionQuality:0.7){_ in image.draw(in:CGRect(origin:.zero,size:size))};photoDraft="data:image/jpeg;base64,"+jpeg.base64EncodedString()}}

    }
    func send(){
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        let image=photoDraft
        guard (!text.isEmpty || image != nil),!sending,owner==store.archive?.owner else{return}
        guard Secret.get("groq") != nil else{status="Prima salva la tua chiave Groq nelle impostazioni.";return}
        let snapshot=store.archive!.active.object ?? [:]
        do{try store.update(owner:owner){root in var chat=root["chat"]?.array ?? [];var item:[String:NOVAJSON]=["r":.string("user"),"c":.string(text)];if let image=image{item["img"] = .string(image)};chat.append(.object(item));root["chat"] = .array(Array(chat.suffix(40)))}}catch{status="Messaggio non salvato. Riprova.";return}
        draft="";photoDraft=nil;sending=true;generation+=1;let expected=generation,expectedOwner=owner,expectedSession=store.archive.flatMap{NOVASession($0.active)}
        let permission=snapshot["aiAct"]?.string ?? "ask"
        let system=NOVASwiftAssistantActions.system(snapshot)
        let history=messages.suffix(12).map{message -> [String:String] in let o=message.object ?? [:];return["role":o["r"]?.string=="user" ? "user":"assistant","content":o["c"]?.string ?? ""]}
        Task{
            let response:[String:Any]
            if let image=image{response=await Groq.handle(["op":"vision","img":image,"prompt":system+"\nRichiesta: "+text])}else{response=await Groq.handle(["op":"chat","messages":[["role":"system","content":system]]+history])}
            guard expected==generation,expectedOwner==store.archive?.owner,store.archive.flatMap({NOVASession($0.active)})==expectedSession else{return};sending=false
            let answer=(response["ok"] as? Int)==1 ? (response["text"] as? String ?? ""):"Richiesta non completata. Controlla connessione e chiave Groq."
            let (visible,actions)=NOVASwiftAssistantActions.parse(answer,permission:permission)
            do{try store.update(owner:expectedOwner){root in var chat=root["chat"]?.array ?? [];chat.append(.object(["r":.string("assistant"),"c":.string(visible),"acts":.array(actions)]));root["chat"] = .array(Array(chat.suffix(40)))};if permission=="always"{let message=messages.count-1;for action in actions.indices{await NOVASwiftAssistantActions.run(store,owner:expectedOwner,message:message,action:action,automatic:true)}}}catch{status="Risposta ricevuta ma non salvata: "+visible}
        }
    }
}
@MainActor struct NOVASwiftProfileEditor:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var draft:[String:NOVAJSON]=[:]
    @State private var owner=""
    @State private var token=""
    @State private var status=""
    @State private var saving=false
    @State private var photo:PhotosPickerItem?
    @State private var songPicker=false
    @State private var photoEpoch=0
    @State private var active=false
    @State private var initialized=false
    func field(_ key:String)->Binding<String>{Binding(get:{draft[key]?.string ?? ""},set:{draft[key] = .string($0)})}
    var body:some View {
        NavigationStack{Form{
            Section("Foto profilo"){
                if let value=draft["avatar"]?.string,let bytes=Data(base64Encoded:value.components(separatedBy:",").last ?? ""),let image=UIImage(data:bytes){Image(uiImage:image).resizable().scaledToFill().frame(width:80,height:80).clipShape(Circle())}
                PhotosPicker("Scegli foto",selection:$photo,matching:.images)
                Text("Visibile secondo le regole del profilo e dell'amicizia.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Username"){TextField("Username",text:field("username")).textInputAutocapitalization(.never).autocorrectionDisabled()}
            Section("Su di te"){
                TextField("Dove studi",text:field("study"));TextField("Punti forti",text:field("skills"));TextField("Hobby",text:field("hobbies"))
            }
            if draft["song"]?.object==nil{Section("La tua canzone"){Button("Scegli canzone"){songPicker=true}}}
            if let song=draft["song"]?.object{Section("La tua canzone"){Text(song["t"]?.string ?? "");Text(song["a"]?.string ?? "").foregroundStyle(.secondary);Button("Cambia canzone"){songPicker=true}}}
            if !status.isEmpty{Text(status).foregroundStyle(.secondary)}
        }.navigationTitle("Il tuo profilo").toolbar{
            ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}.disabled(saving)}
            ToolbarItem(placement:.confirmationAction){Button(saving ? "Salvo…":"Salva"){Task{await save()}}.disabled(saving)}
        }}.sheet(isPresented:$songPicker){NOVASwiftSongPicker(draft:$draft)}
        .onAppear{active=true;guard !initialized else{return};initialized=true;owner=store.archive?.owner ?? "";draft=store.archive?.active.object?["prof"]?.object ?? [:];token=store.archive?.active.object?["acct"]?.object?["token"]?.string ?? ""}
        .onDisappear{active=false;photoEpoch+=1}
        .onChange(of:photo){_,item in
            photoEpoch+=1;let expected=photoEpoch,expectedOwner=owner
            Task{guard let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data) else{return}
                guard active,expected==photoEpoch,expectedOwner==store.archive?.owner else{return}
                let side=min(image.size.width,image.size.height);let scale=256/side
                let jpeg=UIGraphicsImageRenderer(size:CGSize(width:256,height:256)).jpegData(withCompressionQuality:0.65){_ in image.draw(in:CGRect(x:-(image.size.width-side)*scale/2,y:-(image.size.height-side)*scale/2,width:image.size.width*scale,height:image.size.height*scale))}
                draft["avatar"] = .string("data:image/jpeg;base64,"+jpeg.base64EncodedString())
            }
        }
    }
    func save() async {
        guard active,!saving,owner==store.archive?.owner,(store.archive?.active.object?["acct"]?.object?["token"]?.string ?? "")==token else{status="Account cambiato. Chiudi e riapri il profilo.";return}
        let username=(draft["username"]?.string ?? "").trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard username.range(of:"^[a-z0-9_.]{3,20}$",options:.regularExpression) != nil else{status="Username: 3-20 caratteri, lettere minuscole, numeri, punto e trattino basso.";return}
        var profile=draft;profile["username"] = .string(username)
        guard (profile["study"]?.string?.count ?? 0)<=60,(profile["skills"]?.string?.count ?? 0)<=80,(profile["hobbies"]?.string?.count ?? 0)<=80 else{status="Accorcia i campi del profilo prima di salvare.";return}
        if !token.isEmpty {
            saving=true;defer{saving=false}
            let expected=NOVASession(store.archive!.active)!
            do{
                var body:[String:NOVAJSON]=[:]
                body["username"] = .string(username)
                for key in ["study","skills","hobbies","avatar"] { body[key] = profile[key] ?? .string("") }
                body["song"] = profile["song"] ?? .null
                body["badges"] = profile["badges"] ?? .array([])
                body["ntfy_topic"] = profile["ntfy"] ?? .string("")
                let result=try await NOVAAccountService(session:expected).request("profile",method:"PUT",body:.object(body))
                guard active,owner==store.archive?.owner,NOVASession(store.archive!.active)==expected else{return}
                guard result.object?["ok"]?.flag==true else{status="Profilo non confermato online. Bozza conservata.";return}
            }catch{status="Profilo non salvato online. Bozza conservata, riprova.";return}
        }
        do{try store.update(owner:owner){root in root["prof"] = .object(profile);root["profConfirmed"] = .string(username);root["profPending"] = .number(0)};dismiss()}catch{status="Profilo non salvato sul dispositivo. Bozza conservata."}
    }
}
@MainActor final class NOVASwiftSocial:ObservableObject {
    @Published private(set) var chats:[NOVAJSON]=[]
    @Published private(set) var messages:[NOVAJSON]=[]
    @Published private(set) var friends:[NOVAJSON]=[]
    @Published private(set) var reactions:[String:NOVAJSON]=[:]
    @Published private(set) var senders:[String:NOVAJSON]=[:]
    @Published private(set) var typing:[String]=[]
    @Published private(set) var status=""
    @Published private(set) var sending=false
    private var generation=0
    private var activeChat:String?
    private var session:NOVASession?
    typealias Transport=(NOVASession,String,String,NOVAJSON?,[URLQueryItem]) async throws -> NOVAJSON
    private let transport:Transport
    init(transport:Transport?=nil){let source:Transport=transport ?? {owner,path,method,body,query in try await NOVAAccountService(session:owner).request(path,method:method,body:body,query:query)};self.transport={owner,path,method,body,query in let result=try await source(owner,path,method,body,query);if result.object?["ok"]?.flag==false{throw NOVAServiceError.invalidResponse};return result}}
    func reset(){close();chats=[];friends=[];session=nil}
    func close(){generation+=1;activeChat=nil;messages=[];reactions=[:];senders=[:];typing=[];status="";sending=false}
    private func current(_ store:NOVASwiftStore,_ owner:NOVASession,_ epoch:Int,_ id:String?=nil)->Bool{generation==epoch && store.archive.flatMap({NOVASession($0.active)})==owner && (id==nil || activeChat==id)}
    func loadChats(_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{chats=[];status="Accedi al tuo account NOVA.";return}
        session=owner;let epoch=generation
        do{let result=try await transport(owner,"chats","GET",nil,[]);guard current(store,owner,epoch) else{return};chats=result.object?["chats"]?.array ?? [];status=""}catch{if current(store,owner,epoch){status="Elenco non aggiornato. Riprova."}}
    }
    func loadFriends(_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{return};let epoch=generation
        do{let result=try await transport(owner,"friends","GET",nil,[]);guard current(store,owner,epoch) else{return};friends=result.object?["friends"]?.array ?? []}catch{if current(store,owner,epoch){status="Amici non aggiornati."}}
    }
    func create(_ members:[String],name:String,exam:Date?,_ store:NOVASwiftStore) async -> String? {
        guard !members.isEmpty,let active=store.archive?.active,let owner=NOVASession(active) else{return nil};let epoch=generation
        let group=members.count>1;var body:[String:NOVAJSON]=["type":.string(group ? "group":"dm"),"members":.array(members.map{.string($0)})]
        if group{body["name"] = .string(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Gruppo":name);if let exam=exam{body["exam_at"] = .number(exam.timeIntervalSince1970*1000)}}
        do{let result=try await transport(owner,"chats","POST",.object(body),[]);guard current(store,owner,epoch),result.object?["ok"]?.flag==true,let id=result.object?["chat_id"] else{return nil};await loadChats(store);return id.string ?? String(id.integer)}catch{if current(store,owner,epoch){status="Chat non creata. Riprova."};return nil}
    }
    func open(_ id:String,_ store:NOVASwiftStore) async {close();activeChat=id;guard let active=store.archive?.active,let owner=NOVASession(active) else{return};session=owner;await refresh(store)}
    func refresh(_ store:NOVASwiftStore) async {
        guard let id=activeChat,let owner=session else{return};let epoch=generation
        do{
            let result=try await transport(owner,"chats/"+id+"/messages","GET",nil,messages.last?.object?["id"].map{[URLQueryItem(name:"since",value:$0.string ?? String($0.integer))]} ?? [URLQueryItem(name:"limit",value:"50")])
            guard current(store,owner,epoch,id) else{return}
            for message in result.object?["messages"]?.array ?? []{if let index=messages.firstIndex(where:{$0.object?["id"]==message.object?["id"]}){messages[index]=message}else{messages.append(message)}};if let updated=result.object?["reactions"]?.object{reactions=updated};if let updated=result.object?["senders"]?.object{senders.merge(updated){_,new in new}};status=""
            // Opening a visible conversation has the same receipt semantics as the existing app.
            if let last=messages.last?.object?["id"]{_ = try? await transport(owner,"chats/"+id+"/read","POST",.object(["last_msg_id":last]),[])}
            guard current(store,owner,epoch,id) else{return}
            let response=try await transport(owner,"chats/"+id+"/typing","GET",nil,[])
            guard current(store,owner,epoch,id) else{return};typing=(response.object?["typing"]?.array ?? []).compactMap(\.string).prefix(8).map{$0}
        }catch{if current(store,owner,epoch,id){typing=[];status="Messaggi non aggiornati. Riprova."}}
    }
    func send(_ text:String,_ store:NOVASwiftStore) async -> Bool {let value=text.trimmingCharacters(in:.whitespacesAndNewlines);guard !value.isEmpty else{return false};return await sendBody(.object(["body":.string(value)]),store)}
    func sendBody(_ body:NOVAJSON,_ store:NOVASwiftStore) async -> Bool {
        guard !sending,let id=activeChat,let owner=session,store.archive.flatMap({NOVASession($0.active)})==owner else{return false}
        let epoch=generation;sending=true;defer{if current(store,owner,epoch,id){sending=false}}
        do{_ = try await transport(owner,"chats/"+id+"/messages","POST",body,[]);guard current(store,owner,epoch,id) else{return false};await refresh(store);return true}catch{if current(store,owner,epoch,id){status="Messaggio non inviato. La bozza resta conservata."};return false}
    }
    func media(_ data:Data,mime:String,kind:String,_ store:NOVASwiftStore) async -> Bool {
        guard !sending,data.count>=500,data.count<=900000,["image/jpeg","audio/mp4"].contains(mime),let id=activeChat,let owner=session,store.archive.flatMap({NOVASession($0.active)})==owner else{return false}
        let epoch=generation;sending=true;defer{if current(store,owner,epoch,id){sending=false}}
        do{
            let result=try await transport(owner,"media","POST",.object(["data":.string(data.base64EncodedString()),"mime":.string(mime)]),[])
            guard current(store,owner,epoch,id),let key=result.object?["url"]?.string else{return false}
            _ = try await transport(owner,"chats/"+id+"/messages","POST",.object(["kind":.string(kind),"media_key":.string(key)]),[])
            guard current(store,owner,epoch,id) else{return false};await refresh(store);return true
        }catch{if current(store,owner,epoch,id){status="Allegato non inviato. Riprova."};return false}
    }
    func action(_ message:NOVAJSON,operation:String,value:String="",_ store:NOVASwiftStore) async {
        guard let id=activeChat,let owner=session,store.archive.flatMap({NOVASession($0.active)})==owner,let o=message.object,let messageID=o["id"],o["deleted"]?.flag != true,messages.contains(where:{$0.object?["id"]==messageID}) else{return}
        guard ["react","edit","delete"].contains(operation),operation=="react" || o["sender"]?.string==owner.email else{return}
        if operation=="edit" && o["kind"]?.string != "text"{return}
        let epoch=generation,key=messageID.string ?? String(messageID.integer)
        let body:NOVAJSON = operation=="react" ? .object(["emoji":.string(value)]):operation=="edit" ? .object(["body":.string(value)]):.object([:])
        do{_ = try await transport(owner,"messages/"+key+"/"+operation,"POST",body,[]);guard current(store,owner,epoch,id) else{return};await refresh(store)}catch{if current(store,owner,epoch,id){status="Modifica non confermata. Riprova."}}
    }
    func signalTyping(_ store:NOVASwiftStore) async {guard let id=activeChat,let owner=session,store.archive.flatMap({NOVASession($0.active)})==owner else{return};_ = try? await transport(owner,"chats/"+id+"/typing","POST",.object([:]),[])}
}
@MainActor struct NOVASwiftChatList:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var social=NOVASwiftSocial()
    @State private var create=false
    var body:some View {
        NavigationStack{List{
            NavigationLink("Assistente AI"){NOVASwiftAssistant(store:store)}
            ForEach(Array(social.chats.enumerated()),id:\.offset){_,chat in
                let o=chat.object ?? [:],id=o["id"].map{$0.string ?? String($0.integer)} ?? ""
                NavigationLink{NOVASwiftConversation(store:store,social:social,id:id,title:o["title"]?.string ?? "Chat")}label:{VStack(alignment:.leading){Text(o["title"]?.string ?? "Chat");if let last=o["last"]?.object{Text(last["body"]?.string ?? "Allegato").font(.caption).foregroundStyle(.secondary)};if let exam=o["exam_at"],exam.integer>0{Text(Date(timeIntervalSince1970:Double(exam.integer)/1000),style:.date).font(.caption).foregroundStyle(.secondary)}}}
            }
            if !social.status.isEmpty{Text(social.status).foregroundStyle(.secondary)}
        }.navigationTitle("Chat").toolbar{Button{create=true}label:{Image(systemName:"plus")}.accessibilityLabel("Nuova chat")}.sheet(isPresented:$create){NOVASwiftChatCreation(store:store,social:social)}.refreshable{await social.loadChats(store)}.task{await social.loadChats(store)}.onChange(of:store.archive?.owner){_,_ in social.reset();Task{await social.loadChats(store)}}}
    }
}
@MainActor struct NOVASwiftConversation:View {
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var social:NOVASwiftSocial
    let id:String
    let title:String
    @Environment(\.scenePhase) var phase
    @State private var draft=""
    @State private var photo:PhotosPickerItem?
    @State private var photoDraft:Data?
    @State private var mediaEpoch=0
    @State private var typingAt=Date.distantPast
    @State private var editMessage:NOVAJSON?
    @State private var editText=""
    @State private var editOpen=false
    @State private var deleteMessage:NOVAJSON?
    @State private var deleteOpen=false
    @StateObject private var voice=NOVASwiftVoice()
    @StateObject private var playback=NOVASwiftVoicePlayback()
    func mediaURL(_ key:String)->URL? {let url=key.hasPrefix("/") ? URL(string:"https://api.federicotaranu.site"+key):URL(string:key);return url?.scheme=="https" ? url:nil}
    var body:some View {
        VStack(spacing:0){
            ScrollView{LazyVStack(alignment:.leading,spacing:12){ForEach(Array(social.messages.enumerated()),id:\.offset){_,message in
                let o=message.object ?? [:],own=o["sender"]?.string==store.archive?.active.object?["acct"]?.object?["email"]?.string
                VStack(alignment:.leading,spacing:8){
                    if o["deleted"]?.flag==true{Text("Messaggio eliminato").italic().foregroundStyle(.secondary)}else{
                        if !own{Text(social.senders[o["sender"]?.string ?? ""]?.string ?? "Amico").font(.caption.bold())}
                        if let key=o["media_key"]?.string,let url=mediaURL(key){
                            if o["kind"]?.string=="image"{AsyncImage(url:url){image in image.resizable().scaledToFit()}placeholder:{ProgressView()}.frame(maxHeight:240)}
                            if o["kind"]?.string=="voice"{HStack{Button{playback.play(url)}label:{Label("Ascolta vocale",systemImage:"play.fill")};Button{playback.stop()}label:{Image(systemName:"stop.fill")}.accessibilityLabel("Ferma vocale")}}
                        }
                        if let text=o["body"]?.string,!text.isEmpty{Text(text).textSelection(.enabled)}
                        if o["edited"]?.flag==true{Text("modificato").font(.caption2).foregroundStyle(.secondary)}
                        let key=o["id"].map{$0.string ?? String($0.integer)} ?? ""
                        let reactions=social.reactions[key]?.array ?? []
                        if !reactions.isEmpty{Text(reactions.compactMap{$0.object?["emoji"]?.string}.joined(separator:" ")).font(.caption)}
                    }
                }.padding(12).frame(maxWidth:.infinity,alignment:own ? .trailing:.leading).background(own ? Color.blue.opacity(0.1):Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:18))
                .contextMenu{
                    if o["deleted"]?.flag != true{ForEach(["👍","❤️","😂","😮","🎉"],id:\.self){emoji in Button(emoji){Task{await social.action(message,operation:"react",value:emoji,store)}}}
                    if own{if o["kind"]?.string=="text"{Button("Modifica"){editMessage=message;editText=o["body"]?.string ?? "";editOpen=true}};Button("Elimina",role:.destructive){deleteMessage=message;deleteOpen=true}}}
                }
            }}.padding()}.refreshable{await social.refresh(store)}
            if !social.typing.isEmpty{Text(social.typing.joined(separator:", ")+(social.typing.count==1 ? " sta scrivendo…":" stanno scrivendo…")).font(.caption).foregroundStyle(.secondary)}
            if !social.status.isEmpty{Text(social.status).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)}
            if let data=photoDraft,let image=UIImage(data:data){HStack{Image(uiImage:image).resizable().scaledToFit().frame(height:90);Button("Invia foto"){Task{if await social.media(data,mime:"image/jpeg",kind:"image",store){photoDraft=nil}}}.disabled(social.sending);Button("Elimina",role:.destructive){photoDraft=nil}}.padding()}
            if let data=voice.draft{HStack{Text("Vocale in bozza");Button("Invia"){Task{if await social.media(data,mime:"audio/mp4",kind:"voice",store){voice.cancel()}}}.disabled(social.sending);Button("Elimina",role:.destructive){voice.cancel()}}.padding()}
            if !voice.status.isEmpty{Text(voice.status).font(.caption).foregroundStyle(.secondary)}
            HStack(alignment:.bottom){
                PhotosPicker(selection:$photo,matching:.images){Image(systemName:"photo")}.accessibilityLabel("Allega foto")
                Button{if voice.recording{voice.finish()}else{Task{await voice.start()}}}label:{Image(systemName:voice.recording ? "stop.circle.fill":"mic")}.accessibilityLabel(voice.recording ? "Ferma registrazione":"Registra vocale")
                TextField("Messaggio",text:$draft,axis:.vertical).lineLimit(1...6).textFieldStyle(.plain).onChange(of:draft){_,_ in if Date().timeIntervalSince(typingAt)>3{typingAt=Date();Task{await social.signalTyping(store)}}}
                Button{let text=draft;Task{if await social.send(text,store),draft==text{draft=""}}}label:{Image(systemName:"arrow.up")}.buttonStyle(.borderedProminent).disabled(social.sending||draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }.modifier(NOVASwiftComposerSurface()).padding(.horizontal,12).padding(.bottom,8)
        }.navigationTitle(title)
        .alert("Modifica messaggio",isPresented:$editOpen){TextField("Messaggio",text:$editText);Button("Salva"){if let message=editMessage{Task{await social.action(message,operation:"edit",value:editText,store)}}};Button("Annulla",role:.cancel){}}
        .confirmationDialog("Eliminare questo messaggio?",isPresented:$deleteOpen,titleVisibility:.visible){Button("Elimina",role:.destructive){if let message=deleteMessage{Task{await social.action(message,operation:"delete",store)}}};Button("Annulla",role:.cancel){}}
        .task{await social.open(id,store)}
        .task(id:phase){while !Task.isCancelled{try? await Task.sleep(for:.seconds(4));guard !Task.isCancelled else{return};if phase == .active{await social.refresh(store)}}}
        .onDisappear{mediaEpoch += 1;voice.cancel();playback.stop();social.close()}
        .onChange(of:store.archive?.owner){_,_ in mediaEpoch += 1;draft="";photoDraft=nil;voice.cancel();playback.stop();social.close()}
        .onChange(of:photo){_,item in mediaEpoch += 1;let epoch=mediaEpoch,owner=store.archive.flatMap{NOVASession($0.active)};Task{guard let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data) else{return};guard epoch==mediaEpoch,store.archive.flatMap({NOVASession($0.active)})==owner else{return};let scale=min(1,1200/max(image.size.width,image.size.height)),size=CGSize(width:image.size.width*scale,height:image.size.height*scale);photoDraft=UIGraphicsImageRenderer(size:size).jpegData(withCompressionQuality:0.7){_ in image.draw(in:CGRect(origin:.zero,size:size))}}}
    }
}
@MainActor struct NOVASwiftSettings:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var error=""
    @State private var profile=false
    @State private var login=false
    @State private var confirmAlways=false
    @State private var replayWelcome=false
    func text(_ key:String,_ fallback:String="")->Binding<String>{Binding(get:{store.archive?.active.object?[key]?.string ?? fallback},set:{value in do{try store.update(owner:store.archive?.owner ?? ""){$0[key] = .string(value)}}catch{self.error="Modifica non salvata"}})}
    func flag(_ key:String,_ fallback:Bool=false)->Binding<Bool>{Binding(get:{store.archive?.active.object?[key]?.flag ?? fallback},set:{value in do{try store.update(owner:store.archive?.owner ?? ""){$0[key] = .number(value ? 1:0)}}catch{self.error="Modifica non salvata"}})}
    func widget(_ key:String)->Binding<Bool>{Binding(get:{store.archive?.active.object?["w"]?.object?[key]?.flag ?? true},set:{value in do{try store.update(owner:store.archive?.owner ?? ""){root in var widgets=root["w"]?.object ?? [:];widgets[key] = .number(value ? 1:0);root["w"] = .object(widgets)}}catch{self.error="Modifica non salvata"}})}
    var body:some View {
        NavigationStack{Form{
            Section("Il tuo account"){
                NavigationLink("Amici, richieste e profili"){NOVASwiftPeopleView(store:store)}
                Button("Modifica profilo"){profile=true}
                NavigationLink("Gestisci account"){NOVASwiftAccountManagement(store:store)}
                NavigationLink("Backup account"){NOVASwiftBackup(store:store)}
                TextField("Il tuo nome",text:text("name"))
                if let email=store.archive?.active.object?["acct"]?.object?["email"]?.string{Text(email).foregroundStyle(.secondary)}
                Text("Accesso, uscita e confronto backup ancora in verifica. Nessuna sostituzione automatica dei dati.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Aspetto"){
                Picker("Tema",selection:text("theme","auto")){Text("Auto").tag("auto");Text("Chiaro").tag("light");Text("Scuro").tag("dark")}
                Toggle("Intro disattivata",isOn:flag("introOff"));Toggle("Intro a ogni avvio",isOn:flag("introEvery"));Button("Rivedi presentazione"){replayWelcome=true}
            }
            Section("Schermata Home"){
                Toggle("Meteo",isOn:widget("wx"));Toggle("Batteria",isOn:widget("bat"));Toggle("Calendario",isOn:widget("cal"));Toggle("Compiti",isOn:widget("task"));Toggle("Verifiche",isOn:widget("nx"));Toggle("Spotify",isOn:widget("sp"))
                NavigationLink("Modifica orario"){NOVASwiftTimetable(store:store)}
            }
            Section("Assistente AI"){
                NavigationLink("Collega ClasseViva, Groq e Spotify"){NOVASwiftServices(store:store)}
                Picker("Azioni",selection:Binding(get:{store.archive?.active.object?["aiAct"]?.string ?? "ask"},set:{value in if value=="always",store.archive?.active.object?["aiAct"]?.string != "always"{confirmAlways=true}else{do{try store.update(owner:store.archive?.owner ?? ""){$0["aiAct"] = .string(value)}}catch{self.error="Scelta non salvata."}}})){Text("Chiedi prima").tag("ask");Text("Sempre").tag("always");Text("Mai").tag("deny")}
                TextEditor(text:text("agentMd")).frame(minHeight:100)
                Text("Chiedi prima mostra la conferma per ogni azione. Sempre può aggiungere compiti e promemoria o aprire schermate senza chiedere; Mai disattiva le nuove azioni.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy"){
                NavigationLink("Blocco app e notifiche"){NOVASwiftDeviceSettings()}
                Toggle("Avvisi automatici compiti",isOn:Binding(get:{store.archive?.active.object?["hwn"]?.flag ?? true},set:{on in do{try store.update(owner:store.archive?.owner ?? ""){$0["hwn"] = .number(on ? 1:0)};UserDefaults.standard.set(on,forKey:"nova.hwn");if !on{Task{let center=UNUserNotificationCenter.current();let pending=await center.pendingNotificationRequests();center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter{$0.hasPrefix("hw.")||$0.hasPrefix("plan.")})}}}catch{error="Scelta non salvata."}}))
                NavigationLink("Notifiche sociali ntfy"){NOVASwiftSocialNotificationSettings(store:store)}
                Text("La migrazione non attiva la posizione, Fantasma, notifiche o accessi ai servizi. I permessi e i segreti esistenti restano invariati.")
            }
            if !error.isEmpty{Text(error).foregroundStyle(.red)}
        }.navigationTitle("Impostazioni").environment(\.locale,Locale(identifier:"it_IT"))}
        .confirmationDialog("Attivare Sempre? L’assistente potrà aggiungere compiti e promemoria e aprire schermate senza chiedere ogni volta.",isPresented:$confirmAlways,titleVisibility:.visible){Button("Attiva Sempre"){do{try store.update(owner:store.archive?.owner ?? ""){$0["aiAct"] = .string("always")}}catch{self.error="Scelta non salvata."}};Button("Annulla",role:.cancel){}}
        .sheet(isPresented:$profile){NOVASwiftProfileEditor(store:store)}
        .sheet(isPresented:$login){NavigationStack{NOVASwiftAccountLogin(store:store)}}
        .sheet(isPresented:$replayWelcome){NOVASwiftWelcome(store:store)}
    }
}
@MainActor struct NOVASwiftShell:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var sync=NOVASwiftSync()
    @State private var selectedTab=0
    @Environment(\.scenePhase) private var scenePhase
    var colorScheme:ColorScheme? {let theme=store.archive?.active.object?["theme"]?.string;return theme=="dark" ? .dark:theme=="light" ? .light:nil}
    var body:some View {
        Group{switch selectedTab{case 1:NOVASwiftGrades(store:store);case 2:NOVASwiftChatList(store:store);case 3:NOVASwiftMap(store:store);case 4:NOVASwiftProfile(store:store);default:NOVASwiftDashboard(store:store)}}
        .safeAreaInset(edge:.bottom){NOVASwiftNavigation(selected:$selectedTab,avatar:store.archive?.active.object?["prof"]?.object?["avatar"]?.string ?? "").frame(maxWidth:420).frame(height:58).padding(.horizontal,18).padding(.bottom,8)}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("NOVASwiftOpenPage"))){notice in guard notice.userInfo?["owner"] as? String==store.archive?.owner,let page=notice.userInfo?["page"] as? String,let tab=["home":0,"voti":1,"chat":2,"profilo":4][page] else{return};selectedTab=tab}.preferredColorScheme(colorScheme).environment(\.locale,Locale(identifier:"it_IT")).onAppear{sync.bind(store);NOVASwiftBackgroundLocation.shared.bind(store);NOVASwiftSchoolLifecycle.bind(store);Task{_ = await NOVASwiftSchoolLifecycle.refresh()}}.onChange(of:scenePhase){_,phase in if phase == .active{Task{_ = await NOVASwiftSchoolLifecycle.refresh()}}else if phase == .background{BGHandler.schedule()}}.onDisappear{sync.stop();NOVASwiftBackgroundLocation.shared.unbind()}
    }
}

// Explicit account transactions preserve the complete prior state and account cache.
extension NOVASwiftStore {
    func changeAccount(email:String,token:String) throws {
        guard var current=archive,!email.isEmpty,!token.isEmpty else{throw CocoaError(.userCancelled)}
        let target=email.lowercased(),oldOwner=current.owner
        let encoder=JSONEncoder();encoder.outputFormatting = [.sortedKeys]
        let old=try encoder.encode(current.active)
        current.localStorage["nova.swift.account."+oldOwner] = String(data:old,encoding:.utf8)
        current.localStorage["nova.swift.recovery."+UUID().uuidString] = String(data:old,encoding:.utf8)
        var next:[String:NOVAJSON]
        if target==oldOwner {next=current.active.object ?? [:]}
        else if let saved=current.localStorage["nova.swift.account."+target],let bytes=saved.data(using:.utf8),let state=try? JSONDecoder().decode(NOVAJSON.self,from:bytes).object {next=state}
        else if let saved=current.localStorage["nova.account.v3."+target],let bytes=saved.data(using:.utf8),let envelope=try? JSONDecoder().decode(NOVAJSON.self,from:bytes),let data=envelope.object?["data"],data.object != nil {next=data.object!;next["cv"] = .object(["on":.number(0)]);next["profConfirmed"] = .string("");next["profPending"] = .number(1)}
        else {next=["name":.string(""),"theme":.string("auto"),"sb":.string("off"),"tasks":.array([]),"chat":.array([]),"gr":.array([]),"tt":.object(["lessons":.array([])]),"prof":.object([:]),"w":.object([:]),"done":.number(0),"ob":.number(0),"aiAct":.string("ask")]}
        next["acct"] = .object(["email":.string(target),"token":.string(token)])
        next["locShare"] = .number(0);next["bgLoc"] = .number(0);next["locSession"] = .string("");next["locSessionToken"] = .string("")
        current.active = .object(next)
        let data=try encoder.encode(current),url=directory.appendingPathComponent("state-v1.json")
        try data.write(to:url,options:[.atomic,.completeFileProtection])
        let verified=try JSONDecoder().decode(NOVASwiftArchive.self,from:Data(contentsOf:url))
        guard verified.active==current.active,verified.localStorage==current.localStorage else{throw CocoaError(.fileWriteUnknown)}
        archive=verified
    }
}

extension NOVASwiftStore {
    func logoutConfirmed(session:NOVASession,snapshot:NOVAJSON) throws {
        guard var current=archive,NOVASession(current.active)==session,NOVASwiftBackupData.snapshot(current.active)==snapshot else{throw CocoaError(.userCancelled)}
        let bytes=try JSONEncoder().encode(current.active),saved=String(data:bytes,encoding:.utf8)!
        current.localStorage["nova.swift.account."+current.owner]=saved
        current.localStorage["nova.swift.recovery."+UUID().uuidString]=saved
        current.active = .object(["name":.string(""),"theme":.string("auto"),"sb":.string("off"),"tasks":.array([]),"chat":.array([]),"gr":.array([]),"prof":.object([:]),"tt":.object(["lessons":.array([])]),"w":.object([:]),"locShare":.number(0),"bgLoc":.number(0),"locSession":.string("")])
        let url=directory.appendingPathComponent("state-v1.json");try JSONEncoder().encode(current).write(to:url,options:[.atomic,.completeFileProtection])
        let verified=try JSONDecoder().decode(NOVASwiftArchive.self,from:Data(contentsOf:url));guard verified.active==current.active,verified.localStorage==current.localStorage else{throw CocoaError(.fileWriteUnknown)};archive=verified
    }
}
