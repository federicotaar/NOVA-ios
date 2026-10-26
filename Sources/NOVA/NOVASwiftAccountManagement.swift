import SwiftUI
import CoreLocation
import UserNotifications

@MainActor struct NOVASwiftAccountManagement:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var sync=NOVASwiftSync()
    @State private var login=false
    @State private var busy=false
    @State private var status=""
    @State private var confirmation=false
    var body:some View {
        Form {
            Section("Account NOVA") {
                Text(store.archive?.active.object?["acct"]?.object?["email"]?.string ?? "Nessun account collegato")
                Text(sync.status).font(.footnote).foregroundStyle(.secondary)
                Button("Verifica e salva backup"){Task{await sync.inspect(store);await sync.flush(store)}}.disabled(busy)
                NavigationLink("Confronta le copie"){NOVASwiftBackup(store:store)}
                Button("Accedi o cambia account"){prepareSwitch()}.disabled(busy)
                if store.archive.flatMap({NOVASession($0.active)}) != nil{Button("Esci",role:.destructive){confirmation=true}.disabled(busy)}
                if !status.isEmpty{Text(status).font(.footnote).foregroundStyle(.secondary)}
            }
            Text("Prima di uscire o cambiare account il backup della copia attuale deve essere confermato. Se le copie sono diverse, scegli in Confronta le copie. Le cache locali restano conservate.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Gestisci account")
        .confirmationDialog("Uscire da questo account?",isPresented:$confirmation,titleVisibility:.visible){Button("Esci",role:.destructive){logout()};Button("Annulla",role:.cancel){}}
        .sheet(isPresented:$login){NavigationStack{NOVASwiftAccountLogin(store:store)}}
        .onAppear{sync.bind(store)}.onDisappear{sync.stop()}
    }
    func prepareSwitch(){
        guard !busy else{return}
        if store.archive.flatMap({NOVASession($0.active)})==nil{login=true;return}
        busy=true;Task{await sync.flush(store);guard sync.canLeave(store) else{status="Cambio account fermato: backup non confermato. Confronta o verifica le copie.";busy=false;return};login=true;busy=false}
    }
    func logout(){
        guard !busy,let active=store.archive?.active,let owner=NOVASession(active) else{return}
        busy=true
        Task {
            await sync.flush(store)
            guard sync.canLeave(store),store.archive.flatMap({NOVASession($0.active)})==owner else{status="Uscita fermata: backup online non confermato.";busy=false;return}
            let snapshot=NOVASwiftBackupData.snapshot(store.archive!.active)
            do {
                // Server visibility must be confirmed off before token removal.
                _ = try await NOVAAccountService(session:owner).request("location",method:"PUT",body:.object(["sharing":.bool(false)]))
                guard sync.canLeave(store),store.archive.flatMap({NOVASession($0.active)})==owner else{busy=false;return}
                try store.logoutConfirmed(session:owner,snapshot:snapshot)
                let defaults=UserDefaults.standard;defaults.set(false,forKey:"nova.bgLoc.on");defaults.removeObject(forKey:"nova.bgLoc.session");defaults.removeObject(forKey:"nova.bgLoc.token");defaults.set(false,forKey:"nova.bgLoc.sharing")
                CLLocationManager().stopMonitoringSignificantLocationChanges()
                let center=UNUserNotificationCenter.current(),pending=await UNUserNotificationCenter.current().pendingNotificationRequests()
                guard store.archive?.owner=="local" else{busy=false;return}
                center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter{$0.hasPrefix("rem.")})
                status="Uscita completata. Copia locale conservata."
            }catch{status="Uscita non completata. Account e dati restano sul telefono."}
            busy=false
        }
    }
}
