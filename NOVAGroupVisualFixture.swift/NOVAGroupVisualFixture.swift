@MainActor func visualSwiftGroupReady(_ web:WKWebView,_ attempt:Int){
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
 Task{@MainActor in
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("group-info-synthetic"));try? store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"owner@test.invalid\",\"token\":\"synthetic-only\"}}"])
 let settings:NOVAJSON = .object(["add_members":.string("admins"),"send_messages":.string("all"),"edit_settings":.string("admins"),"approval":.bool(false)])
 let info:NOVAJSON = .object(["ok":.bool(true),"title":.string("Gruppo demo"),"role":.string("owner"),"settings":settings,"revision":.number(1),"members":.array([.object(["username":.string("nova.demo"),"role":.string("owner"),"is_self":.bool(true)]),.object(["username":.string("amico.demo"),"role":.string("member")])]),"requests":.array([])])
 let group=NOVASwiftGroupManagement{_,_,_,_,_ in info}
 let social=NOVASwiftSocial{_,path,_,_,_ in if path=="friends"{return .object(["ok":.bool(true),"friends":.array([.object(["username":.string("nuovo.demo")])])])};return .object(["ok":.bool(true),"chats":.array([])])}
 let page=UIHostingController(rootView:NOVASwiftGroupInfo(id:"synthetic",store:store,social:social,group:group).preferredColorScheme(.dark));page.modalPresentationStyle = .fullScreen
 guard let root=web.window?.rootViewController else{return};root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
 }
}
