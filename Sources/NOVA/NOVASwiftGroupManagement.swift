import SwiftUI

@MainActor final class NOVASwiftGroupManagement:ObservableObject {
    @Published private(set) var info:NOVAJSON?
    @Published private(set) var busy=false
    @Published private(set) var status=""
    @Published private(set) var invite=""
    private var generation=0
    private let transport:NOVASwiftSocial.Transport
    init(transport:NOVASwiftSocial.Transport?=nil){self.transport=transport ?? {owner,path,method,body,query in try await NOVAAccountService(session:owner).request(path,method:method,body:body,query:query)}}
    func invalidate(){generation+=1;info=nil;invite="";busy=false;status=""}
    func load(_ id:String,_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{return};let epoch=generation
        do{let result=try await transport(owner,"chats/"+id+"/group","GET",nil,[]);guard generation==epoch,store.archive.flatMap({NOVASession($0.active)})==owner else{return};guard result.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse};info=result;status=""}catch{if generation==epoch,store.archive.flatMap({NOVASession($0.active)})==owner{status="Informazioni gruppo non aggiornate. Riprova."}}
    }
    @discardableResult func change(_ id:String,_ operation:String,_ body:[String:NOVAJSON],_ store:NOVASwiftStore) async -> Bool {
        guard !busy,let active=store.archive?.active,let owner=NOVASession(active) else{return false};let epoch=generation;busy=true
        defer{if generation==epoch{busy=false}}
        do{let result=try await transport(owner,"chats/"+id+"/group/"+operation,operation=="settings" ? "PUT":"POST",.object(body),[]);guard generation==epoch,store.archive.flatMap({NOVASession($0.active)})==owner else{return false};guard result.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse};await load(id,store);if result.object?["pending"]?.flag==true{status="Richiesta inviata agli amministratori."};return true}catch{if generation==epoch,store.archive.flatMap({NOVASession($0.active)})==owner{if case NOVAServiceError.http(403,let reason)=error,reason=="cannot share history outside your access"{status="Non puoi condividere la cronologia che non puoi vedere. Scegli solo nuovi messaggi oppure chiedi a un amministratore con accesso alla cronologia completa."}else if case NOVAServiceError.http(409,_)=error{status="Il gruppo è cambiato. Ricarica prima di confermare di nuovo."}else{status="Modifica non confermata. Ricarica e riprova."}};return false}
    }
    var role:String{info?.object?["role"]?.string ?? ""}
    var isAdmin:Bool{["owner","admin"].contains(role)}
    func allowed(_ key:String)->Bool{info?.object?["settings"]?.object != nil && (isAdmin || info?.object?["settings"]?.object?[key]?.string=="all")}
}

