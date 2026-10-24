import UIKit
import WebKit
@main final class ChatTestApp: UIResponder, UIApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler {
 var window:UIWindow?;var web:WKWebView!
 func application(_ application:UIApplication,didFinishLaunchingWithOptions:[UIApplication.LaunchOptionsKey:Any]?)->Bool{
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
 let v=UIViewController();v.view=web;window=UIWindow(frame:UIScreen.main.bounds);window?.rootViewController=v;window?.makeKeyAndVisible()
 let u=Bundle.main.url(forResource:"nova",withExtension:"html")!;web.loadFileURL(u,allowingReadAccessTo:u.deletingLastPathComponent());return true
 }
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){DispatchQueue.main.asyncAfter(deadline:.now()+2){
 let test="""
 (async()=>{try{
 document.querySelectorAll('dialog[open]').forEach(d=>d.close());if($('#intro'))$('#intro').remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(2);convOpen(1,'Synthetic chat');
 await new Promise(r=>setTimeout(r,300));$('#cvI').value='Synthetic message';$('#cvI').dispatchEvent(new Event('input'));$('#cvI').dispatchEvent(new Event('input'));if(testTyping.length!==1)throw Error('typing throttle');$('#cvS').click();await new Promise(r=>setTimeout(r,300));
 convClose();convOpen(2,'Synthetic second chat');$('#cvI').value='Second fixture';$('#cvI').dispatchEvent(new Event('input'));if(testTyping.length!==2)throw Error('typing reset');
 if(testSent.length!==1||testSent[0].body!=='Synthetic message')throw Error('send');if(testErrors.length||$('#errB'))throw Error('JS runtime errors');
 webkit.messageHandlers.result.postMessage({ok:true,typing:testTyping.length,sent:testSent.length,errors:testErrors,build:document.body.innerText.includes('2026.10.24.6')});
 }catch(e){webkit.messageHandlers.result.postMessage({ok:false,error:String(e),errors:testErrors})}})();
 """
 self.web.evaluateJavaScript(test,completionHandler:nil)
 }}
 func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage){
 let u=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("regression.json")
 if let d=try? JSONSerialization.data(withJSONObject:message.body,options:[.prettyPrinted]){try? d.write(to:u)}
 }
}
