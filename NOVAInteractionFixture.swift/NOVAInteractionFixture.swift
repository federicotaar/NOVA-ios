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
 let social=NOVASwiftSocial{_,path,method,body,_ in
 if path=="chats"{return .object(["chats":.array([.object(["id":.string("demo"),"title":.string("Gruppo demo")])])])}
 if path.hasSuffix("messages"){return .object(["messages":.array([.object(["id":.string("1"),"sender":.string("friend@test.invalid"),"body":.string("Ci vediamo dopo?"),"kind":.string("text")]),.object(["id":.string("2"),"sender":.string("me@test.invalid"),"body":.string("Certo, porto gli appunti."),"kind":.string("text")]),.object(["id":.string("3"),"sender":.string("friend@test.invalid"),"body":.string("Perfetto! Questo messaggio lungo serve per controllare che le righe vadano a capo senza occupare tutta la larghezza della schermata."),"kind":.string("text")])]),"senders":.object(["friend@test.invalid":.string("Amico demo")])])}
 return .object(["ok":.bool(true),"typing":.array([])])
 }
 let page=UIHostingController(rootView:NOVASwiftShell(store:store,initialTab:2,chatSocial:social,deviceServices:false));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? Data().write(to:dir.appendingPathComponent("interaction-ready"))}
}