@MainActor struct NOVASwiftGroupInfo:View {
    let id:String
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var social:NOVASwiftSocial
    @StateObject private var group:NOVASwiftGroupManagement
    @Environment(\.dismiss) private var dismiss
    @State private var add=false
    @State private var settings=false
    @State private var section="Membri"
    init(id:String,store:NOVASwiftStore,social:NOVASwiftSocial,group:NOVASwiftGroupManagement?=nil){self.id=id;self.store=store;self.social=social;_group=StateObject(wrappedValue:group ?? NOVASwiftGroupManagement())}
    var body:some View {
        NavigationStack{List{
            Section{VStack(spacing:12){Image(systemName:"person.3.fill").font(.system(size:46)).frame(width:100,height:100).background(.quaternary,in:Circle());Text(group.info?.object?["title"]?.string ?? "Gruppo").font(.title.bold());Text("Gruppo · \(group.info?.object?["members"]?.array.count ?? 0) membri").foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(.vertical)}
            Section{HStack{Button("Membri"){section="Membri"}.buttonStyle(.bordered);Spacer();Button("Impostazioni"){settings=true}.buttonStyle(.bordered).accessibilityIdentifier("swiftGroupSettings")}}
            Section("Membri"){
                if group.allowed("add_members"){Button{add=true}label:{Label("Aggiungi membri",systemImage:"person.badge.plus")}.accessibilityIdentifier("swiftGroupAddMembers")}
                ForEach(Array((group.info?.object?["members"]?.array ?? []).enumerated()),id:\.offset){_,member in
                    HStack{Label(member.object?["username"]?.string ?? "Membro",systemImage:"person.crop.circle.fill");if member.object?["is_self"]?.flag==true{Text("Tu").foregroundStyle(.secondary)};Spacer();if ["admin","owner"].contains(member.object?["role"]?.string ?? ""){Text(member.object?["role"]?.string=="owner" ? "Creatore":"Amministratore").font(.caption).foregroundStyle(.secondary)}}
                }
            }
            if !group.status.isEmpty{Section{Text(group.status).font(.footnote).foregroundStyle(.secondary);Button("Riprova"){Task{await group.load(id,store)}}}}
        }.navigationTitle("Info gruppo").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Chiudi"){dismiss()}}}.sheet(isPresented:$add){NOVASwiftGroupAddMembers(id:id,store:store,social:social,group:group)}.navigationDestination(isPresented:$settings){NOVASwiftGroupSettings(id:id,store:store,group:group)}.task{await group.load(id,store)}.refreshable{await group.load(id,store)}.onChange(of:store.archive?.owner){_,_ in group.invalidate();dismiss()}.onDisappear{if !settings && !add{group.invalidate()}}}
    }
}

@MainActor struct NOVASwiftGroupAddMembers:View {
    let id:String
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var social:NOVASwiftSocial
    @ObservedObject var group:NOVASwiftGroupManagement
    @Environment(\.dismiss) private var dismiss
    @State private var candidate=""
    @State private var confirm=false
    @State private var history=""
    @State private var confirmAdd=false
    var members:Set<String>{Set((group.info?.object?["members"]?.array ?? []).compactMap{$0.object?["username"]?.string?.lowercased()})}
    var body:some View{NavigationStack{List{
        Section("Amici non ancora nel gruppo"){
            ForEach(Array(social.friends.enumerated()),id:\.offset){_,friend in let username=friend.object?["username"]?.string ?? "";if !members.contains(username.lowercased()){Button("@"+username){candidate=username;history="";confirm=true}.disabled(group.busy || !group.allowed("add_members"))}}
        }
        if !group.status.isEmpty{Text(group.status).font(.footnote).foregroundStyle(.secondary)}
    }.navigationTitle("Aggiungi membri").toolbar{ToolbarItem(placement:.cancellationAction){Button("Chiudi"){dismiss()}}}.confirmationDialog("Aggiungere @"+candidate+"?",isPresented:$confirm,titleVisibility:.visible){Button("Condividi tutta la cronologia"){history="all";confirmAdd=true};Button("Solo nuovi messaggi"){history="from_join";confirmAdd=true};Button("Annulla",role:.cancel){}}message:{Text("Scegli se condividere con @"+candidate+" anche i messaggi e gli allegati precedenti. Nessuna cronologia viene condivisa prima della tua scelta.")}.alert("Aggiungere @"+candidate+"?",isPresented:$confirmAdd){Button("Aggiungi"){guard ["all","from_join"].contains(history) else{return};Task{if await group.change(id,"members",["username":.string(candidate),"history":.string(history)],store){await social.loadChats(store)}}};Button("Annulla",role:.cancel){history=""}}message:{Text(history=="all" ? "Condividerai anche tutti i messaggi e gli allegati precedenti.":"Vedrà solo i messaggi e gli allegati dal suo ingresso.")}.task{await social.loadFriends(store)}}}
}

@MainActor struct NOVASwiftGroupSettings:View {
    let id:String
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var group:NOVASwiftGroupManagement
    @State private var values:[String:String]=[:]
    @State private var approval=""
    @State private var revision=0
    @State private var confirmSave=false
    @State private var adminCandidate=""
    @State private var adminRole=""
    @State private var confirmAdmin=false
    private let keys=["add_members","send_messages","edit_settings"]
    var editable:Bool{group.isAdmin || group.allowed("edit_settings")}
    var valid:Bool{keys.allSatisfy{["admins","all"].contains(values[$0] ?? "")} && ["yes","no"].contains(approval)}
    func selection(_ key:String)->Binding<String>{Binding(get:{values[key] ?? ""},set:{values[key]=$0})}
    func permissions(_ title:String,_ key:String)->some View{Picker(title,selection:selection(key)){Text("Scegli").tag("");Text("Solo amministratori").tag("admins");Text("Tutti").tag("all")}.disabled(!editable||group.busy)}
    func loadDraft(){values=group.info?.object?["settings"]?.object?.compactMapValues(\.string) ?? [:];approval=group.info?.object?["settings"]?.object?["approval"].map{$0.flag ? "yes":"no"} ?? "";revision=group.info?.object?["revision"]?.integer ?? 0}
    var body:some View{Form{
        if group.info?.object?["configuration_required"]?.flag==true{Section{Text("Il creatore deve scegliere le autorizzazioni prima di aggiungere membri. Nessuna impostazione e stata applicata automaticamente.").font(.footnote)}}
        Section("Iscrizione al gruppo"){permissions("Aggiungi nuovi membri","add_members");Picker("Approvazione amministratore",selection:$approval){Text("Scegli").tag("");Text("Si").tag("yes");Text("No").tag("no")}.disabled(!editable||group.busy)}
        Section("Messaggi"){permissions("Invia nuovi messaggi","send_messages");Text("La cronologia viene scelta ogni volta che aggiungi un membro, inclusi messaggi e allegati precedenti.").font(.footnote).foregroundStyle(.secondary)}
        Section{permissions("Modifica impostazioni","edit_settings");Button("Salva autorizzazioni"){confirmSave=true}.disabled(!editable || !valid || group.busy).accessibilityIdentifier("swiftGroupSaveSettings")}
        Section("Amministratori"){
            ForEach(Array((group.info?.object?["members"]?.array ?? []).enumerated()),id:\.offset){_,member in let username=member.object?["username"]?.string ?? "",role=member.object?["role"]?.string ?? "member";HStack{Text("@"+username);Spacer();if role=="owner"{Text("Creatore").foregroundStyle(.secondary)}else if group.role=="owner"{Button(role=="admin" ? "Rimuovi admin":"Rendi admin"){adminCandidate=username;adminRole=role=="admin" ? "member":"admin";confirmAdmin=true}.disabled(group.busy)}else if role=="admin"{Text("Amministratore").foregroundStyle(.secondary)}}}
            Text("Solo il creatore puo nominare o rimuovere amministratori.").font(.footnote).foregroundStyle(.secondary)
        }
        if group.isAdmin{Section("Richieste in attesa"){ForEach(Array((group.info?.object?["requests"]?.array ?? []).enumerated()),id:\.offset){_,request in HStack{VStack(alignment:.leading){Text("@"+(request.object?["username"]?.string ?? "Membro"));Text(request.object?["history"]?.string=="all" ? "Tutta la cronologia e gli allegati":"Solo messaggi e allegati nuovi").font(.caption).foregroundStyle(.secondary)};Spacer();Button("Accetta"){Task{await group.change(id,"requests",["id":request.object?["id"] ?? .null,"approve":.bool(true)],store)}};Button("Rifiuta",role:.destructive){Task{await group.change(id,"requests",["id":request.object?["id"] ?? .null,"approve":.bool(false)],store)}}}.disabled(group.busy)}}}
        if !group.status.isEmpty{Section{Text(group.status).font(.footnote).foregroundStyle(.secondary);Button("Ricarica"){Task{await group.load(id,store);loadDraft()}}}}
    }.navigationTitle("Autorizzazioni gruppo").navigationBarTitleDisplayMode(.inline).onAppear{loadDraft()}.confirmationDialog("Salvare le autorizzazioni del gruppo?",isPresented:$confirmSave,titleVisibility:.visible){Button("Salva"){var body=values.filter{keys.contains($0.key)}.mapValues{NOVAJSON.string($0)};body["approval"] = .bool(approval=="yes");Task{if await group.change(id,"settings",["settings":.object(body),"revision":.number(Double(revision))],store){loadDraft()}}};Button("Annulla",role:.cancel){}}message:{Text("Le nuove regole saranno applicate dal server a tutti i membri. La cronologia viene scelta separatamente per ogni nuovo membro.")}.confirmationDialog(adminRole=="admin" ? "Rendere @"+adminCandidate+" amministratore?":"Rimuovere il ruolo amministratore da @"+adminCandidate+"?",isPresented:$confirmAdmin,titleVisibility:.visible){Button("Conferma"){Task{await group.change(id,"admins",["username":.string(adminCandidate),"role":.string(adminRole)],store)}};Button("Annulla",role:.cancel){}}}
}
