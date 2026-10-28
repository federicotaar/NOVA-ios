@MainActor func visualSwiftGroupReady(_ web:WKWebView,_ attempt:Int){
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
 Task{@MainActor in
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("group-info-synthetic"));try? store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"owner@test.invalid\",\"token\":\"synthetic-only\"}}"])
 var settings:NOVAJSON = .null
 var revision=0
 var adminRole="member"
 func info()->NOVAJSON{.object(["ok":.bool(true),"title":.string("Gruppo demo"),"role":.string("owner"),"settings":settings,"configuration_required":.bool(settings == .null),"revision":.number(Double(revision)),"members":.array([.object(["username":.string("nova.demo"),"role":.string("owner"),"is_self":.bool(true)]),.object(["username":.string("amico.demo"),"role":.string(adminRole)])]),"requests":.array([])])}
 let group=NOVASwiftGroupManagement{_,path,method,body,_ in
 if path.hasSuffix("settings") && method=="PUT"{guard body?.object?["revision"]?.integer==revision,let choice=body?.object?["settings"] else{throw NOVAServiceError.invalidResponse};settings=choice;revision+=1;try? JSONEncoder().encode(body).write(to:dir.appendingPathComponent("group-settings-saved.json"));return .object(["ok":.bool(true)])}
 if path.hasSuffix("admins") && method=="POST"{adminRole=body?.object?["role"]?.string ?? "member";try? JSONEncoder().encode(body).write(to:dir.appendingPathComponent("group-admin-saved.json"));return .object(["ok":.bool(true)])}
 return info()
 }
 let social=NOVASwiftSocial{_,path,_,_,_ in if path=="friends"{return .object(["ok":.bool(true),"friends":.array([.object(["username":.string("nuovo.demo")])])])};return .object(["ok":.bool(true),"chats":.array([])])}
 let page=UIHostingController(rootView:NOVASwiftGroupInfo(id:"synthetic",store:store,social:social,group:group).preferredColorScheme(.dark));page.modalPresentationStyle = .fullScreen
 guard let root=web.window?.rootViewController else{return};root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
 }
}
