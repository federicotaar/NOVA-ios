import SwiftUI
import LocalAuthentication
import UserNotifications

@MainActor final class NOVASwiftDeviceLock:ObservableObject {
    @Published private(set) var locked=false
    @Published private(set) var status=""
    private var context:LAContext?
    private var generation=0
    var enabled:Bool{UserDefaults.standard.bool(forKey:"nova.faceid")}
    func cover(){if enabled{locked=true}}
    func unlock() async {guard enabled else{locked=false;return};generation+=1;let expected=generation;let context=LAContext();self.context=context;var error:NSError?;guard context.canEvaluatePolicy(.deviceOwnerAuthentication,error:&error) else{locked=false;status="Blocco non disponibile: configura Face ID o codice nelle impostazioni di iOS.";return};do{let ok=try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Sblocca NOVA");guard expected==generation else{return};locked = !ok;status=ok ? "":"Sblocco non completato."}catch{if expected==generation{status="Sblocco non completato. Riprova."}}}
    func set(_ on:Bool) async {generation+=1;let expected=generation;let context=LAContext();self.context=context;var error:NSError?;guard context.canEvaluatePolicy(.deviceOwnerAuthentication,error:&error) else{status="Configura prima Face ID o il codice di iOS.";return};do{let ok=try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:on ? "Attiva il blocco di NOVA":"Disattiva il blocco di NOVA");guard expected==generation,ok else{return};UserDefaults.standard.set(on,forKey:"nova.faceid");locked=false;status=on ? "Blocco attivato.":"Blocco disattivato."}catch{if expected==generation{status="Scelta non modificata."}}}
    func invalidate(){generation+=1;context?.invalidate();context=nil}
}
@MainActor struct NOVASwiftDeviceSettings:View {
    @StateObject private var lock=NOVASwiftDeviceLock()
    @State private var notificationStatus=""
    var body:some View {Form{Section("Blocco app"){Toggle("Face ID o codice iOS",isOn:Binding(get:{lock.enabled},set:{value in Task{await lock.set(value)}}));if !lock.status.isEmpty{Text(lock.status).font(.footnote)}};Section("Notifiche"){Button("Consenti notifiche"){Task{do{let accepted=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge]);notificationStatus=accepted ? "Notifiche autorizzate. iOS gestisce la consegna.":"Notifiche non autorizzate. Puoi cambiarle nelle impostazioni di iOS."}catch{notificationStatus="Permesso notifiche non verificato."}}};if !notificationStatus.isEmpty{Text(notificationStatus).font(.footnote).foregroundStyle(.secondary)};Text("I promemoria richiedono una conferma iOS. Le notifiche sociali ntfy non sono APNs e richiedono ancora verifica nella versione Swift.").font(.footnote).foregroundStyle(.secondary)}}.navigationTitle("Privacy e notifiche").onDisappear{lock.invalidate()}}
}
@MainActor struct NOVASwiftWelcome:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var step=0
    init(store:NOVASwiftStore,initialStep:Int=0){self.store=store;_step=State(initialValue:max(0,min(15,initialStep)))}
    @State private var name=""
    @State private var status=""
    @State private var owner=""
    private let titles=["Inserisci la tua email","Ciao, come ti chiamo?","Scegli il tuo username","Su di te","La tua canzone","Che tema preferisci?","Cosa vuoi vedere?","Collega il registro","Vuoi gli avvisi?","Chiave API di Groq","Il tuo orario","Il Client ID di Spotify","Connetti il tuo account","Intro a ogni avvio?","Blocchi NOVA con Face ID?","Tutto pronto"]
    private let descriptions=["Accedi per ritrovare la configurazione. Puoi anche saltare. Le password dei servizi restano sul telefono.","Uso il nome per salutarti nell'app e nelle risposte dell'assistente.","Gli amici ti trovano con lo username. Il salvataggio del profilo controlla la disponibilita online.","Scegli dove studi, i tuoi punti forti e una foto. Le modifiche al profilo richiedono Salva.","Cerca gratis una canzone e scegli l'anteprima per il tuo profilo.","Auto segue l'impostazione chiaro/scuro del tuo iPhone.","La Home mostra solo le schede che scegli. Puoi cambiare dopo.","Importa compiti, verifiche e voti. Password solo nel Portachiavi, richieste solo a ClasseViva.","I promemoria locali richiedono il permesso di iOS. Gli aggiornamenti in background non sono immediati.","Groq ha un piano gratuito. La chiave resta nel Portachiavi ed e usata solo verso api.groq.com.","Aggiungi o importa una foto, controlla le lezioni e salva. L'orario alimenta i widget.","Crea un'app su developer.spotify.com/dashboard, abilita Web API e usa nova://spotify-callback come Redirect URI. Per i controlli serve Premium.","Autorizza il collegamento sulla pagina ufficiale Spotify. Il collegamento resta sul telefono.","La sequenza cinematografica puo apparire solo la prima volta o a ogni avvio.","Facoltativo: NOVA chiede Face ID o il codice prima di mostrare i dati. L'attivazione richiede la verifica iOS.","Puoi cambiare ogni scelta dalle impostazioni. Nessun permesso o servizio viene attivato semplicemente continuando."]
    func value(_ key:String,_ fallback:String="")->Binding<String>{Binding(get:{store.archive?.active.object?[key]?.string ?? fallback},set:{new in save{$0[key] = .string(new)}})}
    func flag(_ key:String)->Binding<Bool>{Binding(get:{store.archive?.active.object?[key]?.flag==true},set:{on in save{root in root[key] = .number(on ? 1:0);if key=="introEvery",on{root["introOff"] = .number(0)}}})}
    var body:some View{NavigationStack{VStack(spacing:0){ProgressView(value:Double(step+1),total:Double(titles.count)).padding(.horizontal);Form{
        Section{Text("\(step+1) di \(titles.count)").font(.footnote).foregroundStyle(.secondary);Text(titles[step]).font(.title.bold());Text(descriptions[step]).foregroundStyle(.secondary)}
        Section{switch step{
        case 0:NavigationLink("Accedi o crea account"){NOVASwiftAccountLogin(store:store)}
        case 1:TextField("Il tuo nome",text:value("name")).textContentType(.givenName)
        case 2,3,4:NavigationLink(step==4 ? "Scegli canzone nel profilo":"Apri editor profilo"){NOVASwiftProfileEditor(store:store)}
        case 5:Picker("Tema",selection:value("theme","auto")){Text("Auto").tag("auto");Text("Chiaro").tag("light");Text("Scuro").tag("dark")}
        case 6:ForEach(["wx","bat","cal","task","nx","sp"],id:\.self){key in Toggle(["wx":"Meteo","bat":"Batteria","cal":"Calendario","task":"Compiti","nx":"Verifiche","sp":"Spotify"][key]!,isOn:Binding(get:{store.archive?.active.object?["w"]?.object?[key]?.flag ?? true},set:{on in save{root in var widgets=root["w"]?.object ?? [:];widgets[key] = .number(on ? 1:0);root["w"] = .object(widgets)}}))}
        case 7,9,11,12:NavigationLink("Configura servizi"){NOVASwiftServices(store:store)}
        case 8,14:NavigationLink("Privacy, blocco e notifiche"){NOVASwiftDeviceSettings()}
        case 10:NavigationLink("Imposta l'orario"){NOVASwiftTimetable(store:store)}
        case 13:Toggle("A ogni avvio",isOn:flag("introEvery"));Toggle("Disattiva intro",isOn:flag("introOff"))
        default:Button("Apri NOVA"){finish()}.buttonStyle(.borderedProminent)
        }}
        if !status.isEmpty{Text(status).foregroundStyle(.red)}
    };HStack{Button("Indietro"){step=max(0,step-1)}.disabled(step==0);Spacer();Button(step==titles.count-1 ? "Inizia":"Avanti / Salta"){if step<titles.count-1{step+=1}else{finish()}}.buttonStyle(.borderedProminent)}.padding()}.navigationTitle("NOVA").toolbar{Button("Configura dopo"){finish()}}}.onAppear{if owner.isEmpty{owner=store.archive?.owner ?? ""}}.onChange(of:store.archive?.owner){_,new in owner=new ?? "";status=""}}
    func save(_ edit:(inout [String:NOVAJSON])->Void){do{try store.update(owner:owner,edit)}catch{status="Impostazioni non salvate. Riprova."}}
    func finish(){guard !owner.isEmpty else{return};save{root in root["done"] = .number(1);root["ob"] = .number(2);root["profDone"] = .number(1)};if status.isEmpty{dismiss()}}
}
@MainActor struct NOVASwiftProtectedRoot:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.scenePhase) var phase
    @StateObject private var lock=NOVASwiftDeviceLock()
    @State private var intro=false
    var body:some View{ZStack{
        if store.archive?.active.object?["done"]?.flag==true{NOVASwiftShell(store:store)}else{NOVASwiftWelcome(store:store)}
        if intro{NOVASwiftCinematicIntro{endIntro()}.transition(.opacity).allowsHitTesting(true)}
        if lock.locked{ZStack{Color.black.ignoresSafeArea();VStack(spacing:20){Image(systemName:"lock.fill").font(.largeTitle);Text("NOVA è bloccata").font(.title.bold());Button("Sblocca con Face ID o codice"){Task{await lock.unlock()}}.buttonStyle(.borderedProminent);if !lock.status.isEmpty{Text(lock.status).font(.footnote)}}.foregroundStyle(.white).padding()}.zIndex(10)}
    }.task{lock.cover();if lock.locked{await lock.unlock()};let root=store.archive?.active.object ?? [:];intro=root["introOff"]?.flag != true && (root["introEvery"]?.flag==true || (root["introSeen"]?.flag != true && root["done"]?.flag != true))}
    .onChange(of:phase){_,value in if value == .active{Task{await lock.unlock()};if store.archive?.active.object?["introEvery"]?.flag==true,store.archive?.active.object?["introOff"]?.flag != true{intro=true}}else{endIntro();lock.invalidate();lock.cover()}}
    }
    private func endIntro(){intro=false;if let owner=store.archive?.owner{try? store.update(owner:owner){$0["introSeen"] = .number(1)}}}

}
