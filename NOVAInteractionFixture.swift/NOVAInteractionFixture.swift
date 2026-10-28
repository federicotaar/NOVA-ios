import SwiftUI
import UIKit

@MainActor final class NOVAInteractionState:ObservableObject {
    @Published var selected=0
    @Published var draft=""
    @Published var checks:[String:Bool]=[:]
    var initial=0
    var tracking=false
    var events:[String]=[]
    var listener:NSObjectProtocol?
    init(){listener=NotificationCenter.default.addObserver(forName:Notification.Name("NOVASwiftNavigationTracking"),object:nil,queue:.main){[weak self] note in MainActor.assumeIsolated{self?.event(note)}}}
    func event(_ note:Notification){let phase=note.userInfo?["phase"] as? String ?? "";events.append(phase);if phase=="start"{initial=selected;tracking=true};if phase=="move"{checks["contentHeldUntilRelease"]=(checks["contentHeldUntilRelease"] ?? true) && selected==initial};if phase=="cancel"{checks["cancelKeepsPage"]=selected==initial;tracking=false};if phase=="end"{tracking=false;checks["fingerEnded"]=true};persist()}
    func choose(_ value:Int){if tracking{checks["noEarlyPageCommit"]=false};selected=value;persist()}
    func persist(){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];let data:[String:Any]=["checks":checks,"events":events,"selected":selected,"draft":draft];try? JSONSerialization.data(withJSONObject:data,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-interaction.json"))}
}
@MainActor struct NOVAInteractionFixture:View {
    @StateObject private var model=NOVAInteractionState()
    var body:some View{VStack(spacing:24){Text(["Home","Voti","Chat","Mappa","Profilo"][model.selected]).font(.largeTitle).accessibilityIdentifier("interactionPage");Text("Pagina \(model.selected)").accessibilityIdentifier("interactionSelected");Spacer();HStack{Image(systemName:"photo");TextField("Messaggio",text:$model.draft,axis:.vertical).lineLimit(1...6).textFieldStyle(.plain).accessibilityIdentifier("interactionComposer");Image(systemName:"arrow.up")}.modifier(NOVASwiftComposerSurface()).padding(.horizontal);Button("Chiudi tastiera"){UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil)};Spacer().frame(height:8)}.safeAreaInset(edge:.bottom){NOVASwiftNavigation(selected:Binding(get:{model.selected},set:{model.choose($0)}),avatar:"").frame(height:58).padding(.horizontal,18).padding(.bottom,8)}.onChange(of:model.draft){_,_ in model.persist()}.onAppear{model.checks["noEarlyPageCommit"]=true;model.persist()}}
}
@MainActor func visualSwiftInteractionReady(_ web:WKWebView,_ attempt:Int){
    guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftInteractionReady(web,attempt+1)}};return}
    let page=UIHostingController(rootView:NOVAInteractionFixture());page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftRootInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftRootInteractionReady(web,attempt+1)}};return}
 let directory=FileManager.default.temporaryDirectory.appendingPathComponent("root-interaction")
 let store=NOVASwiftStore(directory:directory)
 if store.archive==nil{try? store.importOnce(["nova.v1":"{\"name\":\"Studente demo\",\"done\":1,\"introOff\":1,\"theme\":\"light\",\"w\":{\"wx\":0,\"sp\":0},\"tasks\":[],\"tt\":{\"lessons\":[]},\"prof\":{\"username\":\"studente.demo\"}}"])}
 let page=UIHostingController(rootView:NOVASwiftProtectedRoot(store:store));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
 func persist(){let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];if let value=store.archive?.active,let data=try? JSONEncoder().encode(value){try? data.write(to:docs.appendingPathComponent("swift-root-state.json"))};DispatchQueue.main.asyncAfter(deadline:.now()+0.5){persist()}}
 persist()
}


