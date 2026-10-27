import SwiftUI
import UIKit
import MessageUI

extension Notification.Name{static let novaBugReport=Notification.Name("NOVABugReportRequested")}
final class NOVAShakeHostingController<Content:View>:UIHostingController<Content>{
 override var canBecomeFirstResponder:Bool{true}
 override func motionEnded(_ motion:UIEvent.EventSubtype,with event:UIEvent?){if motion == .motionShake{NotificationCenter.default.post(name:.novaBugReport,object:nil)}else{super.motionEnded(motion,with:event)}}
 override func viewDidAppear(_ animated:Bool){super.viewDidAppear(animated);if view.window?.firstResponder == nil{becomeFirstResponder()}}
}
private extension UIWindow{var firstResponder:UIResponder?{func find(_ view:UIView)->UIResponder?{if view.isFirstResponder{return view};for child in view.subviews{if let found=find(child){return found}};return nil};return find(self)}}
struct NOVAShakeContainer<Content:View>:UIViewControllerRepresentable{
 let content:Content
 func makeUIViewController(context:Context)->NOVAShakeHostingController<Content>{let page=NOVAShakeHostingController(rootView:content);page.view.backgroundColor = .clear;return page}
 func updateUIViewController(_ page:NOVAShakeHostingController<Content>,context:Context){page.rootView=content}
}
@MainActor final class NOVABugReportModel:ObservableObject {
 @Published var open=false
 @Published var screenshot:UIImage?
 @Published var description=""
 @Published var status=""
 var enabled=true
 var lastOpened=Date.distantPast
 func request(){guard enabled,!open,Date().timeIntervalSince(lastOpened)>2,UIApplication.shared.applicationState == .active else{return};lastOpened=Date();description="";status="";screenshot=nil
  if let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow}),!Self.hasSecureField(window){
   let format=UIGraphicsImageRendererFormat();format.scale=min(UIScreen.main.scale,2);screenshot=UIGraphicsImageRenderer(bounds:window.bounds,format:format).image{_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:false)}
  }else{status="Screenshot omesso: schermata protetta o non disponibile."}
  open=true
 }
 static func hasSecureField(_ view:UIView)->Bool{if view.isHidden || view.alpha<0.01{return false};if let field=view as? UITextField,field.isSecureTextEntry{return true};return view.subviews.contains{hasSecureField($0)}}
 func clear(){screenshot=nil;description="";status=""}
 static let recipient="novasupporthelp@gmail.com"
 static var version:String{Bundle.main.object(forInfoDictionaryKey:"NOVAReleaseLabel") as? String ?? Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "TEST"}
 var bodyText:String{"Segnalazione bug NOVA\nVersione: "+Self.version+"\niOS: "+UIDevice.current.systemVersion+"\n\nDescrizione e passaggi per riprodurre:\n"+description.trimmingCharacters(in:.whitespacesAndNewlines)+"\n\nScreenshot: "+(screenshot == nil ? "non allegato":"allegato dopo revisione utente")}
}
struct NOVABugReportHost:ViewModifier {
 let enabled:Bool
 @Environment(\.scenePhase) private var phase
 @StateObject private var model=NOVABugReportModel()
 func body(content:Content)->some View{NOVAShakeContainer(content:content)
 .onReceive(NotificationCenter.default.publisher(for:.novaBugReport)){_ in model.enabled=enabled;model.request()}
 .sheet(isPresented:$model.open,onDismiss:{model.clear()}){NOVASwiftBugReport(model:model)}
 .onChange(of:enabled){_,value in model.enabled=value;if !value{model.open=false;model.clear()}}
 .onChange(of:phase){_,value in if value == .background{model.open=false;model.clear()}}
 }
}
struct NOVABugMail:UIViewControllerRepresentable {
 let body:String
 let screenshot:UIImage?
 let finished:(MFMailComposeResult,Error?)->Void
 func makeCoordinator()->Coordinator{Coordinator(finished)}
 func makeUIViewController(context:Context)->MFMailComposeViewController{let controller=MFMailComposeViewController();controller.mailComposeDelegate=context.coordinator;controller.setToRecipients([NOVABugReportModel.recipient]);controller.setSubject("NOVA bug · "+NOVABugReportModel.version);controller.setMessageBody(body,isHTML:false);if let data=screenshot?.pngData(){controller.addAttachmentData(data,mimeType:"image/png",fileName:"NOVA-screenshot.png")};return controller}
 func updateUIViewController(_ controller:MFMailComposeViewController,context:Context){}
 final class Coordinator:NSObject,MFMailComposeViewControllerDelegate{let finished:(MFMailComposeResult,Error?)->Void;init(_ finished:@escaping(MFMailComposeResult,Error?)->Void){self.finished=finished};func mailComposeController(_ controller:MFMailComposeViewController,didFinishWith result:MFMailComposeResult,error:Error?){finished(result,error)}}
}
struct NOVABugShare:UIViewControllerRepresentable {
 let items:[Any]
 let completed:(Bool)->Void
 func makeUIViewController(context:Context)->UIActivityViewController{let page=UIActivityViewController(activityItems:items,applicationActivities:nil);page.completionWithItemsHandler={_,success,_,_ in completed(success)};return page}
 func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}
