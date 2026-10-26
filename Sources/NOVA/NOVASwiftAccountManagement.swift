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
            Text("Prima di uscire o cambiare account il backup della copia attuale deve essere confermato. Se le copie sono diverse, scegli in Confronta le copie. Le cache locali restano conservate. La condivisione viene spenta prima di aprire il cambio account, anche se poi annulli.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Gestisci account")
        .confirmationDialog("Uscire da questo account?",isPresented:$confirmation,titleVisibility:.visible){Button("Esci",role:.destructive){logout()};Button("Annulla",role:.cancel){}}
        .sheet(isPresented:$login){NavigationStack{NOVASwiftAccountLogin(store:store)}}
        .onAppear{sync.bind(store)}.onDisappear{sync.stop()}
    }
    func prepareSwitch(){
        guard !busy else{return}
        if store.archive.flatMap({NOVASession($0.active)})==nil{login=true;return}
        busy=true;Task{await sync.flush(store);guard sync.canLeave(store),let session=store.archive.flatMap({NOVASession($0.active)}) else{status="Cambio account fermato: backup non confermato. Confronta o verifica le copie.";busy=false;return};do{try await NOVASwiftAccountPrivacy.prepare(store,session:session);guard sync.canLeave(store) else{throw CocoaError(.userCancelled)};login=true}catch{status="Cambio fermato: condivisione sul server non confermata spenta. I dati restano sul telefono."};busy=false}
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
                try await NOVASwiftAccountPrivacy.prepare(store,session:owner)
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

// Leave the old account invisible before removing or replacing its credentials.
@MainActor enum NOVASwiftAccountPrivacy {
    typealias Stop=(NOVASession) async throws -> NOVAJSON
    static func prepare(_ store:NOVASwiftStore,session:NOVASession,stop:Stop?=nil) async throws {
        guard store.archive.flatMap({NOVASession($0.active)})==session,let owner=store.archive?.owner else{throw CocoaError(.userCancelled)}
        NOVASwiftBackgroundLocation.shared.stop(clear:false)
        try store.update(owner:owner){root in root["locShare"] = .number(0);root["bgLoc"] = .number(0);root["locSession"] = .string("");root["locSessionToken"] = .string("")}
        let result:NOVAJSON
        if let stop=stop{result=try await stop(session)}else{result=try await NOVAAccountService(session:session).request("location",method:"PUT",body:.object(["sharing":.bool(false)]))}
        guard result.object?["ok"]?.flag==true,store.archive.flatMap({NOVASession($0.active)})==session else{throw NOVAServiceError.invalidResponse}
    }
}