@MainActor final class NOVALaunchFixtureOrigin:NSObject,WKNavigationDelegate {
 static let shared=NOVALaunchFixtureOrigin()
 var completion:(()->Void)?
 func prepare(_ web:WKWebView,_ completion:@escaping()->Void){self.completion=completion;web.stopLoading();web.configuration.userContentController.removeAllUserScripts();web.navigationDelegate=self
 #if SWIFT_PACKAGE
 let bundle=Bundle.module
 #else
 let bundle=Bundle.main
 #endif
 guard let source=bundle.url(forResource:"nova",withExtension:"html") else{return}
 web.loadHTMLString("<!doctype html><title>Isolated migration fixture</title>",baseURL:source)
 }
 func webView(_ web:WKWebView,didFinish navigation:WKNavigation!){web.evaluateJavaScript("localStorage.clear();localStorage.setItem('nova.v1',JSON.stringify({name:'Studente demo',done:1,introOff:1,theme:'light',w:{wx:0,sp:0},tasks:[],tt:{lessons:[]},prof:{username:'studente.demo'},locShare:1,bgLoc:1,locSession:'expired',locSessionToken:'expired'}));true"){_,error in guard error==nil else{return};let callback=self.completion;self.completion=nil;callback?()}}
}
@MainActor func visualSwiftLaunchInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftLaunchInteractionReady(web,attempt+1)}};return}
 let directory=FileManager.default.temporaryDirectory.appendingPathComponent("launch-interaction")
 let store=NOVASwiftStore(directory:directory)
 NOVALaunchFixtureOrigin.shared.prepare(web){let page=UIHostingController(rootView:NOVASwiftLaunchRoot(store:store));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}}
 func persist(){let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];if let value=store.archive?.active,let data=try? JSONEncoder().encode(value){try? data.write(to:docs.appendingPathComponent("swift-root-state.json"))};DispatchQueue.main.asyncAfter(deadline:.now()+0.5){persist()}}
 persist()
}

