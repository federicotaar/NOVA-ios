from pathlib import Path
s=Path('Sources/NOVA/NOVAApp.swift').read_text()
r=Path('ChatRegression.swift').read_text();fixture=r.split(' let fixture="""',1)[1].split('"""',1)[0]
fixture += '''
 window.testErrorDetails=[];window.addEventListener('error',e=>testErrorDetails.push({message:e.message,file:e.filename,line:e.lineno,column:e.colno}));const demoCanvas=document.createElement('canvas');demoCanvas.width=demoCanvas.height=64;const demoCtx=demoCanvas.getContext('2d');demoCtx.fillStyle='#6877ef';demoCtx.fillRect(0,0,64,64);demoCtx.fillStyle='#fff';demoCtx.font='bold 36px sans-serif';demoCtx.fillText('N',17,45);const demoAvatar=demoCanvas.toDataURL('image/png');const demoState=JSON.parse(localStorage.getItem('nova.v1'));demoState.prof.avatar=demoAvatar;demoState.tasks=[{id:'synthetic-task',title:'Synthetic homework',subj:'Maths',due:'2026-10-30T17:00',done:0}];localStorage.setItem('nova.v1',JSON.stringify(demoState));const oldDemoFetch=window.fetch;window.fetch=async(...args)=>{const res=await oldDemoFetch(...args),oldJson=res.json;res.json=async()=>{const j=await oldJson();if(j.friends)j.friends.forEach(f=>f.avatar=demoAvatar);if(j.chats)j.chats=[{id:'synthetic',type:'dm',title:'Example friend',avatar:demoAvatar,unread:0}];return j};return res};
'''
s=s.replace('        let web = WKWebView(frame:', '        config.userContentController.addUserScript(WKUserScript(source:"""'+fixture+'""",injectionTime:.atDocumentStart,forMainFrameOnly:true))\n        let web = WKWebView(frame:',1)
s=s.replace('        return web\n', '''        visualAssistantConfigReady(web,0)
        return web
''',1)
s+=r'''
#if DEBUG
#endif
func visualProductionRun(_ web:WKWebView){
 let steps:[(Double,String,String)]=[
 (8,"document.querySelectorAll('dialog[open]').forEach(d=>d.close());$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(2);","production-chat-list.png"),
 (10,"aiOpen();setTimeout(()=>$('#aiBack').click(),100);","production-ai-return.png"),
 (13,"pg(4);setTimeout(()=>window.scrollTo(0,450),100);","production-profile.png"),
 (18,"pg(2);convOpen(1,'Study group');","production-composer.png")]
 for(delay,script,name)in steps{DispatchQueue.main.asyncAfter(deadline:.now()+delay){web.evaluateJavaScript(script,completionHandler:nil);DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,name)}}}
 DispatchQueue.main.asyncAfter(deadline:.now()+23){if #available(iOS26.0,*){for v in web.subviews{if v.accessibilityIdentifier=="nativeLiquidGlassComposer"{for stack in (v as? UIVisualEffectView)?.contentView.subviews ?? []{for input in stack.subviews{if let field=input as? UITextField{field.text="Draft for our study plan";field.sendActions(for:.editingChanged);field.becomeFirstResponder()}}}}}}}
 DispatchQueue.main.asyncAfter(deadline:.now()+28){visualProductionSave(web,"production-keyboard.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+32){web.endEditing(true);web.evaluateJavaScript("try{convClose()}catch(e){testErrors.push(String(e))};document.querySelectorAll('dialog[open]').forEach(d=>d.close());document.body.classList.remove('ovl');$('#conv').hidden=true;pg(3);JSON.stringify({page:pgI,conv:$('#conv').hidden,errors:testErrors})"){v,e in print("MAP_VISUAL_STATE",v ?? "nil",e ?? "nil")}}
 DispatchQueue.main.asyncAfter(deadline:.now()+35){visualProductionSave(web,"production-map.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+36){web.evaluateJavaScript("toast(\"Condivisione spenta sul server\")",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+37){visualProductionSave(web,"production-centered-notice.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+43){web.evaluateJavaScript("pg(4);$('#bSet').click()",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+47){visualProductionSave(web,"production-settings-top.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+48){web.evaluateJavaScript("(()=>{let el=$$('.settingsSection')[1],scroll=$('.settingsScroll');scroll.scrollTop=el.offsetTop-scroll.offsetTop})()",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+51){visualProductionSave(web,"production-settings-appearance.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+53){web.evaluateJavaScript("(()=>{let el=$$('.settingsSection')[4],scroll=$('.settingsScroll');scroll.scrollTop=el.offsetTop-scroll.offsetTop})()",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+56){visualProductionSave(web,"production-settings-privacy.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+58){web.evaluateJavaScript("$('#dSet').close();pg(0)",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+61){visualProductionSave(web,"production-home-glass.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+63){web.evaluateJavaScript("openTT()",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+66){visualProductionSave(web,"production-chips.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+68){web.evaluateJavaScript("document.querySelectorAll('dialog[open]').forEach(d=>d.close());pg(2);convOpen(1,'Study group')",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+71){web.evaluateJavaScript("cvActSheet(cvMsgs[0]?.id);JSON.stringify({messages:cvMsgs.length,first:cvMsgs[0]?.id,hidden:$('#cvAct').hidden,buttons:$('#cvAct').querySelectorAll('button').length,rect:$('#cvAct').getBoundingClientRect().toJSON()})"){v,e in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:v ?? e).write(to:dir.appendingPathComponent("reaction-state.txt"),atomically:true,encoding:.utf8);DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-reactions.png")}}}

 DispatchQueue.main.asyncAfter(deadline:.now()+74){web.evaluateJavaScript("document.querySelectorAll('dialog[open]').forEach(d=>d.close());document.querySelector('#cvAct').hidden=true;convClose();pg(0)",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+77){visualProductionSave(web,"production-task-controls.png")}
 DispatchQueue.main.asyncAfter(deadline:.now()+80){web.evaluateJavaScript("pg(1)",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+83){visualProductionSave(web,"production-grades-glass.png")}
}
func visualProductionSave(_ web:WKWebView,_ name:String){guard let window=web.window else{return};let image=UIGraphicsImageRenderer(bounds:window.bounds).image{_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)};let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? image.pngData()?.write(to:dir.appendingPathComponent(name));if name=="production-grades-glass.png"{web.evaluateJavaScript("JSON.stringify({errors:testErrors,bodyError:document.querySelector('#errB')?.textContent})"){v,e in try? String(describing:v).write(to:dir.appendingPathComponent("visual-errors.txt"),atomically:true,encoding:.utf8)};try? Data().write(to:dir.appendingPathComponent("visual-done"))}}
'''
s=s.replace('iOS26.0','iOS 26.0');Path('/tmp/NOVAProductionVisual.swift').write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
x=p.read_text()+r"""
func visualReactionRun(_ web:WKWebView){
 DispatchQueue.main.asyncAfter(deadline:.now()+8){web.evaluateJavaScript("document.querySelectorAll('dialog[open]').forEach(d=>d.close());$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(2);convOpen(1,'Study group')",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+14){web.evaluateJavaScript("cvActSheet(cvMsgs[0]?.id);JSON.stringify({messages:cvMsgs.length,first:cvMsgs[0]?.id,hidden:$('#cvAct').hidden,buttons:$('#cvAct').querySelectorAll('button').length})"){v,e in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:v ?? e).write(to:dir.appendingPathComponent("reaction-state.txt"),atomically:true,encoding:.utf8)}}
 DispatchQueue.main.asyncAfter(deadline:.now()+20){visualProductionSave(web,"production-reactions.png");let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];web.evaluateJavaScript("JSON.stringify({errors:testErrors,actions:$('#cvAct').hidden,bodyError:document.querySelector('#errB')?.textContent})"){v,e in try? String(describing:v).write(to:dir.appendingPathComponent("visual-errors.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}
}
"""
p.write_text(x)

