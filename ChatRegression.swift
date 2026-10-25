import UIKit
import WebKit
import PhotosUI
@main final class ChatTestApp:UIResponder,UIApplicationDelegate,WKNavigationDelegate,WKScriptMessageHandler{
 var window:UIWindow?;var web:WKWebView!;var composer:AnyObject?;var navigation:AnyObject?
 func application(_ application:UIApplication,didFinishLaunchingWithOptions:[UIApplication.LaunchOptionsKey:Any]?)->Bool{
 let c=WKWebViewConfiguration();c.userContentController.add(self,name:"result");c.userContentController.add(self,name:"nova")
 let fixture="""
 window.__novaNativeGlass=true;
 localStorage.setItem('nova.v1',JSON.stringify({introOff:1,ob:2,done:1,profDone:1,theme:'dark',name:'Synthetic',acct:{token:'fixture-only',email:'me@test.invalid'},prof:{username:'fixture'},w:{wx:0}}));
 window.testErrors=[];window.testTyping=[];window.testSent=[];
 window.addEventListener('error',e=>testErrors.push(e.message||'error'));
 window.fetch=async(url,opt={})=>{url=String(url);let method=opt.method||'GET',j={ok:true,profile:null,friends:Array.from({length:14},(_,i)=>({email:'friend'+i+'@test.invalid',username:'study_friend_'+i,avatar:'📘'})),incoming:[],outgoing:[],chats:[],typing:[],url:'/synthetic.jpg'};
 if(url.includes('/typing')&&method==='POST')testTyping.push(url);
 if(url.includes('/messages')){if(method==='POST')testSent.push(JSON.parse(opt.body||'{}'));j={ok:true,messages:Array.from({length:18},(_,i)=>({id:i+1,sender:i%2?'me@test.invalid':'friend@test.invalid',kind:'text',body:['Maths review at 17:00','Bring the blue notebook','See you after class'][i%3]})),senders:{'friend@test.invalid':'Example'},reactions:{}}}return {ok:true,status:200,json:async()=>j};};
 """
 c.userContentController.addUserScript(WKUserScript(source:fixture,injectionTime:.atDocumentStart,forMainFrameOnly:true))
 web=WKWebView(frame:.zero,configuration:c);web.navigationDelegate=self;web.isOpaque=false;web.backgroundColor = .black
 let v=UIViewController();v.view=web;window=UIWindow(frame:UIScreen.main.bounds);window?.rootViewController=v;window?.makeKeyAndVisible()
 if #available(iOS 26.0, *){composer=NativeGlassComposer(web:web);navigation=NativeGlassNavigation(web:web)}
 let u=Bundle.main.url(forResource:"nova",withExtension:"html")!;web.loadFileURL(u,allowingReadAccessTo:u.deletingLastPathComponent());return true
 }
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){DispatchQueue.main.asyncAfter(deadline:.now()+2){
 self.web.evaluateJavaScript("document.querySelectorAll('dialog[open]').forEach(d=>d.close());$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(4);setTimeout(()=>window.scrollTo(0,450),100);",completionHandler:nil)
 DispatchQueue.main.asyncAfter(deadline:.now()+2){self.saveImage("native-nav.png");try? Data().write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("nav-ready"))
 DispatchQueue.main.asyncAfter(deadline:.now()+600){
 self.web.evaluateJavaScript("pg(2);convOpen(1,'Study group');",completionHandler:nil)
 DispatchQueue.main.asyncAfter(deadline:.now()+2){self.testNative()}
 }
 }
 }}
 func testNative(){if #available(iOS 26.0,*),let c=composer as? NativeGlassComposer{
 guard !c.surface.isHidden else{return fail("Native composer handshake absent")}
 c.input.text="Draft survives cancellation";c.changed();c.picker(PHPickerViewController(configuration:PHPickerConfiguration()),didFinishPicking:[])
 guard c.input.text=="Draft survives cancellation" else{return fail("cancel lost draft")}
 c.pickerOwner=c.account;c.pickerMode=c.mode
 let image=UIGraphicsImageRenderer(size:CGSize(width:24,height:24)).image{ctx in UIColor.blue.setFill();ctx.fill(CGRect(x:0,y:0,width:24,height:24))}
 c.consumeImageProvider(NSItemProvider(object:image))
 DispatchQueue.main.asyncAfter(deadline:.now()+2){

 DispatchQueue.main.asyncAfter(deadline:.now()+1){
 c.input.text="Native action fixture";c.changed();c.submit();c.submit()
 DispatchQueue.main.asyncAfter(deadline:.now()+1){
 self.web.evaluateJavaScript("JSON.stringify({sent:testSent,errors:testErrors,draft:$('#cvI').value})"){value,error in
 guard let text=value as? String,let data=text.data(using:.utf8),let result=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let sent=result["sent"] as? [[String:Any]],sent.filter({$0["kind"] as? String == "image"}).count==1,sent.filter({$0["body"] as? String == "Native action fixture"}).count==1,sent.count==2 else{return self.fail("native send roundtrip failed")}
 c.input.text="Draft for our study plan";c.changed();c.input.becomeFirstResponder()
 DispatchQueue.main.asyncAfter(deadline:.now()+3){
 let rect=c.surface.convert(c.input.bounds,from:c.input);let bottom=c.surface.frame.maxY;let visible=self.web.bounds.height-c.keyboard
 guard bottom<=visible+2 else{return self.fail("native input overlaps keyboard")}
 self.web.evaluateJavaScript("$('#cvM').scrollTop=Math.max(0,$('#cvM').scrollHeight-$('#cvM').clientHeight-70)",completionHandler:nil)
 self.result(["ok":true,"nativeEffect":"UIGlassEffect.clear","nativeComposerVisible":!c.surface.isHidden,"nativeInput":c.input.text ?? "","keyboardHeight":c.keyboard,"composerBottom":bottom,"visibleBottom":visible,"nativeSendCount":sent.count,"nativePhotoProviderPipeline":true,"nativeCancelDraftRetained":true,"doubleSendSingleText":true,"errors":result["errors"] ?? [],"inputWidth":rect.width])
 }
 }
 }
 }}
 }else{fail("Simulator does not support iOS26 Liquid Glass")}}
 func saveImage(_ name:String){guard let view=window else{return};let renderer=UIGraphicsImageRenderer(bounds:view.bounds);let image=renderer.image{_ in view.drawHierarchy(in:view.bounds,afterScreenUpdates:true)};if let data=image.pngData(){try? data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent(name))}}
 func fail(_ message:String){result(["ok":false,"error":message])}
 func result(_ obj:[String:Any]){if let data=try? JSONSerialization.data(withJSONObject:obj,options:.prettyPrinted){try? data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("regression.json"))}}
 func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage){guard let b=message.body as? [String:Any],#available(iOS 26.0,*) else{return};if b["t"] as? String == "nativeComposer"{(composer as? NativeGlassComposer)?.sync(b)};if b["t"] as? String == "nativeNavigation"{(navigation as? NativeGlassNavigation)?.sync(b)}}
}
// Native iOS26 Liquid Glass message control; older versions keep the web composer.
@available(iOS 26.0, *)
final class NativeGlassComposer: NSObject, UITextFieldDelegate, PHPickerViewControllerDelegate {
 weak var web: WKWebView?
 let surface=UIVisualEffectView(effect: UIGlassEffect(style:.clear))
 let permissions=UIButton(type:.system)
 let photo=UIButton(type:.system), mic=UIButton(type:.system), send=UIButton(type:.system), input=UITextField()
 var mode="", account="", remote="";var row=CGRect.zero;var keyboard:CGFloat=0
 init(web:WKWebView){super.init();self.web=web
 let effect=UIGlassEffect(style:.clear);effect.isInteractive=true;surface.effect=effect;surface.cornerConfiguration = .capsule()
 surface.accessibilityIdentifier="nativeLiquidGlassComposer"
 input.placeholder="Scrivi un messaggio";input.font = .systemFont(ofSize:16);input.delegate=self;input.accessibilityLabel="Messaggio";input.returnKeyType = .send
 input.addTarget(self,action:#selector(changed),for:.editingChanged)
 for (b,symbol,label) in [(permissions,"slider.horizontal.3","Permessi azioni"),(photo,"plus","Invia foto"),(mic,"mic","Messaggio vocale"),(send,"arrow.up.circle.fill","Invia")]{b.setImage(UIImage(systemName:symbol),for:.normal);b.accessibilityLabel=label;b.tintColor = .label;b.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([b.widthAnchor.constraint(equalToConstant:44),b.heightAnchor.constraint(equalToConstant:44)])}
 permissions.addTarget(self,action:#selector(permission),for:.touchUpInside)
 photo.addTarget(self,action:#selector(pick),for:.touchUpInside);mic.addTarget(self,action:#selector(record),for:.touchUpInside);send.addTarget(self,action:#selector(submit),for:.touchUpInside)
 let stack=UIStackView(arrangedSubviews:[photo,permissions,input,mic,send]);stack.spacing=4;stack.alignment = .center;stack.translatesAutoresizingMaskIntoConstraints=false;surface.contentView.addSubview(stack)
 NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:surface.contentView.leadingAnchor,constant:5),stack.trailingAnchor.constraint(equalTo:surface.contentView.trailingAnchor,constant:-5),stack.topAnchor.constraint(equalTo:surface.contentView.topAnchor,constant:5),stack.bottomAnchor.constraint(equalTo:surface.contentView.bottomAnchor,constant:-5)])
 web.addSubview(surface);surface.isHidden=true
 NotificationCenter.default.addObserver(self,selector:#selector(keyboardChanged(_:)),name:UIResponder.keyboardWillChangeFrameNotification,object:nil)
 }
 func sync(_ b:[String:Any]){guard let web=web else{return};let show=(b["show"] as? Bool ?? false) && (b["w"] as? CGFloat ?? 0)>100 && (b["y"] as? CGFloat ?? 0)>web.safeAreaInsets.top
 if !show{surface.isHidden=true;input.resignFirstResponder();mode="";return}
 let m=b["mode"] as? String ?? "",a=b["account"] as? String ?? ""
 if mode != m || account != a{input.resignFirstResponder();mode=m;account=a;input.text=b["value"] as? String ?? ""}
 let value=b["value"] as? String ?? "";if value != remote{input.text=value;remote=value}
 mic.setImage(UIImage(systemName:(b["recording"] as? Bool ?? false) ? "stop.circle.fill":"mic"),for:.normal);mic.tintColor=(b["recording"] as? Bool ?? false) ? .systemRed:.label;mic.isHidden=m != "friend";permissions.isHidden=m != "ai";photo.accessibilityLabel=m=="friend" ? "Invia foto":"Aggiungi foto";surface.isHidden=false
 surface.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;input.textColor = .label
 row=CGRect(x:(b["x"] as? CGFloat ?? 10),y:(b["y"] as? CGFloat ?? 0),width:(b["w"] as? CGFloat ?? web.bounds.width-20),height:56);layout()
 }
 func layout(){guard let web=web else{return};var r=row;if keyboard>0{r.origin.y=min(r.origin.y,web.bounds.height-keyboard-64)};surface.frame=r;web.bringSubviewToFront(surface)}
 @objc func keyboardChanged(_ n:Notification){guard let web=web,let frame=n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else{return};let f=web.convert(frame,from:nil);keyboard=max(0,web.bounds.maxY-f.minY);layout()}
 func script(_ s:String){web?.evaluateJavaScript(s,completionHandler:nil)}
 func quoted(_ s:String)->String{String(data:try! JSONSerialization.data(withJSONObject:[s]),encoding:.utf8)!.dropFirst().dropLast().description}
 @objc func changed(){let text=String((input.text ?? "").prefix(mode=="friend" ? 4000:1500));if input.text != text{input.text=text};remote=text;script("window.__nativeComposerInput&&__nativeComposerInput("+quoted(mode)+","+quoted(text)+","+quoted(account)+")")}
 @objc func permission(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'permissions',"+quoted(account)+")")}
 var pickerOwner="",pickerMode="";weak var activePicker:PHPickerViewController?
 @objc func pick(){guard let web=web,var controller=web.window?.rootViewController else{return};while let presented=controller.presentedViewController{controller=presented};pickerOwner=account;pickerMode=mode;var config=PHPickerConfiguration();config.filter = .images;config.selectionLimit=1;let picker=PHPickerViewController(configuration:config);picker.delegate=self;activePicker=picker;controller.present(picker,animated:true)}
 func picker(_ picker:PHPickerViewController,didFinishPicking results:[PHPickerResult]){picker.dismiss(animated:true);guard let provider=results.first?.itemProvider,provider.canLoadObject(ofClass:UIImage.self) else{return};consumeImageProvider(provider)
 }
 func consumeImageProvider(_ provider:NSItemProvider){let owner=pickerOwner,m=pickerMode
 provider.loadObject(ofClass:UIImage.self){[weak self] image,_ in guard let self=self,let img=image as? UIImage else{return};let ratio=min(1,1600/max(img.size.width,img.size.height));let size=CGSize(width:img.size.width*ratio,height:img.size.height*ratio);let resized=UIGraphicsImageRenderer(size:size).image{_ in img.draw(in:CGRect(origin:.zero,size:size))};guard let data=resized.jpegData(compressionQuality:0.75) else{return};DispatchQueue.main.async{guard self.account==owner,self.mode==m else{return};self.script("window.__nativeComposerPhoto&&__nativeComposerPhoto("+self.quoted(m)+","+self.quoted(owner)+","+self.quoted(data.base64EncodedString())+")")}}
 }
 @objc func record(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'mic',"+quoted(account)+")")}
 @objc func submit(){guard !(input.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return};changed();script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'send',"+quoted(account)+")");input.text="";remote=""}
 func textFieldShouldReturn(_ textField:UITextField)->Bool{submit();return false}
}

@available(iOS 26.0, *)
final class NativeLensSegments:UISegmentedControl {
 var trackingEvent:((String,CGFloat)->Void)?
 override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool{let accepted=super.beginTracking(touch,with:event);if accepted{trackingEvent?("start",touch.location(in:self).x)};return accepted}
 override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool{let accepted=super.continueTracking(touch,with:event);trackingEvent?("move",touch.location(in:self).x);return accepted}
 override func endTracking(_ touch:UITouch?,with event:UIEvent?){super.endTracking(touch,with:event);trackingEvent?("end",touch?.location(in:self).x ?? 0)}
 override func cancelTracking(with event:UIEvent?){super.cancelTracking(with:event);trackingEvent?("cancel",0)}
}
@available(iOS 26.0, *)
final class NativeGlassNavigation:NSObject,UIGestureRecognizerDelegate {
 weak var web:WKWebView?;let surface=NativeLensSegments(items:[]);let backdrop=UIVisualEffectView(effect:UIGlassEffect(style:.regular));var dragStart=0;var selected=0
 init(web:WKWebView){super.init();self.web=web;surface.accessibilityIdentifier="nativeLiquidGlassNavigation"
 for(i,item)in [("house","Home"),("chart.bar","Voti"),("bubble.left.and.bubble.right","Chat"),("mappin","Mappa"),("person.crop.circle","Profilo")].enumerated(){
 let image=UIGraphicsImageRenderer(size:CGSize(width:60,height:46)).image{_ in
 UIImage(systemName:item.0,withConfiguration:UIImage.SymbolConfiguration(pointSize:22,weight:.regular))?.withTintColor(.white,renderingMode:.alwaysOriginal).draw(in:CGRect(x:17,y:0,width:26,height:26))
 let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:10,weight:.semibold),.foregroundColor:UIColor.white];let text=item.1 as NSString;let size=text.size(withAttributes:attrs);text.draw(at:CGPoint(x:(60-size.width)/2,y:30),withAttributes:attrs)
 }.withRenderingMode(.alwaysTemplate)
 surface.insertSegment(with:image,at:i,animated:false);surface.accessibilityLabel="Navigazione"
 }
 backdrop.isUserInteractionEnabled=false;backdrop.cornerConfiguration = .capsule();backdrop.clipsToBounds=false;web.addSubview(backdrop);backdrop.isHidden=true
 surface.trackingEvent={[weak self] phase,x in guard let self=self else{return};if phase=="start"{self.dragStart=self.selected}
 let position=max(0,min(4,x/(self.surface.bounds.width/5)-0.5)),delta=(CGFloat(self.dragStart)-position)*(self.web?.bounds.width ?? 390)*0.25
 if phase=="cancel"{self.web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(self.dragStart))",completionHandler:nil);return}
 if phase=="end"{self.web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(max(0,self.surface.selectedSegmentIndex)))",completionHandler:nil);return}
 self.web?.evaluateJavaScript("window.__nativeNavDrag&&__nativeNavDrag('\(phase)',\(delta))",completionHandler:nil)
 }
 let observer=UILongPressGestureRecognizer(target:self,action:#selector(observeDrag(_:)));observer.minimumPressDuration=0;observer.allowableMovement=10000;observer.cancelsTouchesInView=false;observer.delaysTouchesBegan=false;observer.delaysTouchesEnded=false;observer.delegate=self;surface.addGestureRecognizer(observer)
 surface.addTarget(self,action:#selector(changed),for:.valueChanged);web.addSubview(surface);surface.isHidden=true
 }
 func sync(_ b:[String:Any]){surface.isHidden = !(b["show"] as? Bool ?? false);backdrop.isHidden=surface.isHidden;if surface.isHidden{return};backdrop.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;surface.overrideUserInterfaceStyle=(b["dark"] as? Bool ?? false) ? .dark:.light;surface.frame=CGRect(x:b["x"] as? CGFloat ?? 10,y:b["y"] as? CGFloat ?? 0,width:b["w"] as? CGFloat ?? 300,height:64);backdrop.frame=surface.frame;backdrop.layer.cornerRadius=32;selected=b["selected"] as? Int ?? 0;if !surface.isTracking{surface.selectedSegmentIndex=selected}}
 func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer)->Bool{return true}
 @objc func observeDrag(_ g:UILongPressGestureRecognizer){let phase:String;switch g.state{case .began:phase="start";case .changed:phase="move";case .ended:phase="end";case .cancelled,.failed:phase="cancel";default:return};surface.trackingEvent?(phase,g.location(in:surface).x)}
 @objc func changed(){web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(surface.selectedSegmentIndex))",completionHandler:nil)}
}
