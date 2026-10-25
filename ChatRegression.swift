import UIKit
import WebKit
import ObjectiveC.runtime
@main final class ChatTestApp: UIResponder, UIApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler {
 var window:UIWindow?;var web:WKWebView!;var composer:AnyObject?;var glassNav:AnyObject?
 func application(_ application:UIApplication,didFinishLaunchingWithOptions:[UIApplication.LaunchOptionsKey:Any]?)->Bool{
 // Test-only: permit synthetic focus to display the real simulator keyboard.
 if let cls=NSClassFromString("WKContentView") {
 let sel=NSSelectorFromString("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:")
 if let method=class_getInstanceMethod(cls,sel){
 let imp=method_getImplementation(method)
 typealias Fn = @convention(c) (AnyObject,Selector,UnsafeRawPointer,Bool,Bool,UInt,AnyObject?)->Void
 let original=unsafeBitCast(imp,to:Fn.self)
 let block:@convention(block) (AnyObject,UnsafeRawPointer,Bool,Bool,UInt,AnyObject?)->Void = { object,info,_,blur,changes,user in original(object,sel,info,true,blur,changes,user) }
 method_setImplementation(method,imp_implementationWithBlock(block))
 }
 }
 let c=WKWebViewConfiguration();c.userContentController.add(self,name:"result")
 let fixture="""
 localStorage.setItem('nova.v1',JSON.stringify({introOff:1,ob:2,done:1,profDone:1,name:'Synthetic',acct:{token:'fixture-only',email:'me@test.invalid'},prof:{username:'fixture'},w:{wx:0}}));
 window.testErrors=[];window.testTyping=[];window.testSent=[];
 window.addEventListener('error',e=>testErrors.push(e.message||'error'));
 window.fetch=async(url,opt={})=>{url=String(url);let method=opt.method||'GET',j={ok:true,profile:null,friends:[],incoming:[],outgoing:[],chats:[],typing:[]};
 if(url.includes('/typing')&&method==='POST')testTyping.push(url);
 if(url.includes('/messages')){if(method==='POST')testSent.push(JSON.parse(opt.body||'{}'));j={ok:true,messages:[{id:1,sender:'friend@test.invalid',kind:'text',body:'Synthetic hello'},{id:2,sender:'me@test.invalid',kind:'text',body:'Synthetic reply'}],senders:{'friend@test.invalid':'Example'},reactions:{}}}return {ok:true,status:200,json:async()=>j};};
 """
 c.userContentController.addUserScript(WKUserScript(source:fixture,injectionTime:.atDocumentStart,forMainFrameOnly:true))
 web=WKWebView(frame:.zero,configuration:c);web.navigationDelegate=self
 if #available(iOS 26.0, *) { composer=NativeGlassComposer(web:web);glassNav=NativeGlassNavigation(web:web) }
 let v=UIViewController();v.view=web;window=UIWindow(frame:UIScreen.main.bounds);window?.rootViewController=v;window?.makeKeyAndVisible()
 let u=Bundle.main.url(forResource:"nova",withExtension:"html")!;web.loadFileURL(u,allowingReadAccessTo:u.deletingLastPathComponent());return true
 }
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){DispatchQueue.main.asyncAfter(deadline:.now()+2){
 let test="""
 (async()=>{try{
 document.querySelectorAll('dialog[open]').forEach(d=>d.close());if($('#intro'))$('#intro').remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(2);convOpen(1,'Synthetic chat');
 await new Promise(r=>setTimeout(r,300));$('#cvI').value='Synthetic message';$('#cvI').dispatchEvent(new Event('input'));$('#cvI').dispatchEvent(new Event('input'));if(testTyping.length!==1)throw Error('typing throttle');$('#cvS').click();await new Promise(r=>setTimeout(r,300));
 convClose();convOpen(2,'Synthetic second chat');$('#cvI').value='Second fixture';$('#cvI').dispatchEvent(new Event('input'));if(testTyping.length!==2)throw Error('typing reset');
 if(getComputedStyle(document.documentElement).touchAction!=='manipulation')throw Error('global touch policy');
 for(const sel of ['#cvI','#ai']){const f=$(sel);if(parseFloat(getComputedStyle(f).fontSize)<16)throw Error('input focus zoom font '+sel);f.focus();if(visualViewport&&Math.abs(visualViewport.scale-1)>.01)throw Error('native focus scale '+sel);f.blur()}
 if(document.querySelector('meta[name=viewport]').content.includes('user-scalable=no'))throw Error('pinch disabled');
 if(testSent.length!==1||testSent[0].body!=='Synthetic message')throw Error('send');if(testErrors.length||$('#errB'))throw Error('JS runtime errors');
 $('#cvI').value='Synthetic glass draft';$('#cvI').focus();await new Promise(r=>setTimeout(r,2000));const rect=$('#cvI').getBoundingClientRect();if(rect.bottom>visualViewport.height+visualViewport.offsetTop+2)throw Error('composer below keyboard');webkit.messageHandlers.result.postMessage({ok:true,composer:{bottom:rect.bottom,viewport:visualViewport.height,focused:document.activeElement.id},typing:testTyping.length,sent:testSent.length,errors:testErrors,zoom:{scale:visualViewport.scale,inputFont:getComputedStyle($('#cvI')).fontSize,touch:getComputedStyle(document.documentElement).touchAction},build:document.body.innerText.includes('2026.10.24.6')});
 }catch(e){webkit.messageHandlers.result.postMessage({ok:false,error:String(e),errors:testErrors})}})();
 """
 self.web.evaluateJavaScript(test,completionHandler:{_,_ in
 if #available(iOS 26.0, *), let native=self.composer as? NativeGlassComposer {
 native.sync(["show":true,"mode":"friend","account":"fixture","value":"Genuine native Liquid Glass","x":10.0,"y":self.web.bounds.height-110,"w":self.web.bounds.width-20]);native.input.becomeFirstResponder()
 if let nav=self.glassNav as? NativeGlassNavigation { nav.sync(["show":true,"selected":2,"x":10.0,"y":self.web.bounds.height-200,"w":self.web.bounds.width-20]) }
 }
 })
 }}
 func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage){
 let u=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("regression.json")
 if let d=try? JSONSerialization.data(withJSONObject:message.body,options:[.prettyPrinted]){try? d.write(to:u)}
 }
}
// Native iOS26 Liquid Glass message control; older versions keep the web composer.
@available(iOS 26.0, *)
final class NativeGlassComposer: NSObject, UITextFieldDelegate {
 weak var web: WKWebView?
 let surface=UIVisualEffectView(effect: UIGlassEffect())
 let permissions=UIButton(type:.system)
 let photo=UIButton(type:.system), mic=UIButton(type:.system), send=UIButton(type:.system), input=UITextField()
 var mode="", account="", remote="";var row=CGRect.zero;var keyboard:CGFloat=0
 init(web:WKWebView){super.init();self.web=web
 let effect=UIGlassEffect();effect.isInteractive=true;surface.effect=effect;surface.layer.cornerRadius=28;surface.clipsToBounds=true
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
 func sync(_ b:[String:Any]){guard let web=web else{return};let show=b["show"] as? Bool ?? false
 if !show{surface.isHidden=true;input.resignFirstResponder();mode="";return}
 let m=b["mode"] as? String ?? "",a=b["account"] as? String ?? ""
 if mode != m || account != a{input.resignFirstResponder();mode=m;account=a;input.text=b["value"] as? String ?? ""}
 let value=b["value"] as? String ?? "";if value != remote{input.text=value;remote=value}
 mic.isHidden=m != "friend";permissions.isHidden=m != "ai";photo.accessibilityLabel=m=="friend" ? "Invia foto":"Aggiungi foto";surface.isHidden=false
 row=CGRect(x:(b["x"] as? CGFloat ?? 10),y:(b["y"] as? CGFloat ?? 0),width:(b["w"] as? CGFloat ?? web.bounds.width-20),height:56);layout()
 }
 func layout(){guard let web=web else{return};var r=row;if keyboard>0{r.origin.y=min(r.origin.y,web.bounds.height-keyboard-64)};surface.frame=r;web.bringSubviewToFront(surface)}
 @objc func keyboardChanged(_ n:Notification){guard let web=web,let frame=n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else{return};let f=web.convert(frame,from:nil);keyboard=max(0,web.bounds.maxY-f.minY);layout()}
 func script(_ s:String){web?.evaluateJavaScript(s,completionHandler:nil)}
 func quoted(_ s:String)->String{String(data:try! JSONSerialization.data(withJSONObject:[s]),encoding:.utf8)!.dropFirst().dropLast().description}
 @objc func changed(){let text=String((input.text ?? "").prefix(mode=="friend" ? 4000:1500));if input.text != text{input.text=text};remote=text;script("window.__nativeComposerInput&&__nativeComposerInput("+quoted(mode)+","+quoted(text)+")")}
 @objc func permission(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'permissions',"+quoted(account)+")")}
 @objc func pick(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'photo',"+quoted(account)+")")}
 @objc func record(){script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'mic',"+quoted(account)+")")}
 @objc func submit(){changed();script("window.__nativeComposerAction&&__nativeComposerAction("+quoted(mode)+",'send',"+quoted(account)+")")}
 func textFieldShouldReturn(_ textField:UITextField)->Bool{submit();return false}
}

@available(iOS 26.0, *)
final class NativeGlassNavigation:NSObject {
 weak var web:WKWebView?;let surface=UIVisualEffectView(effect:UIGlassEffect());var buttons:[UIButton]=[];let highlight=UIVisualEffectView(effect:UIGlassEffect());var selected=0
 init(web:WKWebView){super.init();self.web=web;let effect=UIGlassEffect();effect.isInteractive=true;surface.effect=effect;surface.layer.cornerRadius=32;surface.clipsToBounds=true;surface.accessibilityIdentifier="nativeLiquidGlassNavigation";web.addSubview(surface);surface.isHidden=true
 surface.contentView.addSubview(highlight);highlight.isUserInteractionEnabled=false;highlight.layer.cornerRadius=25;highlight.clipsToBounds=true
 for (i,item) in [("house","Home"),("chart.bar","Voti"),("bubble.left.and.bubble.right","Chat"),("mappin","Mappa"),("person.crop.circle","Profilo")].enumerated(){let b=UIButton(type:.system);b.tag=i;b.setImage(UIImage(systemName:item.0),for:.normal);b.accessibilityLabel=item.1;b.addTarget(self,action:#selector(tap(_:)),for:.touchUpInside);surface.contentView.addSubview(b);buttons.append(b)}
 surface.addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(pan(_:))))
 }
 func sync(_ b:[String:Any]){surface.isHidden = !(b["show"] as? Bool ?? false);if surface.isHidden{return};surface.frame=CGRect(x:b["x"] as? CGFloat ?? 10,y:b["y"] as? CGFloat ?? 0,width:b["w"] as? CGFloat ?? 300,height:64);selected=b["selected"] as? Int ?? 0
 let width=(surface.bounds.width-12)/5
 for(i,button)in buttons.enumerated(){button.frame=CGRect(x:6+CGFloat(i)*width,y:7,width:width,height:50);button.tintColor = .label;button.accessibilityTraits = i==selected ? [.button,.selected]:[.button]}
 highlight.frame=buttons[max(0,min(4,selected))].frame
 }
 @objc func tap(_ button:UIButton){web?.evaluateJavaScript("window.__nativeNavSelect&&__nativeNavSelect(\(button.tag))",completionHandler:nil)}
 @objc func pan(_ g:UIPanGestureRecognizer){let dx=g.translation(in:surface).x;let phase=g.state == .began ? "start":g.state == .ended || g.state == .cancelled ? "end":"move";web?.evaluateJavaScript("window.__nativeNavDrag&&__nativeNavDrag('\(phase)',\(dx))",completionHandler:nil)}
}