@MainActor func visualSwiftChatInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftChatInteractionReady(web,attempt+1)}};return}
 let folder=FileManager.default.temporaryDirectory.appendingPathComponent("chat-overlap-fixture")
 let store=NOVASwiftStore(directory:folder);if store.archive==nil{try? store.importOnce(["nova.v1":"{\"name\":\"Demo\",\"done\":1,\"introOff\":1,\"theme\":\"dark\",\"acct\":{\"email\":\"me@test.invalid\",\"token\":\"synthetic-only\"},\"prof\":{\"username\":\"demo\"},\"tasks\":[],\"w\":{\"wx\":0,\"sp\":0}}"])}
 let linkSample="Prima https://example.com/demo?x=1 poi testo."
 let linked=NOVASwiftMessageLinks.attributed(linkSample)
 let checks=["textPreserved":String(linked.characters)==linkSample,"httpsLinked":linked.runs.contains{$0.link?.absoluteString=="https://example.com/demo?x=1"},"httpAllowed":NOVASwiftMessageLinks.safe(URL(string:"http://example.com/demo")!),"customRejected":!NOVASwiftMessageLinks.safe(URL(string:"nova://run")!),"javascriptRejected":!NOVASwiftMessageLinks.safe(URL(string:"javascript:alert(1)")!),"fileRejected":!NOVASwiftMessageLinks.safe(URL(string:"file:///tmp/private")!),"credentialsRejected":!NOVASwiftMessageLinks.safe(URL(string:"https://user:pass@example.com")!),"plainUnlinked":NOVASwiftMessageLinks.attributed("Solo testo").runs.allSatisfy{$0.link==nil}]
 let evidence=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? JSONSerialization.data(withJSONObject:checks).write(to:evidence.appendingPathComponent("chat-link-checks.json"))
 let social=NOVASwiftSocial{_,path,method,body,_ in
 if path=="chats"{return .object(["chats":.array([.object(["id":.string("demo"),"title":.string("Gruppo demo")])])])}
 if path.hasSuffix("messages"){return .object(["messages":.array([.object(["id":.string("1"),"sender":.string("friend@test.invalid"),"body":.string("Ci vediamo dopo?"),"kind":.string("text")]),.object(["id":.string("2"),"sender":.string("me@test.invalid"),"body":.string("Certo, porto gli appunti."),"kind":.string("text")]),.object(["id":.string("synthetic-link"),"sender":.string("friend@test.invalid"),"body":.string("Prima https://example.com/demo poi testo."),"kind":.string("text")]),.object(["id":.string("3"),"sender":.string("friend@test.invalid"),"body":.string("Perfetto! Questo messaggio lungo serve per controllare che le righe vadano a capo senza occupare tutta la larghezza della schermata."),"kind":.string("text")]),.object(["id":.string("4"),"sender":.string("friend@test.invalid"),"kind":.string("image"),"media_key":.string("https://test.invalid/synthetic-color-grid")])]),"senders":.object(["friend@test.invalid":.string("Amico demo")])])}
 return .object(["ok":.bool(true),"typing":.array([])])
 }
 let page=UIHostingController(rootView:NOVASwiftShell(store:store,initialTab:2,chatSocial:social,deviceServices:false).environment(\.openURL,OpenURLAction{url in try? url.absoluteString.write(to:evidence.appendingPathComponent("chat-link-tapped.txt"),atomically:true,encoding:.utf8);return .handled}));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftMapInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftMapInteractionReady(web,attempt+1)}};return}
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("map-layout-fixture-28"));if store.archive==nil{try? store.importOnce(["nova.v1":"{\"name\":\"Demo\",\"done\":1,\"introOff\":1,\"theme\":\"dark\",\"acct\":{\"email\":\"map@test.invalid\",\"token\":\"synthetic-only\"},\"tasks\":[],\"w\":{\"wx\":0,\"sp\":0}}"])}
 Task{@MainActor in
 var old:[String:NOVAJSON]=["locShare":.number(1),"bgLoc":.number(1),"locSession":.string("old-session")]
 var checks=["oldFlagsCannotShare":!NOVASwiftLocationConsent.sharing(old),"oldFlagsCannotBackground":!NOVASwiftLocationConsent.background(old)]
 old["locConsentV2"] = .string("old-session");checks["sharingConsentAloneNoBackground"] = NOVASwiftLocationConsent.sharing(old) && !NOVASwiftLocationConsent.background(old)
 old["bgConsentV2"] = .string("old-session");checks["separateConsentRequired"] = NOVASwiftLocationConsent.background(old)
 old["locSession"] = .string("replacement-session");checks["replacementSessionRejectsOldConsent"] = !NOVASwiftLocationConsent.sharing(old) && !NOVASwiftLocationConsent.background(old)
 func row(_ name:String,_ age:Double=0)->NOVAJSON{.object(["username":.string(name),"lat":.number(0),"lon":.number(0),"ts":.number(Date().timeIntervalSince1970*1000-age*1000)])}
 func response(_ rows:[NOVAJSON])->NOVAJSON{.object(["ok":.bool(true),"friends":.array(rows)])}
 checks["freshParserAccepted"] = NOVASwiftMapFriend.parse(row("synthetic")) != nil
 checks["staleParserRejected"] = NOVASwiftMapFriend.parse(row("stale",1801)) == nil
 var phase=0
 let model=NOVASwiftMapModel{_,path,method,_ in precondition(path=="map" && method=="GET");return response(phase==0 ? []:[row("synthetic_friend")])}
 await model.refresh(store);checks["emptyResponseExplained"] = model.friends.isEmpty && model.lastChecked != nil
 phase=1;await model.refresh(store);checks["laterSharingAppearsOnRefresh"] = model.friends.count==1 && model.friends.first?.id=="synthetic_friend"
 let bad=NOVASwiftMapModel{_,_,_,_ in .object(["error":.string("synthetic")])};await bad.refresh(store);checks["malformedNotEmptySuccess"] = bad.lastChecked==nil && bad.status.contains("non aggiornata")
 let slow=NOVASwiftMapModel{_,_,_,_ in try? await Task.sleep(for:.milliseconds(150));return response([row("late")])}
 let pending=Task{@MainActor in await slow.refresh(store)};try? await Task.sleep(for:.milliseconds(20));slow.cancel();await pending.value;checks["cancelRejectsLateResult"] = slow.friends.isEmpty && slow.lastChecked==nil
 var calls=0
 let race=NOVASwiftMapModel{_,_,_,_ in calls+=1;let n=calls;if n==1{try? await Task.sleep(for:.milliseconds(160))};return response([row(n==1 ? "older":"newer")])}
 let first=Task{@MainActor in await race.refresh(store)};try? await Task.sleep(for:.milliseconds(20));await race.refresh(store);await first.value;checks["outOfOrderRefreshRejected"] = race.friends.first?.id=="newer"
 checks["refreshDoesNotEnableSharing"] = !NOVASwiftLocationConsent.sharing(store.archive?.active.object ?? [:])
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("map-consent-checks.json"))
 let page=UIHostingController(rootView:NOVASwiftShell(store:store,initialTab:3,mapModel:model,deviceServices:false));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
 }
}

