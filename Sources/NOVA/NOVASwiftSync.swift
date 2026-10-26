import SwiftUI
import Combine

// Automatic upload starts only from a verified matching baseline, never from a conflict.
@MainActor final class NOVASwiftSync:ObservableObject {
    @Published private(set) var status="Backup automatico non ancora verificato."
    @Published private(set) var conflict=false
    @Published private(set) var confirmed:NOVAJSON?
    private var session:NOVASession?
    private var revision:NOVAJSON = .null
    private var baseline:NOVAJSON?
    private var generation=0
    private var subscription:AnyCancellable?
    private var work:Task<Void,Never>?
    private var inFlight=false
    typealias Request = (NOVASession,String,NOVAJSON?) async throws -> NOVAJSON
    private let request:Request
    init(request:Request?=nil){self.request=request ?? {session,method,body in try await NOVAAccountService(session:session).request("account-data",method:method,body:body)}}
    func bind(_ store:NOVASwiftStore){
        stop()
        subscription=store.$archive.dropFirst().sink{[weak self,weak store] _ in Task{@MainActor in guard let self=self,let store=store else{return};self.changed(store)}}
        work=Task{await inspect(store)}
    }
    func stop(){generation += 1;work?.cancel();work=nil;subscription=nil;session=nil;baseline=nil;confirmed=nil;revision = .null;conflict=false;inFlight=false}
    func changed(_ store:NOVASwiftStore){
        let active=store.archive.flatMap{NOVASession($0.active)}
        if active != session{generation += 1;work?.cancel();baseline=nil;confirmed=nil;conflict=false;inFlight=false;session=nil;work=Task{await inspect(store)};return}
        guard baseline != nil,!conflict,!inFlight else{return}
        work?.cancel();work=Task{try? await Task.sleep(for:.milliseconds(1800));guard !Task.isCancelled else{return};await flush(store)}
    }
    func inspect(_ store:NOVASwiftStore) async {
        guard let active=store.archive?.active,let owner=NOVASession(active) else{status="Nessun account collegato.";return}
        generation += 1;let epoch=generation;session=owner;baseline=nil;confirmed=nil;conflict=false;status="Verifica backup online…"
        do{
            let result=try await request(owner,"GET",nil)
            guard epoch==generation,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            let local=NOVASwiftBackupData.snapshot(store.archive!.active)
            let cloud=result.object?["data"]
            revision=result.object?["rev"] ?? .null
            guard cloud==local else{conflict=true;status=cloud==nil || cloud == .null ? "Primo backup: scegli Salva copia in Backup account.":"Copie diverse: scegli quale tenere in Backup account.";return}
            baseline=local;confirmed=local;status="Backup online verificato."
        }catch{if epoch==generation{status="Backup non verificato. Dati locali conservati."}}
    }
    func flush(_ store:NOVASwiftStore) async {
        guard !inFlight,!conflict,let original=baseline,let owner=session,
              let active=store.archive?.active,NOVASession(active)==owner else{return}
        let snapshot=NOVASwiftBackupData.snapshot(active)
        guard snapshot != original else{return}
        let epoch=generation;inFlight=true;status="Salvataggio account…"
        do {
            let result=try await request(owner,"PUT",.object(["rev":revision,"data":snapshot]))
            guard epoch==generation,store.archive.flatMap({NOVASession($0.active)})==owner else{return}
            revision=result.object?["rev"] ?? .null;baseline=snapshot;confirmed=snapshot;inFlight=false;status="Backup online confermato."
            if NOVASwiftBackupData.snapshot(store.archive!.active) != snapshot{changed(store)}
        }catch NOVAServiceError.http(let code,_) where code==409{if epoch==generation{inFlight=false;conflict=true;baseline=nil;confirmed=nil;status="Backup cambiato su un altro dispositivo. Confronta le copie."}}
        catch{if epoch==generation{inFlight=false;confirmed=nil;status="Non salvato online. Riprova prima di uscire."}}
    }
    func canLeave(_ store:NOVASwiftStore)->Bool {
        guard !inFlight,!conflict,let active=store.archive?.active,let owner=session,NOVASession(active)==owner else{return false}
        return confirmed==NOVASwiftBackupData.snapshot(active)
    }
}
