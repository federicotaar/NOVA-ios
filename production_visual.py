from pathlib import Path
s=Path('Sources/NOVA/NOVAApp.swift').read_text()
r=Path('ChatRegression.swift').read_text();fixture=r.split(' let fixture="""',1)[1].split('"""',1)[0]
fixture += '''
 const demoCanvas=document.createElement('canvas');demoCanvas.width=demoCanvas.height=64;const demoCtx=demoCanvas.getContext('2d');demoCtx.fillStyle='#6877ef';demoCtx.fillRect(0,0,64,64);demoCtx.fillStyle='#fff';demoCtx.font='bold 36px sans-serif';demoCtx.fillText('N',17,45);const demoAvatar=demoCanvas.toDataURL('image/png');const demoState=JSON.parse(localStorage.getItem('nova.v1'));demoState.prof.avatar=demoAvatar;localStorage.setItem('nova.v1',JSON.stringify(demoState));const oldDemoFetch=window.fetch;window.fetch=async(...args)=>{const res=await oldDemoFetch(...args),oldJson=res.json;res.json=async()=>{const j=await oldJson();if(j.friends)j.friends.forEach(f=>f.avatar=demoAvatar);return j};return res};
'''
s=s.replace('        let web = WKWebView(frame:', '        config.userContentController.addUserScript(WKUserScript(source:"""'+fixture+'""",injectionTime:.atDocumentStart,forMainFrameOnly:true))\n        let web = WKWebView(frame:',1)
s=s.replace('        return web\n', '''        visualProductionRun(web)
        return web
''',1)
s+='''
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
 DispatchQueue.main.asyncAfter(deadline:.now()+32){web.endEditing(true);web.evaluateJavaScript("convClose();pg(3)",completionHandler:nil)}
 DispatchQueue.main.asyncAfter(deadline:.now()+35){visualProductionSave(web,"production-map.png")}
}
func visualProductionSave(_ web:WKWebView,_ name:String){guard let window=web.window else{return};let image=UIGraphicsImageRenderer(bounds:window.bounds).image{_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)};let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? image.pngData()?.write(to:dir.appendingPathComponent(name));if name=="production-map.png"{try? Data().write(to:dir.appendingPathComponent("visual-done"))}}
'''
s=s.replace('iOS26.0','iOS 26.0');Path('/tmp/NOVAProductionVisual.swift').write_text(s)