@MainActor struct NOVASongArtworkFixture:View{
 let song:NOVAJSON = .object(["t":.string("Yellow"),"a":.string("Coldplay"),"art":.string("https://cdn-images.dzcdn.net/images/cover/970dce98eeea6729244c0ae71707a83d/250x250-000000-80-0-0.jpg")])
 var body:some View{NavigationStack{List{Section("La tua canzone"){NOVASwiftSongCard(song:song)};Section("Risultato di ricerca"){HStack{NOVASwiftSongArtwork(song:song,size:56);VStack(alignment:.leading){Text("Yellow");Text("Coldplay").font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:"play.circle.fill").font(.title2)}}}.navigationTitle("La tua canzone")}.preferredColorScheme(.dark)}
}
@MainActor func visualSwiftSongInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftSongInteractionReady(web,attempt+1)}};return}
 let page=UIHostingController(rootView:NOVASongArtworkFixture());page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];DispatchQueue.main.asyncAfter(deadline:.now()+3){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}}
}

@MainActor func visualSwiftQRInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftQRInteractionReady(web,attempt+1)}};return}
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
 var checks:[String:Bool]=[:]
 var diagnostics:[[String:Any]]=[]
 func scan(_ cg:CGImage,_ label:String,_ expected:String)->Bool {
  var defaultSuccess=false
  for revision in [0,1] {
   let request=VNDetectBarcodesRequest();request.symbologies=[.qr]
   if revision==1{request.revision=VNDetectBarcodesRequestRevision1}
   var row:[String:Any]=["label":label,"requestedRevision":revision,"actualRevision":request.revision,"width":cg.width,"height":cg.height]
   do{try VNImageRequestHandler(cgImage:cg,orientation:.up).perform([request]);let payloads=request.results?.compactMap{$0.payloadStringValue} ?? [];row["payloads"]=payloads;row["count"]=request.results?.count ?? 0;row["observations"]=request.results?.map{String(describing:$0)} ?? [];row["pass"]=payloads.contains(expected);if revision==1{defaultSuccess=payloads.contains(expected)}}catch{row["error"]=String(describing:error);row["nsError"]=(error as NSError).userInfo.description}
   diagnostics.append(row)
  }
  return defaultSuccess
 }
 for username in ["demo","nova.demo","abcdefghijklmnopqrst"]{
  guard let image=NOVASwiftQR.render(username) else{checks[username]=false;continue}
  try? image.pngData()?.write(to:dir.appendingPathComponent("qr-"+username+".png"))
  for size in [240,480]{
   let format=UIGraphicsImageRendererFormat();format.scale=1
   let resized=UIGraphicsImageRenderer(size:CGSize(width:size,height:size),format:format).image{_ in image.draw(in:CGRect(x:0,y:0,width:size,height:size))}
   try? resized.pngData()?.write(to:dir.appendingPathComponent("qr-"+username+"-"+String(size)+".png"))
   checks[username+"-"+String(size)]=scan(resized.cgImage!,"styled-"+username+"-"+String(size),"nova:add:"+username)
  }
 }
 let control=CIFilter.qrCodeGenerator();control.message=Data("nova:add:demo".utf8);control.correctionLevel="M"
 if let output=control.outputImage,let cg=CIContext().createCGImage(output.transformed(by:CGAffineTransform(scaleX:10,y:10)),from:output.extent.applying(CGAffineTransform(scaleX:10,y:10))){
  _=scan(cg,"standard-control","nova:add:demo")
 }
 try? JSONSerialization.data(withJSONObject:diagnostics,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("qr-vision-matrix.json"))
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("qr-scan-checks.json"))
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("qr-layout-fixture"));if store.archive==nil{try? store.importOnce(["nova.v1":"{\"name\":\"Demo\",\"prof\":{\"username\":\"nova.demo\"},\"done\":1,\"introOff\":1,\"theme\":\"dark\",\"tasks\":[]}"])}
 let page=UIHostingController(rootView:NOVASwiftQR(store:store,people:NOVASwiftPeople()));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftLegalInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftLegalInteractionReady(web,attempt+1)}};return}
 let page=UIHostingController(rootView:NavigationStack{NOVASwiftLegal()});page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor struct NOVABugFixture:View{
 var body:some View{NavigationStack{VStack(spacing:20){Text("NOVA demo sintetica").font(.title);Text("Nessun dato personale nel fixture.");Button("Simula segnalazione"){NotificationCenter.default.post(name:.novaBugReport,object:nil)}}.navigationTitle("NOVA")}.modifier(NOVABugReportHost(enabled:true))}
}
@MainActor func visualSwiftBugInteractionReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftBugInteractionReady(web,attempt+1)}};return}
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
 var seen=false;let token=NotificationCenter.default.addObserver(forName:.novaBugReport,object:nil,queue:.main){_ in seen=true}
 let control=NOVAShakeHostingController(rootView:Text("Synthetic"));control.motionEnded(.motionShake,with:nil);NotificationCenter.default.removeObserver(token)
 let secure=UITextField();secure.isSecureTextEntry=true;let checks=["shakeHandlerPostsReport":seen,"secureInputSuppressed":NOVABugReportModel.hasSecureField(secure),"approvedRecipient":NOVABugReportModel.recipient=="novasupporthelp@gmail.com"]
 try? JSONSerialization.data(withJSONObject:checks).write(to:dir.appendingPathComponent("bug-checks.json"))
 let page=UIHostingController(rootView:NOVABugFixture());page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftReportedBugsReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftReportedBugsReady(web,attempt+1)}};return}
 let tz=TimeZone(identifier:"Europe/Rome")!;var cal=Calendar(identifier:.gregorian);cal.timeZone=tz
 let date=cal.date(from:DateComponents(year:2026,month:10,day:30,hour:0))!
 let tasks:[NOVAJSON]=[.object(["id":.string("a"),"title":.string("Compito del 30"),"due":.string("2026-10-30T08:00"),"done":.number(0)]),.object(["id":.string("b"),"title":.string("Altro giorno"),"due":.string("2026-10-29T08:00")])]
 let oldKey=date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
 let checks:[String:Bool]=["localRomeKey":NOVASwiftTaskDay.key(date,timeZone:tz)=="2026-10-30","oldUTCFilterLosesTask":oldKey != "2026-10-30","romeGetsCorrectTask":NOVASwiftTaskDay.tasks(tasks,on:date,timeZone:tz).map{$0.object?["id"]?.string ?? ""}==["a"],"emptyDayIsEmpty":NOVASwiftTaskDay.tasks(tasks,on:cal.date(byAdding:.day,value:1,to:date)!,timeZone:tz).isEmpty]
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? JSONSerialization.data(withJSONObject:checks).write(to:dir.appendingPathComponent("reported-bug-checks.json"))
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("reported-bug-fixture"));if store.archive==nil{try? store.importOnce(["nova.v1":"{\"name\":\"Demo\",\"done\":1,\"introOff\":1,\"theme\":\"dark\",\"w\":{\"wx\":0,\"sp\":0,\"task\":0,\"nx\":0},\"tasks\":[{\"id\":\"a\",\"title\":\"Compito del 30\",\"due\":\"2026-10-30T08:00\",\"done\":0},{\"id\":\"b\",\"title\":\"Altro giorno\",\"due\":\"2026-10-29T08:00\",\"done\":0}]}"])}
 try? store.update(owner:store.archive!.owner){root in root["chat"] = .array((0..<12).map{index in .object(["r":.string(index%2==0 ? "user":"assistant"),"c":.string(index%2==0 ? "Esempio sintetico: spiegami questo argomento.":"Risposta sintetica per controllare il contenuto sotto il vetro e la tastiera, senza richieste esterne.")])})}
 let page=UIHostingController(rootView:NOVASwiftDashboard(store:store).preferredColorScheme(.dark));page.overrideUserInterfaceStyle = .dark;page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftComposerPushReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftComposerPushReady(web,attempt+1)}};return}
 let tz=TimeZone(identifier:"Europe/Rome")!;var cal=Calendar(identifier:.gregorian);cal.timeZone=tz
 let date=cal.date(from:DateComponents(year:2026,month:10,day:30,hour:0))!
 let tasks:[NOVAJSON]=[.object(["id":.string("a"),"title":.string("Compito del 30"),"due":.string("2026-10-30T08:00"),"done":.number(0)]),.object(["id":.string("b"),"title":.string("Altro giorno"),"due":.string("2026-10-29T08:00")])]
 let oldKey=date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
 let checks:[String:Bool]=["localRomeKey":NOVASwiftTaskDay.key(date,timeZone:tz)=="2026-10-30","oldUTCFilterLosesTask":oldKey != "2026-10-30","romeGetsCorrectTask":NOVASwiftTaskDay.tasks(tasks,on:date,timeZone:tz).map{$0.object?["id"]?.string ?? ""}==["a"],"emptyDayIsEmpty":NOVASwiftTaskDay.tasks(tasks,on:cal.date(byAdding:.day,value:1,to:date)!,timeZone:tz).isEmpty]
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? JSONSerialization.data(withJSONObject:checks).write(to:dir.appendingPathComponent("reported-bug-checks.json"))
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("composer-push-fixture"));if store.archive==nil{try? store.importOnce(["nova.v1":"{\"name\":\"Demo\",\"done\":1,\"introOff\":1,\"theme\":\"dark\",\"w\":{\"wx\":0,\"sp\":0,\"task\":0,\"nx\":0},\"tasks\":[{\"id\":\"a\",\"title\":\"Compito del 30\",\"due\":\"2026-10-30T08:00\",\"done\":0},{\"id\":\"b\",\"title\":\"Altro giorno\",\"due\":\"2026-10-29T08:00\",\"done\":0}]}"])}
 try? store.update(owner:store.archive!.owner){root in root["chat"] = .array((0..<12).map{index in .object(["r":.string(index%2==0 ? "user":"assistant"),"c":.string(index%2==0 ? "Esempio sintetico: spiegami questo argomento.":"Risposta sintetica per controllare il contenuto sotto il vetro e la tastiera, senza richieste esterne.")])})}
 let social=NOVASwiftSocial{_,_,_,_,_ in .object(["chats":.array([])])}
 let page=UIHostingController(rootView:NOVASwiftShell(store:store,initialTab:2,chatSocial:social,deviceServices:false));page.overrideUserInterfaceStyle = .dark;page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftPerformanceReady(_ web:WKWebView,_ attempt:Int){
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
 Task{@MainActor in
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("latency-fixture"))
  try? store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"synthetic@test.invalid\",\"token\":\"synthetic-only\"}}"])
  let people=NOVASwiftPeople{_,path,_,_,query in try await Task.sleep(for:.milliseconds(300));return .object(["ok":.bool(true),path=="friends" ? "friends":"users":.array([.object(["username":.string(query.first?.value ?? "friend")])])])}
  let start=Date();await people.loadOverview(store);let elapsed=Date().timeIntervalSince(start)
  var checks=["independentReadsOverlap":elapsed<0.75,"allListsLoaded":people.friends.count==1 && people.followers.count==1 && people.following.count==1]
  let pending=Task{@MainActor in await people.loadOverview(store)}
  try? await Task.sleep(for:.milliseconds(50));people.reset();try? store.update(owner:store.archive!.owner){$0["acct"] = .object(["email":.string("other@test.invalid"),"token":.string("other-synthetic")])};await pending.value
  checks["oldAccountResultsRejected"]=people.friends.isEmpty && people.followers.isEmpty && people.following.isEmpty
  try? JSONSerialization.data(withJSONObject:["checks":checks,"syntheticSeconds":elapsed]).write(to:dir.appendingPathComponent("performance-checks.json"))
  try? Data().write(to:dir.appendingPathComponent("interaction-ready"))
 }
}

