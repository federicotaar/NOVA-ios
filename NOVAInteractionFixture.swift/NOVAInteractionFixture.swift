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