struct NOVASwiftBugReport:View {
 @ObservedObject var model:NOVABugReportModel
 @Environment(\.dismiss) private var dismiss
 @State private var mail=false
 @State private var share=false
 @State private var reviewed=false
 var valid:Bool{!model.description.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && (model.screenshot==nil || reviewed)}
 var body:some View{NavigationStack{Form{
 Section{Label("Niente viene inviato automaticamente",systemImage:"hand.raised.fill").font(.headline);Text("Controlla che la schermata non mostri chat, posizione, email, voti o altri dati che non vuoi condividere. Puoi rimuovere lo screenshot. Il report non include credenziali o log raccolti dall’app.").font(.footnote).foregroundStyle(.secondary)}
 Section("Screenshot facoltativo"){if let image=model.screenshot{Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:250).frame(maxWidth:.infinity).accessibilityLabel("Anteprima screenshot da controllare");Button("Rimuovi screenshot",role:.destructive){model.screenshot=nil;reviewed=false};Toggle("Ho controllato lo screenshot",isOn:$reviewed)}else{Text("Nessuno screenshot allegato.").foregroundStyle(.secondary)}}
 Section("Descrivi il problema"){Text("Cosa è successo? Quali passaggi lo riproducono? Non inserire password o chiavi API.").font(.footnote).foregroundStyle(.secondary);TextEditor(text:$model.description).frame(minHeight:120).accessibilityIdentifier("bugDescription").onChange(of:model.description){_,value in if value.count>5000{model.description=String(value.prefix(5000))}}}
 Section("Destinatario e dati del report"){Text(NOVABugReportModel.recipient).textSelection(.enabled);Text("NOVA "+NOVABugReportModel.version+" · iOS "+UIDevice.current.systemVersion).font(.footnote);Text("Solo descrizione, versione app/iOS e lo screenshot che scegli di allegare. Il tuo client email aggiunge il mittente e gli altri dati della normale email.").font(.footnote).foregroundStyle(.secondary)}
 Section{if MFMailComposeViewController.canSendMail(){Button("Prepara email"){mail=true}.disabled(!valid);Text("Si apre Mail: puoi ricontrollare destinatario e allegato e toccare Invia. NOVA non può confermare la consegna al supporto.").font(.footnote).foregroundStyle(.secondary)}else{Button("Condividi report…"){share=true}.disabled(!valid);Text("Mail non configurata. Scegli un’app email nel pannello e invia a "+NOVABugReportModel.recipient+". Il pannello non garantisce destinatario o consegna. Puoi anche salvare il report dove scegli.").font(.footnote).foregroundStyle(.secondary)};if !model.status.isEmpty{Text(model.status).font(.footnote)}}
 }.navigationTitle("Segnala un bug").toolbar{ToolbarItem(placement:.cancellationAction){Button("Chiudi"){dismiss()}}}}
 .sheet(isPresented:$mail){NOVABugMail(body:model.bodyText,screenshot:model.screenshot){result,error in mail=false;if error != nil || result == .failed{model.status="Mail segnala un errore. Il report non è confermato inviato."}else if result == .sent{model.status="Report affidato a Mail. Consegna al supporto non verificata."}else if result == .saved{model.status="Bozza salvata in Mail, non inviata."}else{model.status="Invio annullato."}}}
 .sheet(isPresented:$share){NOVABugShare(items:["Destinatario: "+NOVABugReportModel.recipient+"\n"+model.bodyText]+(model.screenshot.map{[$0 as Any]} ?? [])){success in share=false;model.status=success ? "Operazione completata nel pannello. Invio e consegna email non verificati.":"Condivisione annullata. Nessun invio confermato."}}
 }
}