@MainActor func visualSwiftReleaseReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftReleaseReady(web,attempt+1)}};return}
 let sample:[[String:Any]]=[["tag_name":"v2026.10.27.3","draft":false,"prerelease":true,"html_url":"https://github.com/federicotaranudev/NOVA-ios/releases/tag/v2026.10.27.3","assets":[["name":"NOVA-2026.10.27.3.ipa","size":100,"browser_download_url":"https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.27.3/NOVA-2026.10.27.3.ipa"]]]]
 let candidate=NOVASwiftRelease.select(sample,current:"2026.10.27.2")!
 var invalid=sample;invalid[0]["assets"]=[]
 var draft=sample;draft[0]["draft"]=true
 var checks=["newerIPAFound":candidate.version=="2026.10.27.3","sameVersionNoNotice":NOVASwiftRelease.select(sample,current:"2026.10.27.3")==nil,"noAssetNoNotice":NOVASwiftRelease.select(invalid,current:"2026.10.27.2")==nil,"draftNoNotice":NOVASwiftRelease.select(draft,current:"2026.10.27.2")==nil,"numericNotLexical":NOVASwiftRelease.newer("2026.10.27.10",than:"2026.10.27.9")]
 var importantSample=sample;importantSample[0]["body"]="[NOVA_UPDATE:IMPORTANT] Protected media update";checks["importantMarkerPersistent"]=NOVASwiftRelease.select(importantSample,current:"2026.10.27.2")?.important==true;checks["minorDefaultDismissible"]=candidate.important==false
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? JSONSerialization.data(withJSONObject:checks).write(to:dir.appendingPathComponent("release-checks.json"))
 let major=NOVASwiftRelease.select(importantSample,current:"2026.10.27.2")!
 checks["minorDismissalHides"]=candidate.shouldShow(dismissed:true)==false;checks["majorIgnoresDismissal"]=major.shouldShow(dismissed:true);checks["majorGoneAfterUpdate"]=NOVASwiftRelease.select(importantSample,current:"2026.10.27.3")==nil
 try? JSONSerialization.data(withJSONObject:checks).write(to:dir.appendingPathComponent("release-checks.json"))
 let page=UIHostingController(rootView:VStack(spacing:20){NOVASwiftReleaseBanner(release:candidate);NOVASwiftReleaseBanner(release:major);Spacer();Text("Home dimostrativa: nessun blocco dell'app");Spacer()}.preferredColorScheme(.dark));page.overrideUserInterfaceStyle = .dark;page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}

