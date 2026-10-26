from pathlib import Path
s=Path('Sources/NOVA/NOVAApp.swift').read_text()+chr(10)+chr(10).join(p.read_text() for p in sorted(Path('Sources/NOVA').glob('*.swift')) if p.name!='NOVAApp.swift')
h=Path('Sources/NOVA/nova.html');html=h.read_text();html=html.replace(' const syncNative=()=>{syncDashboard();syncGlassButtons();', ' window.__settingsTestKeys=()=>({fields:nativeFields,epoch:settingsEpoch,sync:syncNative,dashboardFields,dashboardEpoch});const syncNative=()=>{syncDashboard();syncGlassButtons();');h.write_text(html)
r=Path('ChatRegression.swift').read_text();fixture=r.split(' let fixture="""',1)[1].split('"""',1)[0]
fixture += '''
 window.testErrorDetails=[];window.addEventListener('error',e=>testErrorDetails.push({message:e.message,file:e.filename,line:e.lineno,column:e.colno}));const demoCanvas=document.createElement('canvas');demoCanvas.width=demoCanvas.height=64;const demoCtx=demoCanvas.getContext('2d');demoCtx.fillStyle='#6877ef';demoCtx.fillRect(0,0,64,64);demoCtx.fillStyle='#fff';demoCtx.font='bold 36px sans-serif';demoCtx.fillText('N',17,45);const demoAvatar=demoCanvas.toDataURL('image/png');const demoState=JSON.parse(localStorage.getItem('nova.v1'));demoState.prof.avatar=demoAvatar;demoState.tasks=[{id:'synthetic-task',title:'Synthetic homework',subj:'Maths',due:'2026-10-30T17:00',done:0}];localStorage.setItem('nova.v1',JSON.stringify(demoState));const oldDemoFetch=window.fetch;window.fetch=async(...args)=>{const res=await oldDemoFetch(...args),oldJson=res.json;res.json=async()=>{const j=await oldJson();if(j.friends)j.friends.forEach(f=>f.avatar=demoAvatar);if(j.chats)j.chats=[{id:'synthetic',type:'dm',title:'Example friend',avatar:demoAvatar,unread:0}];return j};return res};
'''
s=s.replace('        let web = WKWebView(frame:', '        config.userContentController.addUserScript(WKUserScript(source:"""'+fixture+'""",injectionTime:.atDocumentStart,forMainFrameOnly:true))\n        let web = WKWebView(frame:',1)
s=s.replace('        return web\n', '''        visualNativeProfileReady(web,0)
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
func visualProductionSave(_ web:WKWebView,_ name:String){guard let window=web.window ?? UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow}) else{return};let image=UIGraphicsImageRenderer(bounds:window.bounds).image{_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)};let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? image.pngData()?.write(to:dir.appendingPathComponent(name));if name=="production-grades-glass.png"{web.evaluateJavaScript("JSON.stringify({errors:testErrors,bodyError:document.querySelector('#errB')?.textContent})"){v,e in try? String(describing:v).write(to:dir.appendingPathComponent("visual-errors.txt"),atomically:true,encoding:.utf8)};try? Data().write(to:dir.appendingPathComponent("visual-done"))}}
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

p=Path('/tmp/NOVAProductionVisual.swift')
x=p.read_text()+r"""
func visualNativeSettingsReady(_ web:WKWebView,_ attempt:Int){
 web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualNativeSettingsReady(web,attempt+1)}};return};web.evaluateJavaScript("$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(4);$('#bSet').click()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-native-settings-top.png");if #available(iOS 26.0, *){visualNativeSettingsCheck(web)}}}}
}
@available(iOS 26.0, *)
func visualNativeSettingsCheck(_ web:WKWebView){
 let window=web.window ?? UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow});guard let nav=window?.rootViewController?.presentedViewController as? UINavigationController,let page=nav.topViewController as? NativeSettingsPage else{return}
 if let section=page.groups.firstIndex(where:{($0["title"] as? String ?? "").hasPrefix("Aspetto e schermata Home")}){page.tableView.scrollToRow(at:IndexPath(row:0,section:section),at:.top,animated:false)}
 DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-native-settings-appearance.png");let rows=page.groups.enumerated().flatMap{section,g in (g["rows"] as? [[String:Any]] ?? []).enumerated().map{(section,$0.offset,$0.element)}};if let intro=rows.first(where:{($0.2["label"] as? String ?? "").hasPrefix("Intro all'")}){let path=IndexPath(row:intro.1,section:intro.0);page.tableView.scrollToRow(at:path,at:.middle,animated:false);page.tableView.layoutIfNeeded();if let control=page.tableView.cellForRow(at:path)?.accessoryView as? UISwitch{control.setOn(!control.isOn,animated:false);control.sendActions(for:.valueChanged)}}
 DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-native-settings-toggled.png");if page.groups.count>3{page.tableView.scrollToRow(at:IndexPath(row:0,section:page.groups.count-2),at:.top,animated:false)};DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-native-settings-privacy.png");let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];web.evaluateJavaScript("JSON.stringify({errors:testErrors,details:testErrorDetails,introOff:S.introOff,settingsOpen:$('#dSet').open,profile:S.prof.username,account:S.acct?.email})"){v,e in try? String(describing:v ?? e).write(to:dir.appendingPathComponent("visual-errors.txt"),atomically:true,encoding:.utf8);visualNativeSettingsFunctional(web,page,dir)}}}
 }
}
"""
p.write_text(x)

p=Path('/tmp/NOVAProductionVisual.swift')
x=p.read_text()+r'''
@available(iOS 26.0, *)
func visualNativeSettingsFunctional(_ web:WKWebView,_ page:NativeSettingsPage,_ dir:URL){
 let script="""
 (async()=>{const report={};const keyFor=q=>{const e=$(q);return [...__settingsTestKeys().fields.entries()].find(([k,v])=>v===e)?.[0]};const owner=S.acct?.email||'',epoch=__settingsTestKeys().epoch;
 const nameKey=keyFor('#fN'),introKey=keyFor('#bIntro');const start=S.introOff;await __nativeSettingsPageAction(introKey,String(!!S.introOff),'wrong@test.invalid',epoch);report.wrongOwnerBlocked=S.introOff===start;await __nativeSettingsPageAction(introKey,String(!!S.introOff),owner,epoch-1);report.oldEpochBlocked=S.introOff===start;
 await __nativeSettingsPageAction(nameKey,'Native field test',owner,epoch);report.nameSaved=S.name==='Native field test'&&JSON.parse(localStorage.getItem(K)).name==='Native field test';
 const widgetKey=keyFor('#settingsWidget_bat'),before=S.w.bat;await __nativeSettingsPageAction(widgetKey,String(!before),owner,epoch);report.widgetChanged=!!S.w.bat===!before;
 const oldHandler=$('#bIntro').onclick;$('#bIntro').onclick=async()=>{};await __nativeSettingsPageAction(introKey,String(!!S.introOff),owner,epoch);report.cancelPreserved=S.introOff===start;$('#bIntro').onclick=oldHandler;
 const profileKey=keyFor('#bProf');await __nativeSettingsPageAction(profileKey,null,owner,epoch);report.profileOpened=$('#dProf').open;const current=S.introOff;await __nativeSettingsPageAction(introKey,String(!!S.introOff),owner,epoch);report.coveredActionBlocked=S.introOff===current;$('#dProf').close();
 return JSON.stringify({...report,errors:testErrors,account:S.acct?.email,profile:S.prof.username,faceId:!!S.faceId})})()
 """
 web.callAsyncJavaScript("return await "+script,arguments:[:],in:nil,in:.page){result in try? String(describing:result).write(to:dir.appendingPathComponent("native-functional.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}
}
'''
p.write_text(x)

p=Path('/tmp/NOVAProductionVisual.swift')
p.write_text(p.read_text()+'func visualNativeProfileReady(_ web:WKWebView,_ attempt:Int){\n web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualNativeProfileReady(web,attempt+1)}};return};web.evaluateJavaScript("$(\'#intro\')?.remove();$(\'#ob\').hidden=true;document.body.classList.remove(\'ovl\');pg(4);$(\'#bSet\').click();$(\'#bProf\').click()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-native-profile-top.png");if #available(iOS 26.0, *){visualNativeProfileCheck(web)}}}}\n}\n@available(iOS 26.0, *)\nfunc visualNativeProfileCheck(_ web:WKWebView){\n let window=web.window ?? UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow});guard let nav=window?.rootViewController?.presentedViewController as? UINavigationController,let page=nav.topViewController as? NativeSettingsPage else{return}\n page.tableView.scrollToRow(at:IndexPath(row:0,section:page.groups.count-1),at:.bottom,animated:false)\n DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-native-profile-bottom.png");let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];let script="""\n return await(async()=>{const keyFor=q=>[...__settingsTestKeys().fields.entries()].find(([k,e])=>e===$(q))?.[0];const owner=S.acct?.email||\'\',epoch=__settingsTestKeys().epoch,original=JSON.stringify(S.prof),r={};await __nativeSettingsPageAction(keyFor(\'#dSt\'),\'Unsaved native draft\',owner,epoch);r.draftDoesNotSave=JSON.stringify(S.prof)===original;await __nativeSettingsPageAction(\'__close\',null,owner,epoch);r.cancelPreserves=JSON.stringify(S.prof)===original&&!$(\'#dProf\').open;profOpen(0);__settingsTestKeys().sync();const next=__settingsTestKeys().epoch;await __nativeSettingsPageAction(keyFor(\'#dU\'),\'bad space!\',owner,next);await __nativeSettingsPageAction(keyFor(\'#dOk\'),null,owner,next);r.invalidUsernameStaysOpen=$(\'#dProf\').open&&!!$(\'#dE\').textContent;r.invalidDoesNotSave=JSON.stringify(S.prof)===original;await __nativeSettingsPageAction(keyFor(\'#dU\'),\'fixture\',owner,next);await __nativeSettingsPageAction(keyFor(\'#dSt\'),\'Native school test\',owner,next);await __nativeSettingsPageAction(keyFor(\'#dOk\'),null,owner,next);r.validExplicitSave=S.prof.study===\'Native school test\'&&!$(\'#dProf\').open;return JSON.stringify({...r,errors:testErrors,profile:S.prof.username,account:S.acct?.email})})()\n """;web.callAsyncJavaScript(script,arguments:[:],in:nil,in:.page){result in try? String(describing:result).write(to:dir.appendingPathComponent("native-functional.txt"),atomically:true,encoding:.utf8);DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProfileExtras(web,page,dir)}}}\n}\n@available(iOS 26.0, *)\nfunc visualProfileExtras(_ web:WKWebView,_ page:NativeSettingsPage,_ dir:URL){\n web.evaluateJavaScript("profOpen(0);$(\'#dSoC\').click();$(\'#dSoL\')._rs=[{t:\'Synthetic song\',a:\'Fixture artist\',art:\'\',p:\'https://test.invalid/preview\'}];const el=document.createElement(\'div\');el.className=\'sngR\';el.textContent=\'Synthetic song - Fixture artist\';el.onclick=()=>{dTmp.song=$(\'#dSoL\')._rs[0];dSoDraw();$(\'#dSoS\').hidden=true};$(\'#dSoL\').appendChild(el);__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+2){\n func findPage(_ vc:UIViewController?)->NativeSettingsPage?{guard let vc=vc else{return nil};if let nav=vc as? UINavigationController,let page=nav.topViewController as? NativeSettingsPage{return page};if let p=findPage(vc.presentedViewController){return p};for child in vc.children{if let p=findPage(child){return p}};return nil};let roots=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.compactMap{$0.rootViewController};guard let page=roots.compactMap({findPage($0)}).first else{try? "missing native profile".write(to:dir.appendingPathComponent("profile-extras.txt"),atomically:true,encoding:.utf8);return}\n let rows=page.groups.enumerated().flatMap{section,g in (g["rows"] as? [[String:Any]] ?? []).enumerated().map{(section,$0.offset,$0.element)}};if let query=rows.first(where:{$0.2["label"] as? String=="Cerca canzone o artista"}){page.tableView.scrollToRow(at:IndexPath(row:query.1,section:query.0),at:.middle,animated:false)};visualProductionSave(web,"production-native-profile-song.png")\n if let query=rows.first(where:{$0.2["label"] as? String=="Cerca canzone o artista"}),let cell=page.tableView.cellForRow(at:IndexPath(row:query.1,section:query.0)),let field=cell.contentView.subviews.first(where:{$0 is UITextField}) as? UITextField{field.becomeFirstResponder();var body:[String:Any]=["page":"profile","canClose":true,"account":page.owner,"epoch":page.epoch,"revision":100];var groups=page.groups;var g=groups[query.0];var rs=g["rows"] as! [[String:Any]];if var item=rs.last{item["label"]="Synthetic song - Refreshed artist";rs[rs.count-1]=item};g["rows"]=rs;groups[query.0]=g;body["groups"]=groups;page.apply(body);try? "focusPreserved=\\(field.isFirstResponder),resultUpdated=\\(page.tableView.cellForRow(at:IndexPath(row:rs.count-1,section:query.0))?.textLabel?.text ?? "missing")".write(to:dir.appendingPathComponent("profile-focus.txt"),atomically:true,encoding:.utf8);visualProductionSave(web,"production-native-profile-song-focused.png");field.resignFirstResponder()}\n let picker=PHPickerViewController(configuration:PHPickerConfiguration());page.picker(picker,didFinishPicking:[])\n web.callAsyncJavaScript("return await(async()=>{const find=q=>[...__settingsTestKeys().fields.entries()].find(([k,e])=>e===$(q))?.[0];const owner=S.acct?.email||\'\',epoch=__settingsTestKeys().epoch,original=JSON.stringify(S.prof);await __nativeSettingsPageAction(find(\'#dSoL .sngR\'),null,owner,epoch);const r={songSelectedDraft:dTmp.song?.t===\'Synthetic song\',songNotSaved:JSON.stringify(S.prof)===original};__nativeProfilePhoto(\'ignored\',\'wrong@test.invalid\',epoch);r.wrongPhotoOwnerBlocked=!String(dTmp.avatar).includes(\'ignored\');await __nativeSettingsPageAction(\'__close\',null,owner,epoch);r.cancelSongPreserved=JSON.stringify(S.prof)===original;return JSON.stringify({...r,errors:testErrors})})()",arguments:[:],in:nil,in:.page){result in try? String(describing:result).write(to:dir.appendingPathComponent("profile-extras.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}\n }}\n}\n')

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('visualNativeProfileReady(web,0)','visualDeviceFixReady(web,0)')
s+=r'''
func visualProductionLightProfile(_ web:WKWebView,_ attempt:Int){web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionLightProfile(web,attempt+1)}};return};web.evaluateJavaScript("S.theme='light';theme();$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');pg(4);$('#bSet').click();$('#bProf').click();__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-profile-light.png");if #available(iOS 26.0, *){let bridge=web.configuration.userContentController;_ = bridge;web.evaluateJavaScript("$('#dSoC').click();__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-profile-light-search.png");let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];web.evaluateJavaScript("JSON.stringify({theme:S.theme,mode:__settingsTestKeys().epoch,errors:testErrors})"){v,e in try? String(describing:v ?? e).write(to:dir.appendingPathComponent("profile-light.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}}}}
'''
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
p.write_text(p.read_text()+'func visualNativeDashboardReady(_ web:WKWebView,_ attempt:Int){web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualNativeDashboardReady(web,attempt+1)}};return};web.evaluateJavaScript("$(\'#intro\')?.remove();$(\'#ob\').hidden=true;document.body.classList.remove(\'ovl\');S.w.wx=1;show();askCity(\'Scegli la città per il meteo.\');pg(0);__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-native-dashboard-top.png");if #available(iOS 26.0, *){let dashboard=web.subviews.first(where:{$0.accessibilityIdentifier=="nativeDashboard"}) as? UIScrollView;dashboard?.setContentOffset(CGPoint(x:0,y:560),animated:false);DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-native-dashboard-middle.png");dashboard?.setContentOffset(CGPoint(x:0,y:max(0,(dashboard?.contentSize.height ?? 0)-(dashboard?.bounds.height ?? 0))),animated:false);DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-native-dashboard-bottom.png");let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];web.callAsyncJavaScript("return await(async()=>{const r={},owner=S.acct?.email||\'\',original=S.tasks[0].done,find=q=>[...__settingsTestKeys().dashboardFields.entries()].find(([k,e])=>e===$(q))?.[0];const id=find(\'#tl [data-a=ck]\');await __nativeDashboardAction(id,null,\'wrong@test.invalid\',__settingsTestKeys().dashboardEpoch);r.wrongOwnerBlocked=S.tasks[0].done===original;await __nativeDashboardAction(id,null,owner,__settingsTestKeys().dashboardEpoch-1);r.oldEpochBlocked=S.tasks[0].done===original;await __nativeDashboardAction(id,null,owner,__settingsTestKeys().dashboardEpoch);r.taskCompleted=S.tasks[0].done!==original;$(\'#bSet\').click();await __nativeDashboardAction(id,null,owner,__settingsTestKeys().dashboardEpoch);r.coveredActionBlocked=S.tasks[0].done!==original;$(\'#dSet\').close();pg(1);await __nativeDashboardAction(id,null,owner,__settingsTestKeys().dashboardEpoch);r.wrongPageBlocked=S.tasks[0].done!==original;return JSON.stringify({...r,errors:testErrors})})()",arguments:[:],in:nil,in:.page){result in try? String(describing:result).write(to:dir.appendingPathComponent("dashboard-functional.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}}}}\n')

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text()+r'''
func visualNativeGradesReady(_ web:WKWebView,_ attempt:Int){web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualNativeGradesReady(web,attempt+1)}};return};web.evaluateJavaScript("$('#intro')?.remove();$('#ob').hidden=true;document.body.classList.remove('ovl');S.cv.on=1;S.gr=[{subj:'Matematica',v:5,d:'5',date:'2026-10-25'},{subj:'Matematica',v:7,d:'7',date:'2026-10-24'},{subj:'Italiano',v:8,d:'8',date:'2026-10-23'}];grades();pg(1);__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-native-grades.png");web.evaluateJavaScript("JSON.stringify({errors:testErrors,gradeCount:S.gr.length,expectedAverage:20/3})"){v,e in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:v ?? e).write(to:dir.appendingPathComponent("dashboard-functional.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}
'''
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('JSON.stringify({errors:testErrors,gradeCount:S.gr.length,expectedAverage:20/3})',"(()=>{const owner=S.acct?.email||'',key=[...__settingsTestKeys().dashboardFields.entries()].find(([k,e])=>e.id==='bSet')?.[0];__nativeDashboardAction(key,null,owner,__settingsTestKeys().dashboardEpoch);return JSON.stringify({errors:testErrors,gradeCount:S.gr.length,settingsOpened:$('#dSet').open})})()")
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
p.write_text(p.read_text()+'func visualNativeTaskReady(_ web:WKWebView,_ attempt:Int){web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualNativeTaskReady(web,attempt+1)}};return};web.evaluateJavaScript("$(\'#intro\')?.remove();$(\'#ob\').hidden=true;document.body.classList.remove(\'ovl\');newTask();__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-native-task.png");web.callAsyncJavaScript("return await(async()=>{const r={},owner=S.acct?.email||\'\',epoch=__settingsTestKeys().epoch,original=S.tasks.length,key=q=>[...__settingsTestKeys().fields.entries()].find(([k,e])=>e===$(q))?.[0];await __nativeSettingsPageAction(key(\'#tT\'),\'Native task fixture\',owner,epoch);await __nativeSettingsPageAction(key(\'#tN\'),\'A native multiline note\',owner,epoch);await __nativeSettingsPageAction(key(\'#tP\'),\'alta\',owner,epoch);await __nativeSettingsPageAction(key(\'#tR\'),\'10\',owner,epoch);r.draftNotSaved=S.tasks.length===original;await __nativeSettingsPageAction(key(\'#tS\'),null,owner,epoch);r.saved=S.tasks.length===original+1;r.values=S.tasks.at(-1).pr===\'alta\'&&S.tasks.at(-1).rem===10&&S.tasks.at(-1).note===\'A native multiline note\';newTask();__settingsTestKeys().sync();await __nativeSettingsPageAction(\'__close\',null,owner,__settingsTestKeys().epoch);r.cancelPreserved=S.tasks.length===original+1;return JSON.stringify({...r,errors:testErrors})})()",arguments:[:],in:nil,in:.page){result in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:result).write(to:dir.appendingPathComponent("dashboard-functional.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}\n')

p=Path('/tmp/NOVAProductionVisual.swift')
p.write_text(p.read_text()+'func visualDeviceFixReady(_ web:WKWebView,_ attempt:Int){web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualDeviceFixReady(web,attempt+1)}};return};web.evaluateJavaScript("$(\'#intro\')?.remove();$(\'#ob\').hidden=true;document.body.classList.remove(\'ovl\');sp.conn=true;sp.st={idle:true};spCard();S.tasks.push({id:\'synthetic-test\',title:\'Verifica Informatica: Diagrammi di flusso, concetto di variabile, selezione\',subj:\'Informatica\',due:\'2026-11-03T09:00\',done:0,kind:\'test\',src:\'cv\'});tasks();cal();nxt();pg(0);__novaBattery(-1,false);__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-device-fix-top.png");let dashboard=web.subviews.first(where:{$0.accessibilityIdentifier=="nativeDashboard"}) as? UIScrollView;dashboard?.setContentOffset(CGPoint(x:0,y:max(0,(dashboard?.contentSize.height ?? 0)-(dashboard?.bounds.height ?? 0))),animated:false);DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-device-fix-spotify.png");web.evaluateJavaScript("pg(4);__settingsTestKeys().sync();window.scrollTo(0,180)"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-device-fix-profile.png");web.evaluateJavaScript("JSON.stringify({errors:testErrors,standbyOff:S.sb===\'off\',standbyEntryHidden:$(\'#bSb\').hidden,decorativeNativeButtons:document.querySelectorAll(\'.nativeGlassButton\').length,batteryUnknown:$(\'#batB\').textContent,spotifyLabels:[...document.querySelectorAll(\'#spB button\')].map(e=>e.getAttribute(\'aria-label\'))})"){v,e in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:v ?? e).write(to:dir.appendingPathComponent("dashboard-functional.txt"),atomically:true,encoding:.utf8);web.evaluateJavaScript("openTT();ttDraft=[{d:2,s:600,e:660,n:\'ESEMPIO\',r:\'\'}];ttDraw();$(\'#dTT\').scrollTop=250"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-device-fix-timetable.png");try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}}}}}}\n')

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace("visualDeviceFixReady(web,0)","visualNativeTimetableReady(web,0)")
s+='\nfunc visualNativeTimetableReady(_ web:WKWebView,_ attempt:Int){web.evaluateJavaScript("!!window.__novaMainReady"){v,e in if v as? Bool != true{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualNativeTimetableReady(web,attempt+1)}};return};web.evaluateJavaScript("$(\'#intro\')?.remove();$(\'#ob\').hidden=true;document.body.classList.remove(\'ovl\');S.tt={lessons:[{d:2,s:490,e:550,n:\'INFORMATICA\',r:\'LAB 2\'},{d:2,s:550,e:610,n:\'MATEMATICA\',r:\'3A\'}]};openTT();__settingsTestKeys().sync()"){_,_ in DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-native-timetable-top.png");if #available(iOS26.0,*){func findPage(_ vc:UIViewController?)->NativeSettingsPage?{guard let vc=vc else{return nil};if let nav=vc as? UINavigationController,let p=nav.topViewController as? NativeSettingsPage{return p};if let p=findPage(vc.presentedViewController){return p};for child in vc.children{if let p=findPage(child){return p}};return nil};let roots=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.compactMap{$0.rootViewController};if let editor=roots.compactMap({findPage($0)}).first{editor.tableView.scrollToRow(at:IndexPath(row:3,section:editor.groups.count-1),at:.bottom,animated:false)}};DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-native-timetable-bottom.png");web.callAsyncJavaScript("return await(async()=>{const k=()=>__settingsTestKeys(),key=e=>[...k().fields].find(([id,v])=>v===e)?.[0],a=(e,v=null)=>__nativeSettingsPageAction(key(e),v,S.acct?.email||\'\',k().epoch),before=JSON.stringify(S.tt);await a($(\'#ttL .tn\'),\'FISICA\');await a($(\'#ttL .ts\'),\'08:30\');const draftOnly=JSON.stringify(S.tt)===before;await a($(\'#ttC\'));openTT();k().sync();const cancelPreserved=JSON.stringify(S.tt)===before&&ttDraft[0].n===\'INFORMATICA\';await a($(\'#ttL .tn\'),\'FISICA\');await a($(\'#ttL .ts\'),\'08:30\');await a($(\'#ttOk\'));const saved=S.tt.lessons[0].n===\'FISICA\'&&S.tt.lessons[0].s===510;openTT();k().sync();const old=k().epoch,id=key($(\'#ttX\'));await __nativeSettingsPageAction(id,null,\'wrong-owner\',old);const wrongOwner=ttDraft.length===2;await __nativeSettingsPageAction(id,null,S.acct?.email||\'\',old-1);const staleEpoch=ttDraft.length===2;await a($(\'#ttX\'));const clearDraft=ttDraft.length===0&&S.tt.lessons.length===2;await a($(\'#ttC\'));const originalNat=nat,originalImg=ttImg,hadKey=gqHas;gqHas=true;ttImg=async()=>\'\';let finish;nat=(t,op,d)=>t===\'groq\'&&op===\'vision\'?new Promise(r=>finish=r):originalNat(t,op,d);openTT();await new Promise(r=>setTimeout(r,10));const imported=$(\'#ttF\').onchange({target:{files:[new File([\'x\'],\'x.jpg\')],value:\'\'}});await new Promise(r=>setTimeout(r,0));$(\'#ttC\').click();await new Promise(r=>setTimeout(r,10));openTT();const expected=JSON.stringify(ttDraft);finish({ok:true,text:JSON.stringify({lessons:[{d:1,h:1,s:\'08:00\',e:\'09:00\',n:\'STALE\'}]})});await imported;const staleImportBlocked=JSON.stringify(ttDraft)===expected;nat=originalNat;ttImg=originalImg;gqHas=hadKey;return JSON.stringify({draftOnly,cancelPreserved,saved,wrongOwner,staleEpoch,clearDraft,staleImportBlocked,errors:testErrors})})()",arguments:[:],in:nil,in:.page){result in let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0];try? String(describing:result).write(to:dir.appendingPathComponent("timetable-functional.txt"),atomically:true,encoding:.utf8);try? Data().write(to:dir.appendingPathComponent("visual-done"))}}}}}}\n'
p.write_text(s.replace("iOS26.0","iOS 26.0"))

Path("/tmp/SwiftStateTests.swift").write_text('import Foundation\nimport Combine\n// Swift-owned state foundation. Not activated until screen/service parity is verified.\n// Unknown JSON keys survive import and every write. Legacy storage is never deleted.\nindirect enum NOVAJSON: Codable, Equatable {\n    case null, bool(Bool), number(Double), string(String), array([NOVAJSON]), object([String:NOVAJSON])\n    init(from decoder: Decoder) throws {\n        let c = try decoder.singleValueContainer()\n        if c.decodeNil() { self = .null }\n        else if let v = try? c.decode(Bool.self) { self = .bool(v) }\n        else if let v = try? c.decode(Double.self) { self = .number(v) }\n        else if let v = try? c.decode(String.self) { self = .string(v) }\n        else if let v = try? c.decode([NOVAJSON].self) { self = .array(v) }\n        else { self = .object(try c.decode([String:NOVAJSON].self)) }\n    }\n    func encode(to encoder: Encoder) throws {\n        var c = encoder.singleValueContainer()\n        switch self {\n        case .null: try c.encodeNil()\n        case .bool(let v): try c.encode(v)\n        case .number(let v): try c.encode(v)\n        case .string(let v): try c.encode(v)\n        case .array(let v): try c.encode(v)\n        case .object(let v): try c.encode(v)\n        }\n    }\n    var object: [String:NOVAJSON]? { if case .object(let o) = self { return o }; return nil }\n    var string: String? { if case .string(let s) = self { return s }; return nil }\n}\nstruct NOVASwiftArchive: Codable {\n    let version: Int\n    let importedAt: Date\n    var localStorage: [String:String]\n    var active: NOVAJSON\n    var owner: String {\n        active.object?["acct"]?.object?["email"]?.string?.lowercased() ?? "local"\n    }\n    static func imported(_ values: [String:String]) throws -> NOVASwiftArchive {\n        guard let source = values["nova.v1"], let bytes = source.data(using:.utf8),\n              let state = try? JSONDecoder().decode(NOVAJSON.self, from:bytes), state.object != nil else {\n            throw CocoaError(.fileReadCorruptFile)\n        }\n        return NOVASwiftArchive(version:1, importedAt:Date(), localStorage:values, active:state)\n    }\n}\n@MainActor final class NOVASwiftStore: ObservableObject {\n    @Published private(set) var archive: NOVASwiftArchive?\n    private let directory: URL\n    init(directory: URL? = nil) {\n        self.directory = directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("NOVASwift",isDirectory:true)\n        let url = self.directory.appendingPathComponent("state-v1.json")\n        if let data = try? Data(contentsOf:url) { archive = try? JSONDecoder().decode(NOVASwiftArchive.self,from:data) }\n    }\n    // Called only after the user reviews the one-time migration offer.\n    func importOnce(_ values: [String:String]) throws {\n        guard archive == nil else { throw CocoaError(.fileWriteFileExists) }\n        let imported = try NOVASwiftArchive.imported(values)\n        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)\n        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]\n        let data = try encoder.encode(imported)\n        // Keep an immutable recovery copy before activating the new state.\n        try data.write(to:directory.appendingPathComponent("legacy-import-v1.json"),options:[.atomic,.completeFileProtection])\n        try data.write(to:directory.appendingPathComponent("state-v1.json"),options:[.atomic,.completeFileProtection])\n        let readBack = try JSONDecoder().decode(NOVASwiftArchive.self,from:Data(contentsOf:directory.appendingPathComponent("state-v1.json")))\n        guard readBack.active == imported.active, readBack.localStorage == imported.localStorage else { throw CocoaError(.fileWriteUnknown) }\n        archive = readBack\n    }\n    func update(owner: String, _ edit: (inout [String:NOVAJSON]) throws -> Void) throws {\n        guard var current = archive, current.owner == owner, var state = current.active.object else { throw CocoaError(.userCancelled) }\n        let previousOwner = current.owner\n        try edit(&state); current.active = .object(state)\n        // Account transitions use a separate reviewed transaction, never an ordinary field update.\n        guard current.owner == previousOwner else { throw CocoaError(.userCancelled) }\n        let data = try JSONEncoder().encode(current)\n        try data.write(to:directory.appendingPathComponent("state-v1.json"),options:[.atomic,.completeFileProtection])\n        archive = current\n    }\n}\n@main struct StateTests {\n @MainActor static func main() throws {\n  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)\n  defer {try? FileManager.default.removeItem(at:root)}\n  let values=["nova.v1":"{\\"name\\":\\"Fixture\\",\\"acct\\":{\\"email\\":\\"test@example.invalid\\",\\"token\\":\\"synthetic\\"},\\"tt\\":{\\"lessons\\":[]},\\"future\\":{\\"preserve\\":[1,true,null,\\"x\\"]}}","nova.account.v3.other@example.invalid":"synthetic-cache","nova.recovery.old":"synthetic-recovery"]\n  let store=NOVASwiftStore(directory:root)\n  try store.importOnce(values)\n  precondition(store.archive?.localStorage==values)\n  let old=store.archive!.active.object!["future"]\n  try store.update(owner:"test@example.invalid"){$0["name"] = .string("Updated")}\n  precondition(store.archive!.active.object!["future"]==old)\n  precondition(store.archive!.active.object!["tt"]?.object?["lessons"] == .array([]))\n  var blocked=false;do{try store.update(owner:"other@example.invalid"){$0["name"] = .string("WRONG")}}catch{blocked=true};precondition(blocked)\n  blocked=false;do{try store.importOnce(values)}catch{blocked=true};precondition(blocked)\n  blocked=false;do{try store.update(owner:"test@example.invalid"){$0["acct"] = .object(["email":.string("wrong@example.invalid")])}}catch{blocked=true};precondition(blocked)\n  let reload=NOVASwiftStore(directory:root)\n  precondition(reload.archive!.active.object!["name"] == .string("Updated"))\n  precondition(reload.archive!.localStorage==values)\n  let recovery=try JSONDecoder().decode(NOVASwiftArchive.self,from:Data(contentsOf:root.appendingPathComponent("legacy-import-v1.json")))\n  precondition(recovery.active.object!["name"] == .string("Fixture"))\n  print("Swift state import/unknown fields/empty timetable/reload/recovery/wrong owner/reimport/account-change guards PASS")\n }\n}\n')

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace("visualNativeTimetableReady(web,0)","visualSwiftOwnedReady(web,0)")
s+='\n@MainActor func visualSwiftOwnedReady(_ web:WKWebView,_ attempt:Int){\n guard let root=web.window?.rootViewController else{if attempt<90{DispatchQueue.main.asyncAfter(deadline:.now()+1){visualSwiftOwnedReady(web,attempt+1)}};return}\n let directory=FileManager.default.temporaryDirectory.appendingPathComponent("swift-screen-fixture-"+UUID().uuidString)\n let store=NOVASwiftStore(directory:directory)\n do {try store.importOnce(["nova.v1":"{\\"name\\":\\"Fixture\\",\\"tasks\\":[{\\"id\\":\\"test\\",\\"title\\":\\"Compito dimostrativo\\",\\"due\\":\\"2026-11-03T18:00\\"}],\\"tt\\":{\\"lessons\\":[{\\"d\\":2,\\"s\\":600,\\"e\\":660,\\"n\\":\\"ESEMPIO\\",\\"r\\":\\"Aula A\\"}]}}"])}catch{return}\n let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]\n var checks:[String:Bool]=[:]\n do {\n  let original=store.archive!.active\n  do{try NOVASwiftTaskActions.add(store,owner:"wrong",title:"Wrong",note:"",due:Date(),priority:"media",reminder:0)}catch{}\n  checks["wrongOwnerBlocked"]=store.archive!.active==original\n  let due=Date().addingTimeInterval(86400)\n  try NOVASwiftTaskActions.add(store,owner:"local",title:"Nuovo compito Swift",note:"Bozza dimostrativa",due:due,priority:"alta",reminder:0)\n  checks["taskAdded"]=(store.archive!.active.object?["tasks"]?.array.count==2)\n  do{try NOVASwiftTaskActions.add(store,owner:"local",title:"Nuovo compito Swift",note:"",due:due,priority:"media",reminder:0)}catch{}\n  checks["duplicateBlocked"]=(store.archive!.active.object?["tasks"]?.array.count==2)\n  try NOVASwiftTaskActions.mutate(store,owner:"local",id:"test")\n  checks["completed"]=(store.archive!.active.object?["tasks"]?.array.first?.object?["done"]?.flag==true)\n  try NOVASwiftTaskActions.mutate(store,owner:"local",id:"test",remove:true)\n  checks["removed"]=(store.archive!.active.object?["tasks"]?.array.count==1)\n }catch{checks["taskException"]=true}\n try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-task-checks.txt"))\n let page=UIHostingController(rootView:NOVASwiftOverview(store:store));page.modalPresentationStyle = .fullScreen\n root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-overview.png");page.dismiss(animated:false){let editor=UIHostingController(rootView:NOVASwiftTimetable(store:store));editor.modalPresentationStyle = .fullScreen;root.present(editor,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-timetable.png");editor.dismiss(animated:false){let task=UIHostingController(rootView:NOVASwiftTaskEditor(store:store));task.modalPresentationStyle = .fullScreen;root.present(task,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-task.png");try? "Swift-owned views, synthetic local imported data, no JavaScript actions used".write(to:dir.appendingPathComponent("swift-screen-state.txt"),atomically:true,encoding:.utf8);visualSwiftImportOrigin(web,dir)}}}}}}}\n}\n}\n@MainActor func visualSwiftImportOrigin(_ web:WKWebView,_ dir:URL){\n let reader=NOVALegacyReader()\n web.evaluateJavaScript("localStorage.setItem(\'nova.origin-test\',\'synthetic-origin\');true"){_,_ in\n  reader.read{result in\n   var checks:[String:Bool]=[:]\n   switch result {case .success(let values):checks["sameOriginMarkerRead"]=values["nova.origin-test"]=="synthetic-origin";checks["legacyStatePreserved"]=values["nova.v1"] != nil\n   case .failure:checks["readFailed"]=true}\n   try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-import-origin.txt"))\n   try? Data().write(to:dir.appendingPathComponent("visual-done"))\n   _ = reader\n  }\n }\n}\n'
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('visualSwiftImportOrigin(web,dir)','visualSwiftProfileSettings(web,store,dir)')
s+=r'''
@MainActor func visualSwiftProfileSettings(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL){
 guard let root=web.window?.rootViewController else{return}
 let host=root.presentedViewController ?? root
 host.dismiss(animated:false){
  let profile=UIHostingController(rootView:NOVASwiftProfileEditor(store:store));profile.modalPresentationStyle = .fullScreen
  root.present(profile,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){
   visualProductionSave(web,"production-swift-owned-profile.png")
   profile.dismiss(animated:false){
    let settings=UIHostingController(rootView:NOVASwiftSettings(store:store));settings.modalPresentationStyle = .fullScreen
    root.present(settings,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-settings.png");visualSwiftImportOrigin(web,dir)}}
   }
  }}
 }
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('visualSwiftImportOrigin(web,dir)','visualSwiftMapReview(web,store,dir)',1)
s+=r'''
@MainActor func visualSwiftMapReview(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL){
 guard let root=web.window?.rootViewController else{return}
 root.presentedViewController?.dismiss(animated:false){
  let host=UIHostingController(rootView:NOVASwiftMap(store:store));host.modalPresentationStyle = .fullScreen
  root.present(host,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-swift-owned-map.png");visualSwiftImportOrigin(web,dir)}}
 }
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('var checks:[String:Bool]=[:]\n do {','var checks:[String:Bool]=[:]\n do {',1)
# Add pure backup/map guard assertions to the synthetic Swift scene, not a live account.
needle='let original=store.archive!.active'
addition=r'''let original=store.archive!.active
  let privateState:NOVAJSON = .object(["name":.string("Fixture"),"groq":.string("synthetic-secret"),"cv":.object(["password":.string("synthetic")]),"acct":.object(["token":.string("synthetic")]),"future":.bool(true),"prof":.object(["username":.string("fixture"),"ntfy":.string("synthetic-private")]),"chat":.array([.object(["acts":.array([.object(["st":.string("pending")])])])])])
  let snapshot=NOVASwiftBackupData.snapshot(privateState)
  checks["backupExcludesDeviceSecrets"] = snapshot.object?["groq"]==nil && snapshot.object?["cv"]==nil && snapshot.object?["acct"]==nil && snapshot.object?["prof"]?.object?["ntfy"]==nil
  var imported=privateState.object!;NOVASwiftBackupData.apply(snapshot,to:&imported)
  checks["backupPreservesUnknownAndDeviceSecrets"] = imported["future"] == .bool(true) && imported["groq"] == .string("synthetic-secret")
  checks["backupDoesNotReplayActions"] = imported["chat"]?.array.first?.object?["acts"]?.array.first?.object?["st"] == .string("no")
  var waiting:[String:NOVAJSON] = ["chat":.array([.object(["acts":.array([.object(["st":.string("wait"),"swiftID":.string("old")])])])])]
  let waitingCopy:NOVAJSON = .object(waiting);NOVASwiftBackupData.apply(waitingCopy,to:&waiting)
  checks["backupDisablesWaitingProposals"] = waiting["chat"]?.array.first?.object?["acts"]?.array.first?.object?["st"] == .string("no")
  checks["backupDoesNotEnableLocation"] = imported["locShare"]?.flag == false && imported["bgLoc"]?.flag == false
  let now=Date();let stale:NOVAJSON = .object(["username":.string("fixture"),"lat":.number(44),"lon":.number(11),"ts":.number(now.addingTimeInterval(-1801).timeIntervalSince1970*1000)])
  checks["mapRejectsStalePeerPosition"] = NOVASwiftMapFriend.parse(stale,now:now)==nil
'''
s=s.replace(needle,addition,1)
p.write_text(s)

# Exercise the current state implementation, not a frozen duplicate of it.
state=Path("/tmp/SwiftStateTests.swift")
old=state.read_text()
production=Path("Sources/NOVA/NOVASwiftCore.swift").read_text()
foundation=production.split("// Swift-owned state foundation.",1)[1].split("// Swift-only screens",1)[0]
state.write_text("import Foundation\nimport Combine\n// Swift-owned state foundation."+foundation+"\n@main struct StateTests"+old.split("@main struct StateTests",1)[1])

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('guard let root=web.window?.rootViewController else{return}', 'guard let root=(web.window ?? UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.first{$0.isKeyWindow})?.rootViewController else{return}')
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('visualSwiftImportOrigin(web,dir)','visualSwiftDashboardReview(web,store,dir)',1)
s+=r'''
@MainActor func visualSwiftDashboardReview(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 root.presentedViewController?.dismiss(animated:false){
  let host=UIHostingController(rootView:NOVASwiftDashboard(store:store));host.modalPresentationStyle = .fullScreen
  root.present(host,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+3){visualProductionSave(web,"production-swift-owned-dashboard.png");visualSwiftImportOrigin(web,dir)}}
 }
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('visualProductionSave(web,"production-swift-owned-dashboard.png");visualSwiftImportOrigin(web,dir)', 'visualProductionSave(web,"production-swift-owned-dashboard.png");visualSwiftDashboardLower(web,store,dir,host)')
s+=r'''
@MainActor func visualSwiftDashboardLower(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL,_ host:UIHostingController<NOVASwiftDashboard>){
 func scroll(_ view:UIView)->UIScrollView?{if let scroll=view as? UIScrollView{return scroll};for child in view.subviews{if let found=scroll(child){return found}};return nil}
 if let view=scroll(host.view){view.setContentOffset(CGPoint(x:0,y:max(0,view.contentSize.height-view.bounds.height)),animated:false)}
 DispatchQueue.main.asyncAfter(deadline:.now()+1){
  visualProductionSave(web,"production-swift-owned-dashboard-lower.png")
  host.dismiss(animated:false){
   guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
   try? store.update(owner:"local"){$0["gr"] = .array([.object(["subj":.string("Matematica"),"v":.number(7)]),.object(["subj":.string("Matematica"),"v":.number(5)])])}
   let grade=UIHostingController(rootView:NOVASwiftGrades(store:store));grade.modalPresentationStyle = .fullScreen
   root.present(grade,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-grades.png");grade.dismiss(animated:false){let backup=UIHostingController(rootView:NavigationStack{NOVASwiftBackup(store:store)});backup.modalPresentationStyle = .fullScreen;root.present(backup,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-backup.png");visualSwiftImportOrigin(web,dir)}}}}}
  }
 }
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('checks["backupExcludesDeviceSecrets"]', 'checks["backupExcludesDeviceSecrets"]',1)
needle='let privateState:NOVAJSON'
addition=r'''let transition=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
  try transition.importOnce(["nova.v1":"{\"name\":\"Original\",\"future\":true,\"tasks\":[],\"tt\":{\"lessons\":[]}}"])
  try transition.changeAccount(email:"first@example.invalid",token:"synthetic1")
  checks["accountTransitionHasRecovery"] = transition.archive!.localStorage.keys.contains{$0.hasPrefix("nova.swift.recovery.")}
  try transition.update(owner:"first@example.invalid"){$0["name"] = .string("First")}
  try transition.changeAccount(email:"second@example.invalid",token:"synthetic2")
  checks["accountTransitionIsolatesState"] = transition.archive!.active.object?["name"] == .string("")
  try transition.changeAccount(email:"first@example.invalid",token:"synthetic3")
  checks["accountTransitionRestoresOwnCache"] = transition.archive!.active.object?["name"] == .string("First")
  let privateState:NOVAJSON'''
s=s.replace(needle,addition,1)
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('try? Data().write(to:dir.appendingPathComponent("visual-done"))\n   _ = reader','Task{await visualSwiftSyncChecks(dir);try? Data().write(to:dir.appendingPathComponent("visual-done"))}\n   _ = reader',1)
s+=r'''
@MainActor func visualSwiftSyncChecks(_ dir:URL) async {
 var checks:[String:Bool]=[:]
 do{
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
  try store.importOnce(["nova.v1":"{\"name\":\"Fixture\",\"acct\":{\"email\":\"fixture@example.invalid\",\"token\":\"synthetic\"},\"tasks\":[]}"])
  let initial=NOVASwiftBackupData.snapshot(store.archive!.active)
  var putCount=0
  let sync=NOVASwiftSync{_,method,body in
   if method=="GET"{return .object(["data":initial,"rev":.number(1)])}
   putCount += 1;return .object(["rev":.number(2)])
  }
  await sync.inspect(store);checks["matchingBaselineVerified"]=sync.canLeave(store)
  try store.update(owner:"fixture@example.invalid"){$0["name"] = .string("Changed")}
  checks["unsavedEditBlocksLeave"] = !sync.canLeave(store)
  await sync.flush(store);checks["revisionWriteConfirmed"]=putCount==1 && sync.canLeave(store)
  let conflict=NOVASwiftSync{_,method,_ in if method=="GET"{return .object(["data":initial,"rev":.number(1)])};throw NOVAServiceError.http(409,"conflict")}
  await conflict.inspect(store);await conflict.flush(store);checks["differentCloudNeverOverwritten"]=conflict.conflict && !conflict.canLeave(store)
  let revision=NOVASwiftSync{_,method,_ in if method=="GET"{return .object(["data":NOVASwiftBackupData.snapshot(store.archive!.active),"rev":.number(1)])};throw NOVAServiceError.http(409,"conflict")}
  await revision.inspect(store);try store.update(owner:"fixture@example.invalid"){$0["name"] = .string("New edit")};await revision.flush(store)
  checks["serverConflictBlocksLeave"] = revision.conflict && !revision.canLeave(store)
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-sync-checks.txt"))
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('checks["accountTransitionRestoresOwnCache"] = transition.archive!.active.object?["name"] == .string("First")',r'''checks["accountTransitionRestoresOwnCache"] = transition.archive!.active.object?["name"] == .string("First")
  let owner=NOVASession(transition.archive!.active)!,logoutSnapshot=NOVASwiftBackupData.snapshot(transition.archive!.active)
  try transition.update(owner:"first@example.invalid"){$0["name"] = .string("Changed after review")}
  do{try transition.logoutConfirmed(session:owner,snapshot:logoutSnapshot)}catch{}
  checks["logoutRejectsChangedSnapshot"]=NOVASession(transition.archive!.active)==owner
  try transition.logoutConfirmed(session:owner,snapshot:NOVASwiftBackupData.snapshot(transition.archive!.active))
  checks["logoutPreservesAccountCache"]=transition.archive!.owner=="local" && transition.archive!.localStorage["nova.swift.account.first@example.invalid"] != nil
''',1)
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('visualProductionSave(web,"production-swift-owned-backup.png");visualSwiftImportOrigin(web,dir)','visualProductionSave(web,"production-swift-owned-backup.png");visualSwiftAccountScreens(web,store,dir)',1)
s+=r'''
struct VisualSongFixture:View {@State var draft:[String:NOVAJSON]=[:];var body:some View{NOVASwiftSongPicker(draft:$draft)}}
@MainActor func visualSwiftAccountScreens(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 root.presentedViewController?.dismiss(animated:false){
  let login=UIHostingController(rootView:NavigationStack{NOVASwiftAccountLogin(store:store)});login.modalPresentationStyle = .fullScreen
  root.present(login,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-login.png");login.dismiss(animated:false){let songs=UIHostingController(rootView:VisualSongFixture());songs.modalPresentationStyle = .fullScreen;root.present(songs,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-song-search.png");visualSwiftImportOrigin(web,dir)}}}}}
 }
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('await visualSwiftSyncChecks(dir);try? Data()', 'await visualSwiftSyncChecks(dir);await visualSwiftSocialChecks(dir);try? Data()',1)
s+=r'''
@MainActor func visualSwiftSocialChecks(_ dir:URL) async {
 var checks:[String:Bool]=[:]
 do{
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"fixture@example.invalid\",\"token\":\"synthetic\"},\"tasks\":[]}"])
  var paths:[String]=[]
  let social=NOVASwiftSocial{_,path,method,body,_ in
   paths.append(method+":"+path)
   if path=="chats/1/messages" && method=="GET"{return .object(["messages":.array([.object(["id":.number(2),"sender":.string("fixture@example.invalid"),"kind":.string("text"),"body":.string("Example")])])])}
   if path=="media"{return .object(["url":.string("/media/synthetic")])}
   return .object(["ok":.bool(true)])
  }
  await social.open("1",store);checks["readReceiptAfterVisibleOpen"]=paths.contains("POST:chats/1/read")
  let sent=await social.send("Draft",store);checks["textSendSameConversation"]=sent && paths.contains("POST:chats/1/messages")
  paths=[];let other:NOVAJSON = .object(["id":.number(3),"sender":.string("other@example.invalid"),"kind":.string("text")]);await social.action(other,operation:"delete",store);checks["cannotDeleteOtherSender"]=paths.isEmpty
  let own=social.messages.first!;await social.action(own,operation:"react",value:"👍",store);checks["reactionUsesEstablishedEndpoint"]=paths.contains("POST:messages/2/react")
  paths=[];let uploaded=await social.media(Data(repeating:1,count:1000),mime:"image/jpeg",kind:"image",store);checks["mediaUploadThenMessage"]=uploaded && paths.first=="POST:media" && paths.contains("POST:chats/1/messages")
  social.close();paths=[];let closed=await social.send("Blocked",store);checks["closedConversationCannotSend"] = !closed && paths.isEmpty
  var stale:NOVASwiftSocial!
  var stalePaths:[String]=[]
  stale=NOVASwiftSocial{_,path,method,_,_ in stalePaths.append(method+":"+path);if path=="media"{stale.close();return .object(["url":.string("/media/stale")])};return .object(["ok":.bool(true)])}
  await stale.open("stale",store);stalePaths=[];let staleSent=await stale.media(Data(repeating:1,count:1000),mime:"image/jpeg",kind:"image",store);checks["closeDuringUploadBlocksMessage"] = !staleSent && !stalePaths.contains("POST:chats/stale/messages")
  let refused=NOVASwiftSocial{_,_,method,_,_ in .object(["ok":.bool(method != "POST")])};await refused.open("refused",store);let refusedSent=await refused.send("Keep draft",store);checks["serverRefusalPreservesDraft"] = !refusedSent

 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-social-checks.txt"))
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text().replace('visualProductionSave(web,"production-swift-owned-song-search.png");visualSwiftImportOrigin(web,dir)','visualProductionSave(web,"production-swift-owned-song-search.png");visualSwiftSocialScreens(web,dir)',1)
s+=r'''
@MainActor func visualSwiftSocialScreens(_ web:WKWebView,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
 try? store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"fixture@example.invalid\",\"token\":\"synthetic\"}}"])
 let social=NOVASwiftSocial{_,path,_,_,_ in
  if path=="friends"{return .object(["friends":.array([.object(["username":.string("amico_esempio")]),.object(["username":.string("compagna_esempio")])])])}
  if path.hasSuffix("/messages"){return .object(["messages":.array([.object(["id":.number(1),"sender":.string("other@example.invalid"),"kind":.string("text"),"body":.string("Ripassiamo insieme per la verifica?")]),.object(["id":.number(2),"sender":.string("fixture@example.invalid"),"kind":.string("text"),"body":.string("Sì, preparo gli appunti."),"edited":.bool(true)]),.object(["id":.number(3),"sender":.string("other@example.invalid"),"deleted":.bool(true)])]),"reactions":.object(["2":.array([.object(["emoji":.string("👍")])])]),"senders":.object(["other@example.invalid":.string("Amico dimostrativo")])])}
  return .object(["ok":.bool(true)])
 }
 root.presentedViewController?.dismiss(animated:false){
  let conversation=UIHostingController(rootView:NavigationStack{NOVASwiftConversation(store:store,social:social,id:"fixture",title:"Gruppo dimostrativo")});conversation.modalPresentationStyle = .fullScreen
  root.present(conversation,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-conversation.png");conversation.dismiss(animated:false){let create=UIHostingController(rootView:NOVASwiftChatCreation(store:store,social:social));create.modalPresentationStyle = .fullScreen;root.present(create,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-create-chat.png");visualSwiftPeopleScreens(web,store,dir)}}}}}
 }
}
'''
p.write_text(s)
p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('await visualSwiftSocialChecks(dir);try? Data()', 'await visualSwiftSocialChecks(dir);await visualSwiftPeopleChecks(dir);try? Data()',1)
s+=r'''
@MainActor func visualSwiftPeopleChecks(_ dir:URL) async {
 var checks:[String:Bool]=[:]
 do{
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"fixture@example.invalid\",\"token\":\"synthetic\"},\"prof\":{\"username\":\"fixture\"},\"profConfirmed\":\"fixture\"}"])
  var paths:[String]=[]
  let people=NOVASwiftPeople{_,path,method,_,_ in paths.append(method+":"+path);if path=="friends"{return .object(["ok":.bool(true),"friends":.array([.object(["username":.string("esempio")])]),"incoming":.array([]),"outgoing":.array([])])};if path=="users/profile"{return .object(["ok":.bool(true),"limited":.bool(true),"profile":.object([:])])};return .object(["ok":.bool(true)])}
  await people.load(store);checks["readDoesNotMutateFriendships"] = paths==["GET:friends"] && people.friends.count==1
  let request=await people.action("friends/request",username:"esempio",store);checks["explicitRequestEstablishedEndpoint"] = request && paths.contains("POST:friends/request")
  await people.open("esempio",store);checks["limitedProfilePreserved"] = people.profile?.object?["limited"]?.flag==true
  paths=[];let rejected=await people.action("unrelated/write",username:"x",store);checks["unknownActionRejected"] = !rejected && paths.isEmpty
  checks["qrOnlyNOVAUsername"] = NOVASwiftQR.parse("nova:add:amico_test")=="amico_test" && NOVASwiftQR.parse("https://example.invalid/collect")==nil && NOVASwiftQR.parse("nova:add:bad/user")==nil && NOVASwiftQR.parse("nova:add:amico.test")=="amico.test"
  var stale:NOVASwiftPeople!
  stale=NOVASwiftPeople{_,_,_,_,_ in stale.closeProfile();return .object(["ok":.bool(true),"profile":.object(["study":.string("STALE")])])}
  await stale.open("old",store);checks["closedProfileIgnoresResponse"] = stale.profile==nil
  people.reset();checks["resetClearsAllAccountLists"] = people.friends.isEmpty && people.results.isEmpty && people.profile==nil
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-people-checks.txt"))
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text()+r'''
@MainActor func visualSwiftPeopleScreens(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 let people=NOVASwiftPeople{_,_,_,_,_ in .object(["ok":.bool(true),"profile":.object(["study":.string("Scuola dimostrativa"),"skills":.string("Matematica e informatica"),"hobbies":.string("Musica e sport"),"badges":.array([.string("Primi passi")])]),"followers":.number(12),"following":.number(8),"you_follow":.bool(false),"is_friend":.bool(true)])}
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:NavigationStack{NOVASwiftPublicProfile(store:store,people:people,username:"esempio")});page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-public-profile.png");page.dismiss(animated:false){try? store.update(owner:store.archive!.owner){$0["prof"] = .object(["username":.string("esempio")])};let qr=UIHostingController(rootView:NOVASwiftQR(store:store,people:people));qr.modalPresentationStyle = .fullScreen;root.present(qr,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-qr.png");visualSwiftAssistantScreen(web,dir)}}}}}}
}
'''
p.write_text(s)
p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('await visualSwiftPeopleChecks(dir);try? Data()', 'await visualSwiftPeopleChecks(dir);await visualSwiftAssistantChecks(dir);try? Data()',1)
s+=r'''
@MainActor func visualSwiftAssistantChecks(_ dir:URL) async {
 var checks:[String:Bool]=[:]
 let text="Proposta\n###AZIONI###[{\"a\":\"task\",\"title\":\"Ripasso\",\"due\":\"2026-11-03T18:00\",\"rem\":0},{\"a\":\"unknown\"}]"
 let (visible,actions)=NOVASwiftAssistantActions.parse(text,permission:"ask")
 checks["parseSeparatesTextAndValidActions"] = visible=="Proposta" && actions.count==1 && actions.first?.object?["st"]?.string=="wait"
 checks["denyNeverQueuesExecution"] = NOVASwiftAssistantActions.parse(text,permission:"deny").1.first?.object?["st"]?.string=="off"
 checks["unknownPageRejected"] = NOVASwiftAssistantActions.normalize(.object(["a":.string("open"),"page":.string("external")]))==nil
 checks["badDateRejected"] = NOVASwiftAssistantActions.normalize(.object(["a":.string("task"),"title":.string("X"),"due":.string("not-a-date")]))==nil
 do{
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try store.importOnce(["nova.v1":"{\"tasks\":[],\"chat\":[],\"aiAct\":\"ask\"}"])
  try store.update(owner:"local"){$0["chat"] = .array([.object(["r":.string("assistant"),"c":.string(visible),"acts":.array(actions)])])}
  checks["proposalDoesNotMutateTasks"] = store.archive?.active.object?["tasks"]?.array.isEmpty==true
  await NOVASwiftAssistantActions.run(store,owner:"wrong",message:0,action:0);checks["wrongOwnerCannotExecute"] = store.archive?.active.object?["tasks"]?.array.isEmpty==true
  await NOVASwiftAssistantActions.run(store,owner:"local",message:0,action:0);checks["confirmedTaskCreated"] = store.archive?.active.object?["tasks"]?.array.count==1 && store.archive?.active.object?["chat"]?.array.first?.object?["acts"]?.array.first?.object?["st"]?.string=="done"
  await NOVASwiftAssistantActions.run(store,owner:"local",message:0,action:0);checks["completedActionNotReplayed"] = store.archive?.active.object?["tasks"]?.array.count==1
  var old=actions[0].object!;old.removeValue(forKey:"swiftID");old["st"] = .string("wait");try store.update(owner:"local"){$0["chat"] = .array([.object(["r":.string("assistant"),"acts":.array([.object(old)])])])};await NOVASwiftAssistantActions.run(store,owner:"local",message:0,action:0);checks["legacyActionsNeverReplayed"] = store.archive?.active.object?["tasks"]?.array.count==1
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-assistant-checks.txt"))
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text()+r'''
@MainActor func visualSwiftAssistantScreen(_ web:WKWebView,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try? store.importOnce(["nova.v1":"{\"chat\":[],\"tasks\":[],\"aiAct\":\"ask\"}"])
 let proposal=NOVASwiftAssistantActions.parse("Ti propongo un ripasso breve.\n###AZIONI###[{\"a\":\"task\",\"title\":\"Ripasso dimostrativo\",\"due\":\"2026-11-03T18:00\",\"rem\":0}]",permission:"ask")
 try? store.update(owner:"local"){$0["chat"] = .array([.object(["r":.string("user"),"c":.string("Come preparo la verifica?")]),.object(["r":.string("assistant"),"c":.string(proposal.0),"acts":.array(proposal.1)])])}
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:NOVASwiftAssistant(store:store));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-assistant-actions.png");visualSwiftServicesScreen(web,dir)}}}
}
'''
p.write_text(s)
p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('await visualSwiftAssistantChecks(dir);try? Data()', 'await visualSwiftAssistantChecks(dir);visualSwiftSchoolChecks(dir);await visualSwiftNotificationChecks(dir);try? Data()',1)
s+=r'''
@MainActor func visualSwiftSchoolChecks(_ dir:URL){
 var checks:[String:Bool]=[:]
 do{
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try store.importOnce(["nova.v1":"{\"tasks\":[{\"id\":\"manual\",\"title\":\"Manuale\",\"done\":0},{\"id\":\"cvhw1\",\"title\":\"Old\",\"src\":\"cv\",\"done\":1,\"unknown\":\"keep\"}],\"gr\":[]}"])
  let response:NOVAJSON = .object(["ok":.bool(true),"name":.string("Studente dimostrativo"),"events":.array([.object(["id":.string("hw1"),"date":.string("2026-11-03"),"title":.string("Aggiornato"),"kind":.string("hw")]),.object(["id":.string("ag2"),"date":.string("2026-11-04"),"title":.string("Verifica"),"kind":.string("test")])]),"grades":.array([.object(["subj":.string("Matematica"),"v":.number(7)])])])
  try NOVASwiftSchoolImport.apply(response,store,owner:"local")
  let tasks=store.archive!.active.object!["tasks"]!.array
  checks["manualTaskPreserved"] = tasks.contains{$0.object?["id"]?.string=="manual"}
  checks["completionAndUnknownPreserved"] = tasks.first{$0.object?["id"]?.string=="cvhw1"}?.object?["done"]?.flag==true && tasks.first{$0.object?["id"]?.string=="cvhw1"}?.object?["unknown"]?.string=="keep"
  checks["schoolEventsAndGradesImported"] = tasks.count==3 && store.archive?.active.object?["gr"]?.array.count==1
  let snapshot=store.archive!.active
  do{try NOVASwiftSchoolImport.apply(.object(["ok":.bool(false)]),store,owner:"local")}catch{}
  checks["failedImportPreservesData"] = store.archive!.active==snapshot
  do{try NOVASwiftSchoolImport.apply(response,store,owner:"wrong")}catch{}
  checks["wrongOwnerImportBlocked"] = store.archive!.active==snapshot
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-school-checks.txt"))
}
'''
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text()+r'''
@MainActor func visualSwiftServicesScreen(_ web:WKWebView,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try? store.importOnce(["nova.v1":"{\"tasks\":[],\"gr\":[]}"])
 let model=NOVASwiftServicesModel(school:{_ in ["ok":0]},music:{_ in ["ok":1,"cid":false,"conn":false]},ai:{_ in ["ok":1,"has":false]})
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:NavigationStack{NOVASwiftServices(store:store,model:model)});page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-services.png");visualSwiftServicesLower(web,store,dir,page)}}}
}
'''
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('NOVASwiftMusicCard()', 'NOVASwiftMusicCard(model:NOVASwiftServicesModel(school:{_ in ["ok":0]},music:{_ in ["ok":1,"cid":false,"conn":false]},ai:{_ in ["ok":1,"has":false]}))')
p.write_text(s)

p=Path("/tmp/NOVAProductionVisual.swift")
s=p.read_text()+r'''
@MainActor func visualSwiftLifecycleScreens(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:NOVASwiftWelcome(store:store));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-welcome.png");page.dismiss(animated:false){let settings=UIHostingController(rootView:NavigationStack{NOVASwiftDeviceSettings()});settings.modalPresentationStyle = .fullScreen;root.present(settings,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-device-settings.png");visualSwiftImportOrigin(web,dir)}}}}}}
}
'''
p.write_text(s)
p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('visualProductionSave(web,"production-swift-owned-device-settings.png");visualSwiftImportOrigin(web,dir)','visualProductionSave(web,"production-swift-owned-device-settings.png");visualSwiftNavigationScreen(web,dir)',1)
s+=r'''
struct VisualSwiftNavigationFixture:View {
 @State var selected=0
 var body:some View{VStack{Text(["Home","Voti","Chat","Mappa","Profilo"][selected]).font(.largeTitle.bold());Text("Contenuto dimostrativo: cambia solo al rilascio").foregroundStyle(.secondary);Spacer()}.padding().safeAreaInset(edge:.bottom){NOVASwiftNavigation(selected:$selected,avatar:"").frame(height:58).padding(18)}}
}
@MainActor func visualSwiftNavigationScreen(_ web:WKWebView,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:VisualSwiftNavigationFixture());page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-owned-navigation.png");visualSwiftImportOrigin(web,dir)}}}
}
'''
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text()+r'''
@MainActor func visualSwiftNotificationChecks(_ dir:URL) async {
 var checks:[String:Bool]=[:]
 do{
  let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"fixture@example.invalid\",\"token\":\"synthetic\"},\"prof\":{\"username\":\"fixture\"}}"])
  var paths:[String]=[];var changed=false
  let model=NOVASwiftSocialNotifications{_,path,method,_,_ in paths.append(method+":"+path);if path=="profile"{return .object(["ok":.bool(true),"profile":.object(["ntfy_topic":.string(changed ? "nova-changed":"nova-fixture")])])};return .object(["ok":.bool(true),"accepted":.bool(true)])}
  await model.load(store);checks["readNeverPublishesTest"] = paths==["GET:profile"]
  checks["previewHiddenByDefault"] = !model.preview
  paths=[];changed=true;await model.test(store);checks["changedTopicBlocksTest"] = !paths.contains("POST:notifications/test")
  changed=false;await model.load(store);paths=[];await model.test(store);checks["explicitTestRechecksTopic"] = paths==["GET:profile","POST:notifications/test"]
  model.cancel();checks["cancelClearsTopic"] = model.topic.isEmpty
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-notification-checks.txt"))
}
'''
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('visualSwiftSchoolChecks(dir);await visualSwiftNotificationChecks(dir);try? Data()', 'visualSwiftSchoolChecks(dir);await visualSwiftNotificationChecks(dir);await visualSwiftPrivacyServiceChecks(dir);try? Data()',1)
s=s.replace('visualProductionSave(web,"production-swift-owned-navigation.png");visualSwiftImportOrigin(web,dir)', 'visualProductionSave(web,"production-swift-owned-navigation.png");visualSwiftWelcomePages(web,dir,0)',1)
s+=r"""
@MainActor func visualSwiftPrivacyServiceChecks(_ dir:URL) async {
 var checks:[String:Bool]=[:]
 do{
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try store.importOnce(["nova.v1":"{\"acct\":{\"email\":\"fixture@example.invalid\",\"token\":\"synthetic\"},\"locShare\":1,\"bgLoc\":1,\"locSession\":\"old\",\"tasks\":[{\"id\":\"keep\"}],\"gr\":[{\"v\":7}],\"cv\":{\"on\":1}}"])
 let session=NOVASession(store.archive!.active)!,before=NOVASwiftBackupData.snapshot(store.archive!.active)
 var localOffBeforeRequest=false,failedBlocked=false
 do{try await NOVASwiftAccountPrivacy.prepare(store,session:session,stop:{_ in localOffBeforeRequest=store.archive?.active.object?["locShare"]?.flag==false && store.archive?.active.object?["bgLoc"]?.flag==false;return .object(["ok":.bool(false)])})}catch{failedBlocked=true}
 checks["localSharingStopsBeforeAwait"]=localOffBeforeRequest
 checks["serverRefusalBlocksTransition"]=failedBlocked && NOVASession(store.archive!.active)==session
 checks["privacyStopPreservesBackup"]=NOVASwiftBackupData.snapshot(store.archive!.active)==before
 try await NOVASwiftAccountPrivacy.prepare(store,session:session,stop:{_ in .object(["ok":.bool(true)])})
 checks["positiveServerStopAllowsSameSession"]=NOVASession(store.archive!.active)==session
 var changedBlocked=false
 do{try await NOVASwiftAccountPrivacy.prepare(store,session:session,stop:{_ in try store.changeAccount(email:"other@example.invalid",token:"other");return .object(["ok":.bool(true)])})}catch{changedBlocked=true}
 checks["accountChangeDuringStopRejected"]=changedBlocked
 try store.changeAccount(email:"fixture@example.invalid",token:"new")
 var ops:[String]=[]
 let services=NOVASwiftServicesModel(school:{body in ops.append(body["op"] as? String ?? "");return ["ok":1]},music:{_ in ["ok":1]},ai:{_ in ["ok":1]})
 await services.schoolRequest("logout",store)
 checks["disconnectUsesLogoutOnly"]=ops==["logout"]
 checks["disconnectKeepsImportedData"]=store.archive?.active.object?["tasks"]?.array.count==1 && store.archive?.active.object?["gr"]?.array.count==1 && store.archive?.active.object?["cv"]?.object?["on"]?.flag==false
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-privacy-service-checks.txt"))
}
@MainActor func visualSwiftWelcomePages(_ web:WKWebView,_ dir:URL,_ step:Int){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try? store.importOnce(["nova.v1":"{\"tasks\":[],\"gr\":[]}"])
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:NOVASwiftWelcome(store:store,initialStep:step));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+0.6){visualProductionSave(web,"production-swift-owned-welcome-"+String(step)+".png");if step<15{visualSwiftWelcomePages(web,dir,step+1)}else{page.dismiss(animated:false){let intro=UIHostingController(rootView:NOVASwiftCinematicIntro(completion:{}));intro.modalPresentationStyle = .fullScreen;root.present(intro,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2.5){visualProductionSave(web,"production-swift-owned-intro.png");intro.dismiss(animated:false){visualSwiftImportOrigin(web,dir)}}}}}}}}
}
"""
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('intro.dismiss(animated:false){visualSwiftImportOrigin(web,dir)}','intro.dismiss(animated:false){visualSwiftProfileOverview(web,dir)}',1)
s+=r"""
@MainActor func visualSwiftProfileOverview(_ web:WKWebView,_ dir:URL){
 guard let root=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow})?.rootViewController else{return}
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));try? store.importOnce(["nova.v1":"{\"name\":\"Studente dimostrativo\",\"prof\":{\"username\":\"nova.demo\",\"study\":\"Scuola dimostrativa\",\"skills\":\"Matematica e informatica\",\"hobbies\":\"Musica\",\"song\":{\"t\":\"Canzone dimostrativa\",\"a\":\"Artista\"}}}"])
 let page=UIHostingController(rootView:NOVASwiftProfile(store:store));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-profile-overview.png");visualSwiftFinalDetailScreens(web,store,dir,page)}}
}
"""
p.write_text(s)

import os
if os.environ.get('NOVA_INTERACTION')=='1':
    p=Path('/tmp/NOVAProductionVisual.swift')
    s=p.read_text()
    assert 'visualSwiftOwnedReady(web,0)' in s, 'Swift entry point missing'
    s=s.replace('visualSwiftOwnedReady(web,0)','visualSwiftInteractionReady(web,0)',1)
    s+='\n'+Path('NOVAInteractionFixture.swift/NOVAInteractionFixture.swift').read_text()
    p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('await visualSwiftPrivacyServiceChecks(dir);try? Data()', 'await visualSwiftPrivacyServiceChecks(dir);visualSwiftTimetablePhotoChecks(dir);try? Data()',1)
s+=r"""
@MainActor func visualSwiftTimetablePhotoChecks(_ dir:URL){
 var checks:[String:Bool]=[:]
 do{
 let result=try NOVASwiftTimetablePhoto.parse("Risposta ```json {\"lessons\":[{\"d\":1,\"h\":1,\"s\":\"08:10\",\"e\":\"09:00\",\"n\":\"MAT\"},{\"d\":2,\"h\":3,\"n\":\"ITA\"}]} ```")
 checks["weekdaysAndTimesPreserved"]=result.lessons[0].day==2 && result.lessons[0].start==490 && result.lessons[0].end==540
 checks["missingTimeExplicitlyEstimated"]=result.estimated && result.lessons[1].day==3 && result.lessons[1].start==600
 var rejected=false;do{_ = try NOVASwiftTimetablePhoto.parse("{\"lessons\":[{\"d\":9,\"n\":\"BAD\"}]}")}catch{rejected=true};checks["emptyInvalidProposalRejected"]=rejected
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-timetable-photo-checks.txt"))
}
"""
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text().replace('visualSwiftTimetablePhotoChecks(dir);try? Data()', 'visualSwiftTimetablePhotoChecks(dir);visualSwiftLegacyAccountCacheChecks(dir);try? Data()',1)
s+=r"""
@MainActor func visualSwiftLegacyAccountCacheChecks(_ dir:URL){
 var checks:[String:Bool]=[:]
 do{
 let store=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
 let cached="{\"data\":{\"chat\":[{\"acts\":[{\"a\":\"task\",\"st\":\"wait\",\"swiftID\":\"old-proposal\"}]}],\"name\":\"Returning\",\"tasks\":[{\"id\":\"old-task\",\"future\":true}],\"tt\":{\"lessons\":[]},\"prof\":{\"username\":\"returning\"},\"future\":\"keep\"},\"rev\":3,\"last\":\"old\"}"
 try store.importOnce(["nova.v1":"{\"tasks\":[]}","nova.account.v3.return@example.invalid":cached])
 try store.changeAccount(email:"return@example.invalid",token:"new-token")
 checks["cachedProposalsNeverReplayAcrossSessions"]=store.archive?.active.object?["chat"]?.array.first?.object?["acts"]?.array.first?.object?["st"]?.string=="off"
 checks["legacyEnvelopeRestored"]=store.archive?.active.object?["name"]?.string=="Returning" && store.archive?.active.object?["tasks"]?.array.first?.object?["id"]?.string=="old-task"
 checks["unknownFieldsAndOriginalCachePreserved"]=store.archive?.active.object?["future"]?.string=="keep" && store.archive?.localStorage["nova.account.v3.return@example.invalid"]==cached
 let privacyStore=NOVASwiftStore(directory:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
 let privacyLegacy="{\"locShare\":1,\"bgLoc\":1,\"locSession\":\"old-location-session\",\"locSessionToken\":\"old-token\",\"tasks\":[{\"title\":\"Keep me\"}]}"
 try privacyStore.importOnce(["nova.v1":privacyLegacy])
 checks["initialImportNeverEnablesSharing"]=privacyStore.archive?.active.object?["locShare"]?.flag==false && privacyStore.archive?.active.object?["bgLoc"]?.flag==false && privacyStore.archive?.active.object?["locSession"]?.string=="" && privacyStore.archive?.localStorage["nova.v1"]==privacyLegacy && privacyStore.archive?.active.object?["tasks"]?.array.count==1
 checks["cacheNeverEnablesSharingOrServices"]=store.archive?.active.object?["locShare"]?.flag==false && store.archive?.active.object?["bgLoc"]?.flag==false && store.archive?.active.object?["cv"]?.object?["on"]?.flag==false
 }catch{checks["exception"]=true}
 try? JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-account-cache-checks.txt"))
}
"""
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text()+r"""
@MainActor func visualSwiftServicesLower(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL,_ page:UIViewController){
 func scroll(_ view:UIView)->UIScrollView?{if let s=view as? UIScrollView{return s};for child in view.subviews{if let s=scroll(child){return s}};return nil}
 if let view=scroll(page.view){view.setContentOffset(CGPoint(x:0,y:max(0,view.contentSize.height-view.bounds.height)),animated:false)}
 DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-services-lower.png");visualSwiftLifecycleScreens(web,store,dir)}
}
"""
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text()+r"""
@MainActor func visualSwiftFinalDetailScreens(_ web:WKWebView,_ store:NOVASwiftStore,_ dir:URL,_ page:UIViewController){
 func scroll(_ view:UIView)->UIScrollView?{if let s=view as? UIScrollView{return s};for child in view.subviews{if let s=scroll(child){return s}};return nil}
 if let view=scroll(page.view){view.setContentOffset(CGPoint(x:0,y:max(0,view.contentSize.height-view.bounds.height)),animated:false)}
 DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-profile-lower.png");page.overrideUserInterfaceStyle = .dark
 DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-profile-dark.png");page.dismiss(animated:false){
 guard let root=web.window?.rootViewController else{return}
 let task:NOVAJSON = .object(["title":.string("Ripasso funzioni, dominio e grafici"),"subj":.string("Matematica"),"kind":.string("test"),"due":.string("2026-11-03T09:00"),"note":.string("Porta il quaderno e controlla gli esercizi."),"src":.string("cv")])
 let help=UIHostingController(rootView:NOVASwiftTaskHelp(store:store,task:task));help.modalPresentationStyle = .fullScreen;root.present(help,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-task-detail.png");help.overrideUserInterfaceStyle = .dark;DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-task-detail-dark.png");help.dismiss(animated:false){let ai=UIHostingController(rootView:NOVASwiftAssistant(store:store,initialDraft:"Aiutami a prepararmi per la verifica di Matematica."));ai.modalPresentationStyle = .fullScreen;root.present(ai,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-owned-task-ai-draft.png");visualSwiftIntegratedShell(web,dir,0)}}}}}}
 }}}
}
"""
p.write_text(s)

p=Path('/tmp/NOVAProductionVisual.swift')
s=p.read_text()+r"""
@MainActor func visualSwiftIntegratedShell(_ web:WKWebView,_ dir:URL,_ index:Int){
 guard let root=web.window?.rootViewController else{return}
 let folder=FileManager.default.temporaryDirectory.appendingPathComponent("integrated-swift-"+UUID().uuidString)
 let store=NOVASwiftStore(directory:folder)
 let value="{\"name\":\"Studente demo\",\"done\":1,\"introOff\":1,\"theme\":\"light\",\"tasks\":[{\"id\":\"task\",\"title\":\"Ripasso funzioni\",\"due\":\"2026-11-03T17:00\",\"subj\":\"Matematica\",\"rem\":0}],\"gr\":[{\"subj\":\"Matematica\",\"v\":7,\"date\":\"2026-10-20\"}],\"w\":{\"wx\":0,\"sp\":0},\"tt\":{\"lessons\":[]},\"prof\":{\"username\":\"studente.demo\"}}"
 do{try store.importOnce(["nova.v1":value]);let reload=NOVASwiftStore(directory:folder);let original=try JSONDecoder().decode(NOVASwiftArchive.self,from:Data(contentsOf:folder.appendingPathComponent("legacy-import-v1.json")));let checks:[String:Bool]=["shellReloadPreservesPersonalData":reload.archive?.active==store.archive?.active,"immutableOriginalRecoveryRetained":original.localStorage["nova.v1"]==value,"noMigrationServiceOrSharingActivation":store.archive?.active.object?["locShare"]?.flag==false && store.archive?.active.object?["bgLoc"]?.flag==false && store.archive?.active.object?["cv"]==nil];try JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:dir.appendingPathComponent("swift-integrated-checks.txt"))}catch{return}
 root.presentedViewController?.dismiss(animated:false){let page=UIHostingController(rootView:NOVASwiftShell(store:store,initialTab:index));page.modalPresentationStyle = .fullScreen;root.present(page,animated:false){DispatchQueue.main.asyncAfter(deadline:.now()+2){visualProductionSave(web,"production-swift-integrated-tab-"+String(index)+".png");if index<4{visualSwiftIntegratedShell(web,dir,index+1)}else{page.overrideUserInterfaceStyle = .dark;try? store.update(owner:"local"){$0["theme"] = .string("dark")};DispatchQueue.main.asyncAfter(deadline:.now()+1){visualProductionSave(web,"production-swift-integrated-profile-dark.png");visualSwiftImportOrigin(web,dir)}}}}}
}
"""
p.write_text(s)

if os.environ.get('NOVA_ROOT_INTERACTION')=='1':
    p=Path('/tmp/NOVAProductionVisual.swift')
    s=p.read_text()
    assert 'visualSwiftOwnedReady(web,0)' in s, 'Swift root entry point missing'
    s=s.replace('visualSwiftOwnedReady(web,0)','visualSwiftRootInteractionReady(web,0)',1)
    s+='\n'+Path('NOVAInteractionFixture.swift/NOVAInteractionFixture.swift').read_text()
    p.write_text(s)
