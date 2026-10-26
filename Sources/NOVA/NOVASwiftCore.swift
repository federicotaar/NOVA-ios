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
            guard !loaded else{return}; loaded=true; owner=store.archive?.owner ?? ""
            lessons=(store.archive?.active.object?["tt"]?.object?["lessons"]?.array ?? []).map(NOVALessonDraft.init)
        }
    }
    func time(_ value: Binding<Int>) -> Binding<Date> {
        Binding(get:{Calendar.current.startOfDay(for:Date()).addingTimeInterval(Double(value.wrappedValue*60))},set:{date in let c=Calendar.current.dateComponents([.hour,.minute],from:date);value.wrappedValue=(c.hour ?? 0)*60+(c.minute ?? 0)})
    }
    func save() {
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
        let owner=archive.owner
        let tasks=archive.active.object?["tasks"]?.array ?? []
        let homework=tasks.compactMap{task -> NOVAJSON? in
            let o=task.object ?? [:]
            guard o["done"]?.flag != true,o["kind"]?.string != "test",let due=o["due"]?.string else{return nil}
            return .object(["t":o["title"] ?? .string(""),"s":o["subj"] ?? .string(""),"d":.string(String(due.prefix(10)))])
        }
        if let data=try? JSONEncoder().encode(NOVAJSON.object(["v":.number(1),"items":.array(homework)])),let json=String(data:data,encoding:.utf8){_ = TT.saveHomework(json)}
        let center=UNUserNotificationCenter.current()
        let settings=await center.notificationSettings()
        guard store.archive?.owner==owner else{return false}
        guard [.authorized,.provisional,.ephemeral].contains(settings.authorizationStatus) else{return false}
        // Remove first and await the read, avoiding the previous scheduling race.
        let pending=await center.pendingNotificationRequests()
        guard store.archive?.owner==owner else{return false}
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
            guard store.archive?.owner==owner else{return false}
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
                            if !((o["acts"]?.array ?? []).isEmpty){Text("Azioni conservate. Esecuzione ancora da verificare nella versione Swift.").font(.caption).foregroundStyle(.secondary)}
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(o["r"]?.string=="user" ? Color.blue.opacity(0.1):Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:20)).id(index)
                    }
                }.padding()}.onChange(of:messages.count){_,_ in if !messages.isEmpty{proxy.scrollTo(messages.count-1,anchor:.bottom)}}}
                if !status.isEmpty{Text(status).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)}
                HStack(alignment:.bottom){
                    TextField("Scrivi un messaggio",text:$draft,axis:.vertical).lineLimit(1...6).textFieldStyle(.roundedBorder)
                    Button{send()}label:{Image(systemName:sending ? "hourglass":"arrow.up").font(.headline).frame(width:36,height:36)}.buttonStyle(.borderedProminent).buttonBorderShape(.circle).disabled(sending || draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }.padding()
            }.navigationTitle("Assistente")
        }.onAppear{owner=store.archive?.owner ?? ""}.onDisappear{generation+=1}
    }
    func send(){
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,!sending,owner==store.archive?.owner else{return}
        guard Secret.get("groq") != nil else{status="Prima salva la tua chiave Groq nelle impostazioni.";return}
        let snapshot=store.archive!.active.object ?? [:]
        do{try store.update(owner:owner){root in var chat=root["chat"]?.array ?? [];chat.append(.object(["r":.string("user"),"c":.string(text)]));root["chat"] = .array(Array(chat.suffix(40)))}}catch{status="Messaggio non salvato. Riprova.";return}
        draft="";sending=true;generation+=1;let expected=generation,expectedOwner=owner
        let permission=snapshot["aiAct"]?.string ?? "ask"
        let system="Sei NOVA, assistente di studio. Rispondi in italiano in modo concreto. Non dichiarare di aver modificato dati, programmato notifiche o eseguito azioni: questa anteprima non esegue azioni. Permesso azioni salvato: "+permission+". Nome: "+(snapshot["name"]?.string ?? "")
        let history=messages.suffix(12).map{message -> [String:String] in let o=message.object ?? [:];return["role":o["r"]?.string=="user" ? "user":"assistant","content":o["c"]?.string ?? ""]}
        Task{
            let response=await Groq.handle(["op":"chat","messages":[["role":"system","content":system]]+history])
            guard expected==generation,expectedOwner==store.archive?.owner else{return};sending=false
            let answer=(response["ok"] as? Int)==1 ? (response["text"] as? String ?? ""):"Richiesta non completata. Controlla connessione e chiave Groq."
            do{try store.update(owner:expectedOwner){root in var chat=root["chat"]?.array ?? [];chat.append(.object(["r":.string("assistant"),"c":.string(answer)]));root["chat"] = .array(Array(chat.suffix(40)))}}catch{status="Risposta ricevuta ma non salvata: "+answer}
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
    @State private var photoEpoch=0
    @State private var active=false
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
            if let song=draft["song"]?.object{Section("La tua canzone"){Text(song["t"]?.string ?? "");Text(song["a"]?.string ?? "").foregroundStyle(.secondary);Text("La ricerca e la selezione sono ancora da collegare nella versione Swift.").font(.footnote)}}
            if !status.isEmpty{Text(status).foregroundStyle(.secondary)}
        }.navigationTitle("Il tuo profilo").toolbar{
            ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}.disabled(saving)}
            ToolbarItem(placement:.confirmationAction){Button(saving ? "Salvo…":"Salva"){Task{await save()}}.disabled(saving)}
        }}.onAppear{guard !active else{return};active=true;owner=store.archive?.owner ?? "";draft=store.archive?.active.object?["prof"]?.object ?? [:];token=store.archive?.active.object?["acct"]?.object?["token"]?.string ?? ""}
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
        guard active,!saving,owner==store.archive?.owner else{return}
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
    @Published private(set) var status=""
    @Published private(set) var sending=false
    private var generation=0
    private var activeChat:String?
    private var session:NOVASession?
    func close(){generation+=1;activeChat=nil;messages=[];status="";sending=false}
    func loadChats(_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{status="Accedi al tuo account NOVA.";return}
        session=owner;generation+=1;let epoch=generation
        do{let result=try await NOVAAccountService(session:owner).chats();guard epoch==generation,NOVASession(store.archive!.active)==owner else{return};chats=result.object?["chats"]?.array ?? [];status=""}catch{if epoch==generation{status="Elenco non aggiornato. Riprova."}}
    }
    func open(_ id:String,_ store:NOVASwiftStore) async {
        close();activeChat=id
        guard let active=store.archive?.active,let owner=NOVASession(active) else{return};session=owner
        await refresh(store)
    }
    func refresh(_ store:NOVASwiftStore) async {
        guard let id=activeChat,let owner=session else{return};let epoch=generation
        do{
            let result=try await NOVAAccountService(session:owner).request("chats/"+id+"/messages",query:[URLQueryItem(name:"limit",value:"50")])
            guard epoch==generation,activeChat==id,NOVASession(store.archive!.active)==owner else{return}
            messages=result.object?["messages"]?.array ?? [];status=""
        }catch{if epoch==generation{status="Messaggi non aggiornati. Riprova."}}
    }
    func send(_ text:String,_ store:NOVASwiftStore) async -> Bool {
        let text=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !sending,!text.isEmpty,let id=activeChat,let owner=session,NOVASession(store.archive!.active)==owner else{return false}
        let epoch=generation;sending=true;defer{if epoch==generation{sending=false}}
        do{
            _ = try await NOVAAccountService(session:owner).request("chats/"+id+"/messages",method:"POST",body:.object(["body":.string(text)]))
            guard epoch==generation,activeChat==id,NOVASession(store.archive!.active)==owner else{return false}
            await refresh(store);return true
        }catch{if epoch==generation{status="Messaggio non inviato. Il testo resta nella bozza."};return false}
    }
}
@MainActor struct NOVASwiftChatList:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var social=NOVASwiftSocial()
    var body:some View {
        NavigationStack{List{
            NavigationLink("Assistente AI"){NOVASwiftAssistant(store:store)}
            ForEach(Array(social.chats.enumerated()),id:\.offset){_,chat in
                let o=chat.object ?? [:],id=o["id"].flatMap{value -> String? in value.string ?? String(value.integer)} ?? ""
                NavigationLink{NOVASwiftConversation(store:store,social:social,id:id,title:o["title"]?.string ?? "Chat")}label:{VStack(alignment:.leading){Text(o["title"]?.string ?? "Chat");if let last=o["last"]?.object{Text(last["body"]?.string ?? "Allegato").font(.caption).foregroundStyle(.secondary)}}}
            }
            if !social.status.isEmpty{Text(social.status).foregroundStyle(.secondary)}
            Text("Creazione chat, gruppi, allegati, reazioni e ricevute restano da verificare. Nessuna ricevuta viene inviata da questa anteprima.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Chat").refreshable{await social.loadChats(store)}.task{await social.loadChats(store)}}
    }
}
@MainActor struct NOVASwiftConversation:View {
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var social:NOVASwiftSocial
    let id:String
    let title:String
    @State private var draft=""
    var body:some View {
        VStack{
            ScrollView{LazyVStack(alignment:.leading,spacing:12){ForEach(Array(social.messages.enumerated()),id:\.offset){_,message in
                let o=message.object ?? [:]
                VStack(alignment:.leading){Text(o["kind"]?.string=="text" || o["kind"]==nil ? (o["body"]?.string ?? ""):(o["kind"]?.string=="image" ? "Foto allegata":"Messaggio vocale")).textSelection(.enabled)}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Color.secondary.opacity(0.1),in:RoundedRectangle(cornerRadius:18))
            }}.padding()}.refreshable{await social.refresh(store)}
            if !social.status.isEmpty{Text(social.status).font(.footnote).foregroundStyle(.secondary)}
            HStack{TextField("Messaggio",text:$draft,axis:.vertical).textFieldStyle(.roundedBorder);Button{let text=draft;Task{if await social.send(text,store),draft==text{draft=""}}}label:{Image(systemName:"arrow.up")}.buttonStyle(.borderedProminent).disabled(social.sending||draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}.padding()
        }.navigationTitle(title).task{await social.open(id,store)}.onDisappear{social.close()}
    }
}
@MainActor struct NOVASwiftSettings:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var error=""
    @State private var profile=false
    func text(_ key:String,_ fallback:String="")->Binding<String>{Binding(get:{store.archive?.active.object?[key]?.string ?? fallback},set:{value in do{try store.update(owner:store.archive?.owner ?? ""){$0[key] = .string(value)}}catch{self.error="Modifica non salvata"}})}
    func flag(_ key:String,_ fallback:Bool=false)->Binding<Bool>{Binding(get:{store.archive?.active.object?[key]?.flag ?? fallback},set:{value in do{try store.update(owner:store.archive?.owner ?? ""){$0[key] = .number(value ? 1:0)}}catch{self.error="Modifica non salvata"}})}
    func widget(_ key:String)->Binding<Bool>{Binding(get:{store.archive?.active.object?["w"]?.object?[key]?.flag ?? true},set:{value in do{try store.update(owner:store.archive?.owner ?? ""){root in var widgets=root["w"]?.object ?? [:];widgets[key] = .number(value ? 1:0);root["w"] = .object(widgets)}}catch{self.error="Modifica non salvata"}})}
    var body:some View {
        NavigationStack{Form{
            Section("Il tuo account"){
                Button("Modifica profilo"){profile=true}
                TextField("Il tuo nome",text:text("name"))
                if let email=store.archive?.active.object?["acct"]?.object?["email"]?.string{Text(email).foregroundStyle(.secondary)}
                Text("Accesso, uscita e confronto backup ancora in verifica. Nessuna sostituzione automatica dei dati.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Aspetto"){
                Picker("Tema",selection:text("theme","auto")){Text("Auto").tag("auto");Text("Chiaro").tag("light");Text("Scuro").tag("dark")}
                Toggle("Intro disattivata",isOn:flag("introOff"))
            }
            Section("Schermata Home"){
                Toggle("Meteo",isOn:widget("wx"));Toggle("Batteria",isOn:widget("bat"));Toggle("Calendario",isOn:widget("cal"));Toggle("Compiti",isOn:widget("task"));Toggle("Verifiche",isOn:widget("nx"));Toggle("Spotify",isOn:widget("sp"))
                NavigationLink("Modifica orario"){NOVASwiftTimetable(store:store)}
            }
            Section("Assistente AI"){
                Picker("Azioni",selection:text("aiAct","ask")){Text("Chiedi prima").tag("ask");Text("Sempre").tag("always");Text("Mai").tag("deny")}
                TextEditor(text:text("agentMd")).frame(minHeight:100)
                Text("La scelta viene conservata, ma l'esecuzione delle azioni non è ancora attiva in questa anteprima Swift.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy"){
                Text("La migrazione non attiva la posizione, Fantasma, notifiche o accessi ai servizi. I permessi e i segreti esistenti restano invariati.")
            }
            if !error.isEmpty{Text(error).foregroundStyle(.red)}
        }.navigationTitle("Impostazioni").environment(\.locale,Locale(identifier:"it_IT"))}
        .sheet(isPresented:$profile){NOVASwiftProfileEditor(store:store)}
    }
}
@MainActor struct NOVASwiftShell:View {
    @ObservedObject var store:NOVASwiftStore
    var colorScheme:ColorScheme? {let theme=store.archive?.active.object?["theme"]?.string;return theme=="dark" ? .dark:theme=="light" ? .light:nil}
    var body:some View {
        TabView {
            NOVASwiftOverview(store:store).tabItem{Label("Home",systemImage:"house")}
            NOVASwiftChatList(store:store).tabItem{Label("Chat",systemImage:"bubble.left.and.bubble.right")}
            NOVASwiftSettings(store:store).tabItem{Label("Profilo",systemImage:"person.crop.circle")}
        }.preferredColorScheme(colorScheme).environment(\.locale,Locale(identifier:"it_IT"))
    }
}