@MainActor func visualSwiftGroupAlertReady(_ web:WKWebView,_ attempt:Int){
 guard let root=web.window?.rootViewController else{if attempt<60{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftGroupAlertReady(web,attempt+1)}};return}
 Task{@MainActor in
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("group-alert-fixture"))
 try? store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"synthetic@test.invalid\",\"token\":\"synthetic-only\"}}"])
 var id=10,sender="friend@test.invalid",unread=1,kind="group",delay=false
 let alerts=NOVASwiftGroupAlerts{_,_,_,_,_ in if delay{try await Task.sleep(for:.milliseconds(200))};return .object(["ok":.bool(true),"chats":.array([.object(["id":.string("syntheticgroup"),"type":.string(kind),"title":.string("Gruppo demo"),"unread":.number(Double(unread)),"last":.object(["id":.number(Double(id)),"sender":.string(sender),"body":.string("Contenuto privato non mostrato nell'avviso")])])])])}
 await alerts.check(store);var checks=["firstLoadSilent":!alerts.notice]
 id=11;await alerts.check(store);checks["incomingGroupNotice"]=alerts.notice
 alerts.dismiss();await alerts.check(store);checks["duplicateSilent"] = !alerts.notice
 id=12;sender="synthetic@test.invalid";await alerts.check(store);checks["ownMessageSilent"] = !alerts.notice
 id=13;sender="friend@test.invalid";unread=0;await alerts.check(store);checks["readMessageSilent"] = !alerts.notice
 kind="dm";id=14;unread=1;await alerts.check(store);checks["directMessageOutsideScope"] = !alerts.notice
 kind="group";id=15;await alerts.check(store);id=16;delay=true;let pending=Task{@MainActor in await alerts.check(store)};try? await Task.sleep(for:.milliseconds(20));alerts.reset();await pending.value;checks["resetRejectsOldReply"] = !alerts.notice
 delay=false;await alerts.check(store);id=17;await alerts.check(store)
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? JSONSerialization.data(withJSONObject:["checks":checks]).write(to:dir.appendingPathComponent("performance-checks.json"))
 let page=UIHostingController(rootView:NOVASwiftShell(store:store,initialTab:2,chatSocial:NOVASwiftSocial{_,_,_,_,_ in .object(["ok":.bool(true),"chats":.array([])])},deviceServices:false,groupAlertModel:alerts).preferredColorScheme(.dark));page.overrideUserInterfaceStyle = .dark;page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
 }
}

