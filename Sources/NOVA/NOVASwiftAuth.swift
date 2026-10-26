import SwiftUI
import CoreLocation
import UserNotifications

struct NOVASwiftAuthService {
    func request(_ path:String,_ body:NOVAJSON) async throws -> NOVAJSON {
        var request=URLRequest(url:URL(string:"https://api.federicotaranu.site")!.appendingPathComponent(path))
        request.httpMethod="POST";request.timeoutInterval=25;request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try JSONEncoder().encode(body)
        let(data,response)=try await URLSession.shared.data(for:request)
        let value=try JSONDecoder().decode(NOVAJSON.self,from:data)
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else{throw NOVAServiceError.invalidResponse};return value
    }
}
@MainActor struct NOVASwiftAccountLogin:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var email=""
    @State private var code=""
    @State private var password=""
    @State private var stage="email"
    @State private var busy=false
    @State private var status=""
    @State private var generation=0
    @State private var startingSession:NOVASession?
    @State private var startingOwner=""
    @State private var startingSnapshot:NOVAJSON?
    var body:some View {
        Form {
            Section("Account NOVA"){
                if stage=="email"{TextField("Email",text:$email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.emailAddress)}else{Text(email);Button("Cambia email"){generation += 1;stage="email";code="";password="";status="";busy=false}}
                if stage=="loginCode" || stage=="newCode"{TextField("Codice di 6 cifre",text:$code).keyboardType(.numberPad).textContentType(.oneTimeCode);Text("Il codice vale 10 minuti. Controlla anche la posta indesiderata.").font(.footnote).foregroundStyle(.secondary)}
                if stage=="password" || stage=="newCode"{SecureField(stage=="newCode" ? "Crea password (minimo 8 caratteri)":"Password",text:$password).textContentType(stage=="newCode" ? .newPassword:.password)}
                Button(stage=="email" ? "Continua":stage=="newCode" ? "Crea account":"Accedi"){submit()}.disabled(busy)
                if stage=="loginCode"{Button("Uso la password"){stage="password";code="";status=""}.disabled(busy)}
                if stage=="password"{Button("Mandami un codice"){stage="email";password="";submit()}.disabled(busy)}
                if !status.isEmpty{Text(status).font(.footnote).foregroundStyle(.secondary)}
            }
            Section {Text("Prima di cambiare account la copia completa di questo telefono viene conservata. La copia online non viene scelta automaticamente. Nessuna amicizia, posizione o autorizzazione viene attivata durante l'accesso.").font(.footnote).foregroundStyle(.secondary)}
        }.navigationTitle("Accedi a NOVA").disabled(busy)
        .onAppear{startingSession=store.archive.flatMap{NOVASession($0.active)};startingOwner=store.archive?.owner ?? "";startingSnapshot=store.archive.map{NOVASwiftBackupData.snapshot($0.active)}}
        .onDisappear{generation += 1;password="";code=""}
    }
    func submit(){
        let address=email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard address.range(of:"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$",options:.regularExpression) != nil else{status="Email non valida.";return}
        guard store.archive?.owner==startingOwner,store.archive.flatMap({NOVASession($0.active)})==startingSession else{status="Account cambiato. Chiudi e riapri l'accesso.";return}
        if stage=="loginCode" || stage=="newCode"{guard code.count==6,code.allSatisfy(\.isNumber) else{status="Il codice è di 6 cifre.";return}}
        if stage=="newCode" && password.count<8{status="La password deve avere almeno 8 caratteri.";return}
        email=address;busy=true;generation += 1;let expected=generation,step=stage,enteredCode=code,enteredPassword=password
        Task {
            do {
                let service=NOVASwiftAuthService()
                if step=="email" {
                    let value=try await service.request("auth/request-code",.object(["email":.string(address),"mode":.string("login")]))
                    guard expected==generation else{return}
                    if value.object?["sent"]?.flag==true{stage="loginCode";status="Codice inviato."}else{
                        _ = try await service.request("auth/request-code",.object(["email":.string(address)]))
                        guard expected==generation else{return};stage="newCode";status="Nessun account con questa email. Verifica il codice e scegli una password per crearne uno."
                    }
                }else{
                    let path=step=="loginCode" ? "auth/login-code":step=="password" ? "auth/login":"auth/verify"
                    var body:[String:NOVAJSON]=["email":.string(address)]
                    if step != "password"{body["code"] = .string(enteredCode)}
                    if step != "loginCode"{body["password"] = .string(enteredPassword)}
                    let response=try await service.request(path,.object(body))
                    guard expected==generation,store.archive?.owner==startingOwner,store.archive.flatMap({NOVASession($0.active)})==startingSession else{return}
                    guard let token=response.object?["token"]?.string,!token.isEmpty else{throw NOVAServiceError.invalidResponse}
                    guard store.archive.map({NOVASwiftBackupData.snapshot($0.active)})==startingSnapshot else{throw CocoaError(.userCancelled)}
                    try store.changeAccount(email:address,token:token)
                    let defaults=UserDefaults.standard;defaults.set(false,forKey:"nova.bgLoc.on");defaults.removeObject(forKey:"nova.bgLoc.session");defaults.removeObject(forKey:"nova.bgLoc.token");defaults.set(false,forKey:"nova.bgLoc.sharing")
                    CLLocationManager().stopMonitoringSignificantLocationChanges()
                    let center=UNUserNotificationCenter.current();let pending=await center.pendingNotificationRequests();guard store.archive.flatMap({NOVASession($0.active)})==NOVASession(.object(["acct":.object(["email":.string(address),"token":.string(token)])])) else{return};center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter{$0.hasPrefix("rem.")})
                    password="";code="";dismiss()
                }
            }catch{if expected==generation{status="Accesso non completato. Controlla codice, password e connessione. La copia locale resta conservata."}}
            if expected==generation{busy=false}
        }
    }
}
