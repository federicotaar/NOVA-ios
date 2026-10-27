import SwiftUI

// Foreground-only, no APNs claim. The server's authenticated membership list is authoritative.
@MainActor final class NOVASwiftGroupAlerts:ObservableObject {
    @Published private(set) var notice=false
    private var owner:NOVASession?
    private var newest:[String:Int]=[:]
    private var seeded=false
    private var generation=0
    private let transport:NOVASwiftSocial.Transport
    init(transport:NOVASwiftSocial.Transport?=nil){self.transport=transport ?? {owner,path,method,body,query in try await NOVAAccountService(session:owner).request(path,method:method,body:body,query:query)}}
    func reset(){generation+=1;owner=nil;newest=[:];seeded=false;notice=false}
    func dismiss(){notice=false}
    func check(_ store:NOVASwiftStore) async {
        guard let session=store.archive.flatMap({NOVASession($0.active)}) else{reset();return}
        if owner != session{reset();owner=session}
        let expected=generation
        guard let result=try? await transport(session,"chats","GET",nil,[]),result.object?["ok"]?.flag==true,let chats=result.object?["chats"]?.array,expected==generation,owner==session,store.archive.flatMap({NOVASession($0.active)})==session else{return}
        var next:[String:Int]=[:],incoming=false
        for chat in chats{
            guard let c=chat.object,c["type"]?.string=="group",let id=c["id"]?.string,let last=c["last"]?.object else{continue}
            let messageID=last["id"]?.integer ?? 0
            next[id]=messageID
            if seeded,let old=newest[id],messageID>old,(c["unread"]?.integer ?? 0)>0,last["sender"]?.string != session.email{incoming=true}
        }
        newest=next;seeded=true
        if incoming{notice=true}
    }
}