p=Path('/tmp/NOVAProductionVisual.swift')
x=p.read_text()+r"""
func visualOnboardingRun(_ web:WKWebView){visualOnboardingReady(web,0)}
func visualOnboardingReady(_ web:WKWebView,_ attempt:Int){
 web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualOnboardingReady(web,attempt+1)}};return};web.evaluateJavaScript("document.querySelectorAll('dialog[open]').forEach(d=>d.close());$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');delete S.acct;S.prof={username:'',avatar:''};S.done=0;S.ob=0;obStart();JSON.stringify({hidden:$('#ob').hidden,account:!!S.acct})"){v,e in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:v ?? e).write(to:dir.appendingPathComponent("onboarding-init.txt"),atomically:true,encoding:.utf8);visualOnboardingPage(web,0)}}
}
func visualOnboardingPage(_ web:WKWebView,_ page:Int){
 if page>15{web.evaluateJavaScript("$('#oDone').click();JSON.stringify({errors:testErrors,done:S.done,ob:S.ob,hidden:$('#ob').hidden,account:!!S.acct,faceId:!!S.faceId})"){v,e in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:v ?? e).write(to:dir.appendingPathComponent("onboarding-state.txt"),atomically:true,encoding:.utf8);DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-after-onboarding.png");web.evaluateJavaScript("JSON.stringify({errors:testErrors,details:testErrorDetails})"){v,e in try? String(describing:v).write(to:dir.appendingPathComponent("visual-errors.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}};return}
 web.evaluateJavaScript("obI="+String(page)+";obDraw()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-onboarding-"+String(page)+".png");visualOnboardingPage(web,page+1)}}
}
"""
p.write_text(x)

p=Path('/tmp/NOVAProductionVisual.swift')
x=p.read_text()+r"""
func visualAssistantConfigReady(_ web:WKWebView,_ attempt:Int){
 web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualAssistantConfigReady(web,attempt+1)}};return};web.evaluateJavaScript("document.querySelectorAll('dialog[open]').forEach(d=>d.close());$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(2);$('#aiMD').click();JSON.stringify({errors:testErrors})"){v,e in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-assistant-config.png");let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];web.evaluateJavaScript("JSON.stringify({errors:testErrors,details:testErrorDetails,dialog:$('#dMD').open,inputHidden:$('#mdF').hidden,accept:$('#mdF').accept,handler:typeof $('#mdF').onchange,focus:document.activeElement.id,viewport:{scale:visualViewport.scale,height:visualViewport.height},dialogRect:$('#dMD').getBoundingClientRect().toJSON()})"){v,e in try? String(describing:v ?? e).write(to:dir.appendingPathComponent("visual-errors.txt"),atomically:true,encoding:.utf8);web.evaluateJavaScript("$('#mdT').focus()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-assistant-editing.png");web.evaluateJavaScript("JSON.stringify({scale:visualViewport.scale,top:visualViewport.pageTop,height:visualViewport.height,dialog:$('#dMD').getBoundingClientRect().toJSON(),focus:document.activeElement.id})"){v,e in try? String(describing:v ?? e).write(to:dir.appendingPathComponent("editing-state.txt"),atomically:true,encoding:.utf8)};try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}}
}
"""
p.write_text(x)
