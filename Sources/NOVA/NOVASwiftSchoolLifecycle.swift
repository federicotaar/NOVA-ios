import SwiftUI
import UserNotifications

@MainActor enum NOVASwiftSchoolLifecycle {
    private static weak var live:NOVASwiftStore?
    private static var refreshing=false
    private static var last=Date.distantPast
    static func bind(_ store:NOVASwiftStore){live=store}
    static func refresh(background:Bool=false) async -> Bool {
        guard !refreshing else{return false}
        let store=live ?? NOVASwiftStore()
        guard let archive=store.archive,archive.active.object?["cv"]?.object?["on"]?.flag==true,
              let credentials=CredStore.read() else{return false}
        let linkedOwner=UserDefaults.standard.string(forKey:"nova.swift.school.owner")
        guard linkedOwner==nil || linkedOwner==archive.owner else{return false}
        if !background,Date().timeIntervalSince(last)<900{return true}
        let owner=archive.owner,session=NOVASession(archive.active),snapshot=archive.active
        refreshing=true;defer{refreshing=false}
        let raw=await ClasseViva.loginFlow(uid:credentials.uid,pass:credentials.pass,ident:UserDefaults.standard.string(forKey:"nova.swift.school.ident"),save:false,background:background,sideEffects:false)
        guard !Task.isCancelled,store.archive?.owner==owner,store.archive.flatMap({NOVASession($0.active)})==session,
              store.archive?.active==snapshot,let result=NOVASwiftServicesModel.json(raw),result.object?["ok"]?.flag==true else{return false}
        // Legacy links carry no owner key: adopt it only when the student name matches the stored link, never attaching another account's credentials.
        if linkedOwner==nil{
            let storedName=archive.active.object?["cv"]?.object?["name"]?.string ?? ""
            let freshName=result.object?["name"]?.string ?? ""
            guard storedName.isEmpty || storedName==freshName else{return false}
            UserDefaults.standard.set(owner,forKey:"nova.swift.school.owner")
        }
        do{try NOVASwiftSchoolImport.apply(result,store,owner:owner);last=Date();let synced=await NOVASwiftTaskSync.apply(store);guard store.archive?.owner==owner,store.archive.flatMap({NOVASession($0.active)})==session else{return false}
            UserDefaults.standard.set(store.archive?.active.object?["hwn"]?.flag ?? true,forKey:"nova.hwn")
            if let events=raw["events"] as? [[String:Any]]{await HomeNotifs.process(events,background:background,valid:{store.archive?.owner==owner && store.archive.flatMap({NOVASession($0.active)})==session && store.archive?.active.object?["hwn"]?.flag != false})}
            return synced
        }catch{return false}
    }
}