@MainActor func visualSwiftPlaybackReady(_ web:WKWebView,_ attempt:Int){
 let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
 Task{@MainActor in
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent("voice-play-fixture"));try? store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"synthetic@test.invalid\",\"token\":\"synthetic-only\"}}"])
 var wave=Data();func text(_ s:String){wave.append(Data(s.utf8))};func num(_ x:UInt32,_ count:Int){for n in 0..<count{wave.append(UInt8((x >> (8*n))&255))}}
 let samples=22050;text("RIFF");num(UInt32(36+samples*2),4);text("WAVEfmt ");num(16,4);num(1,2);num(1,2);num(22050,4);num(44100,4);num(2,2);num(16,2);text("data");num(UInt32(samples*2),4);for n in 0..<samples{let sample=Int16(sin(Double(n)*2*Double.pi*440/22050)*3000);num(UInt32(UInt16(bitPattern:sample)),2)}
 let url=URL(string:"https://api.federicotaranu.site/media/synthetic")!
 let playback=NOVASwiftVoicePlayback{_,_ in wave};playback.play(url,store);try? await Task.sleep(for:.milliseconds(200));var checks=["validAudioStarts":playback.status=="Riproduzione vocale." && !playback.loading];playback.stop();checks["stopClearsState"]=playback.status.isEmpty
 let failing=NOVASwiftVoicePlayback{_,_ in throw NOVAServiceError.invalidResponse};failing.play(url,store);try? await Task.sleep(for:.milliseconds(100));checks["failureVisible"]=failing.status.contains("non riprodotto") && !failing.loading
 let delayed=NOVASwiftVoicePlayback{_,_ in try await Task.sleep(for:.milliseconds(200));return wave};delayed.play(url,store);delayed.stop();try? await Task.sleep(for:.milliseconds(300));checks["cancelRejectsReply"]=delayed.status.isEmpty
 delayed.play(url,store);try? store.changeAccount(email:"other@test.invalid",token:"other");assert(store.archive?.owner=="other@test.invalid");try? await Task.sleep(for:.milliseconds(300));checks["oldAccountNeverPlays"]=delayed.status != "Riproduzione vocale."
 try? JSONSerialization.data(withJSONObject:["checks":checks]).write(to:dir.appendingPathComponent("performance-checks.json"));try? Data().write(to:dir.appendingPathComponent("interaction-ready"))
 }
}
