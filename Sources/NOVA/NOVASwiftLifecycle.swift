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
    var body:some View {Form{Section("Blocco app"){Toggle("Face ID o codice iOS",isOn:Binding(get:{lock.enabled},set:{value in Task{await lock.set(value)}}));if !lock.status.isEmpty{Text(lock.status).font(.footnote)}};Section("Notifiche"){Button("Consenti notifiche"){Task{do{let accepted=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge]);notificationStatus=accepted ? "Notifiche autorizzate. iOS gestisce la consegna.":"Notifiche non autorizzate. Puoi cambiarle nelle impostazioni di iOS."}catch{notificationStatus="Permesso notifiche non verificato."}}};Text(notificationStatus).font(.footnote).foregroundStyle(.secondary);Text("I promemoria richiedono una conferma iOS. Le notifiche sociali ntfy non sono APNs e richiedono ancora verifica nella versione Swift.").font(.footnote).foregroundStyle(.secondary)}}.navigationTitle("Privacy e notifiche").onDisappear{lock.invalidate()}}
}
@MainActor struct NOVASwiftWelcome:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var step=0
    @State private var name=""
    @State private var status=""
    private let titles=["Benvenuto in NOVA","La tua giornata","Persone e privacy","Scegli i tuoi servizi"]
    private let descriptions=["Compiti, voti, studio e amici in un unico posto.","Organizza i compiti, consulta il calendario e personalizza la Home. Puoi aggiungere l'orario dalle impostazioni.","La posizione non viene condivisa da questa presentazione. Scegli tu quando aggiungere amici, condividere la posizione o attivare le notifiche.","ClasseViva, Groq e Spotify sono facoltativi. Puoi configurarli dopo nelle impostazioni. Le chiavi e le password restano nel Portachiavi di questo iPhone."]
    var body:some View{NavigationStack{VStack(alignment:.leading,spacing:24){Text("NOVA").font(.system(size:48,weight:.black,design:.rounded));Spacer();Text(titles[step]).font(.largeTitle.bold());Text(descriptions[step]).font(.title3).foregroundStyle(.secondary);if step==0{TextField("Come ti chiami?",text:$name).textFieldStyle(.roundedBorder)};if !status.isEmpty{Text(status).foregroundStyle(.red)};Spacer();HStack{if step>0{Button("Indietro"){step-=1}};Spacer();Text("\(step+1) / \(titles.count)").foregroundStyle(.secondary);Button(step==titles.count-1 ? "Inizia":"Continua"){if step<titles.count-1{step+=1}else{finish()}}.buttonStyle(.borderedProminent)}}.padding(24).toolbar{Button("Configura dopo"){finish()}}}.onAppear{name=store.archive?.active.object?["name"]?.string ?? ""}}
    func finish(){do{try store.update(owner:store.archive?.owner ?? ""){root in if !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{root["name"] = .string(String(name.prefix(80)))};root["done"] = .number(1);root["ob"] = .number(2);root["profDone"] = .number(1)};dismiss()}catch{status="Impostazioni non salvate. Riprova."}}
}
@MainActor struct NOVASwiftProtectedRoot:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.scenePhase) var phase
    @StateObject private var lock=NOVASwiftDeviceLock()
    @State private var intro=true
    var body:some View{ZStack{
        if store.archive?.active.object?["done"]?.flag==true{NOVASwiftShell(store:store)}else{NOVASwiftWelcome(store:store)}
        if intro,store.archive?.active.object?["introOff"]?.flag != true{ZStack{Color.black.ignoresSafeArea();Text("N").font(.system(size:96,weight:.black,design:.rounded)).foregroundStyle(.white)}.transition(.opacity).allowsHitTesting(true)}
        if lock.locked{ZStack{Color.black.ignoresSafeArea();VStack(spacing:20){Image(systemName:"lock.fill").font(.largeTitle);Text("NOVA è bloccata").font(.title.bold());Button("Sblocca con Face ID o codice"){Task{await lock.unlock()}}.buttonStyle(.borderedProminent);if !lock.status.isEmpty{Text(lock.status).font(.footnote)}}.foregroundStyle(.white).padding()}.zIndex(10)}
    }.task{lock.cover();if lock.locked{await lock.unlock()};try? await Task.sleep(for:.milliseconds(900));withAnimation(.easeOut(duration:0.3)){intro=false}}
    .onChange(of:phase){_,value in if value == .active{Task{await lock.unlock()}}else{lock.invalidate();lock.cover()}}
    }
}
