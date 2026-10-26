import SwiftUI
import PhotosUI
import Vision
import AVFoundation
import CoreImage.CIFilterBuiltins

@MainActor final class NOVASwiftPeople:ObservableObject {
    @Published private(set) var friends:[NOVAJSON]=[]
    @Published private(set) var incoming:[NOVAJSON]=[]
    @Published private(set) var outgoing:[NOVAJSON]=[]
    @Published private(set) var results:[NOVAJSON]=[]
    @Published private(set) var followers:[NOVAJSON]=[]
    @Published private(set) var following:[NOVAJSON]=[]
    @Published private(set) var profile:NOVAJSON?
    @Published private(set) var status=""
    @Published private(set) var busy=false
    private var epoch=0
    private var searchEpoch=0
    private var profileEpoch=0
    private let transport:NOVASwiftSocial.Transport
    init(transport:NOVASwiftSocial.Transport?=nil){self.transport=transport ?? {owner,path,method,body,query in try await NOVAAccountService(session:owner).request(path,method:method,body:body,query:query)}}
    func reset(){epoch+=1;searchEpoch+=1;profileEpoch+=1;friends=[];incoming=[];outgoing=[];results=[];followers=[];following=[];profile=nil;status="";busy=false}
    func closeProfile(){profileEpoch+=1;profile=nil}
    private func valid(_ store:NOVASwiftStore,_ owner:NOVASession,_ expected:Int)->Bool{epoch==expected && store.archive.flatMap({NOVASession($0.active)})==owner}
    func load(_ store:NOVASwiftStore) async {
        guard let state=store.archive?.active,let owner=NOVASession(state) else{reset();status="Accedi per vedere i tuoi amici.";return};let expected=epoch
        do{let result=try await transport(owner,"friends","GET",nil,[]);guard valid(store,owner,expected) else{return};guard result.object?["ok"]?.flag != false else{throw NOVAServiceError.invalidResponse};friends=result.object?["friends"]?.array ?? [];incoming=result.object?["incoming"]?.array ?? [];outgoing=result.object?["outgoing"]?.array ?? [];status=""}catch{if valid(store,owner,expected){status="Amici non aggiornati. I dati mostrati potrebbero non essere aggiornati."}}
    }
    func search(_ query:String,_ store:NOVASwiftStore) async {
        searchEpoch+=1;let search=searchEpoch,value=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard value.count>=2,let state=store.archive?.active,let owner=NOVASession(state) else{results=[];return};let expected=epoch
        do{let result=try await transport(owner,"users/search","GET",nil,[URLQueryItem(name:"q",value:String(value.prefix(20)))]);guard valid(store,owner,expected),search==searchEpoch else{return};guard result.object?["ok"]?.flag != false else{throw NOVAServiceError.invalidResponse};results=result.object?["users"]?.array ?? [];status=results.isEmpty ? "Nessun utente trovato.":""}catch{if valid(store,owner,expected),search==searchEpoch{status="Ricerca non disponibile."}}
    }
    func lists(_ store:NOVASwiftStore) async {
        guard let state=store.archive?.active,let owner=NOVASession(state) else{return};let expected=epoch
        do{for kind in ["followers","following"]{let result=try await transport(owner,"follows","GET",nil,[URLQueryItem(name:"kind",value:kind)]);guard valid(store,owner,expected) else{return};guard result.object?["ok"]?.flag != false else{throw NOVAServiceError.invalidResponse};if kind=="followers"{followers=result.object?["users"]?.array ?? []}else{following=result.object?["users"]?.array ?? []}}}catch{if valid(store,owner,expected){status="Liste non aggiornate."}}
    }
    func open(_ username:String,_ store:NOVASwiftStore) async {
        profileEpoch+=1;let page=profileEpoch;profile=nil
        guard let state=store.archive?.active,let owner=NOVASession(state) else{return};let expected=epoch
        do{let result=try await transport(owner,"users/profile","GET",nil,[URLQueryItem(name:"u",value:username)]);guard valid(store,owner,expected),page==profileEpoch else{return};guard result.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse};profile=result;status=""}catch{if valid(store,owner,expected),page==profileEpoch{status="Profilo non disponibile ora."}}
    }
    func action(_ operation:String,username:String="",rid:String="",_ store:NOVASwiftStore) async -> Bool {
        guard !busy,["friends/request","friends/accept","friends/remove","follow","unfollow"].contains(operation),let state=store.archive?.active,let owner=NOVASession(state),!username.isEmpty || !rid.isEmpty else{return false}
        if operation=="friends/request"{let name=state.object?["prof"]?.object?["username"]?.string ?? "";guard !name.isEmpty,state.object?["profConfirmed"]?.string==name,state.object?["profPending"]?.flag != true else{status="Salva prima il tuo username online da Modifica profilo.";return false}}
        let expected=epoch;busy=true;defer{if valid(store,owner,expected){busy=false}}
        let body:NOVAJSON = !username.isEmpty ? .object(["username":.string(username)]):.object(["rid":.string(rid)])
        do{let result=try await transport(owner,operation,"POST",body,[]);guard valid(store,owner,expected) else{return false};guard result.object?["ok"]?.flag==true else{throw NOVAServiceError.invalidResponse};status=operation=="friends/request" ? "Richiesta inviata a @"+username:"Modifica confermata.";await load(store);return true}catch{if valid(store,owner,expected){status="Modifica non confermata. Riprova."};return false}
    }
}

struct NOVASwiftAvatar:View {
    let value:String
    let username:String
    var body:some View{Group{if value.hasPrefix("data:image/"),value.count<=120000,let payload=value.split(separator:",",maxSplits:1).last,let bytes=Data(base64Encoded:String(payload)),let image=UIImage(data:bytes){Image(uiImage:image).resizable().scaledToFill()}else{Text(value.count<=8 && !value.isEmpty ? value:String(username.prefix(1)).uppercased()).font(.title3.bold()).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color.blue.opacity(0.12))}}.frame(width:44,height:44).clipShape(Circle())}
}
@MainActor struct NOVASwiftPeopleView:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var people=NOVASwiftPeople()
    @State private var query=""
    @State private var selected:String?
    @State private var showProfile=false
    @State private var qr=false
    @State private var removal:String?
    @State private var confirmRemove=false
    func user(_ item:NOVAJSON)->String{item.object?["username"]?.string ?? ""}
    @ViewBuilder func row(_ item:NOVAJSON) -> some View {let username=user(item);Button{selected=username;showProfile=true}label:{HStack{NOVASwiftAvatar(value:item.object?["avatar"]?.string ?? "",username:username);Text(username.isEmpty ? "Username non disponibile":"@"+username).foregroundStyle(.primary)}}.disabled(username.isEmpty)}
    var body:some View {
        List{
            Section{TextField("Cerca per username",text:$query).textInputAutocapitalization(.never).autocorrectionDisabled();ForEach(Array(people.results.enumerated()),id:\.offset){_,item in row(item)}}
            if !people.incoming.isEmpty{Section("Richieste ricevute"){ForEach(Array(people.incoming.enumerated()),id:\.offset){_,item in VStack(alignment:.leading){row(item);Button("Accetta"){Task{_ = await people.action("friends/accept",username:user(item),rid:item.object?["rid"]?.string ?? "",store)}}.disabled(people.busy)}}}}
            Section("Amici"){if people.friends.isEmpty{Text("Nessun amico ancora.").foregroundStyle(.secondary)};ForEach(Array(people.friends.enumerated()),id:\.offset){_,item in row(item).swipeActions{Button("Rimuovi",role:.destructive){removal=user(item);confirmRemove=true}}}}
            if !people.outgoing.isEmpty{Section("In attesa"){ForEach(Array(people.outgoing.enumerated()),id:\.offset){_,item in row(item).swipeActions{Button("Annulla richiesta",role:.destructive){removal=user(item);confirmRemove=true}}}}}
            Section{NavigationLink("Follower (\(people.followers.count))"){List{ForEach(Array(people.followers.enumerated()),id:\.offset){_,item in row(item)}}.navigationTitle("Follower")};NavigationLink("Seguiti (\(people.following.count))"){List{ForEach(Array(people.following.enumerated()),id:\.offset){_,item in row(item)}}.navigationTitle("Seguiti")};Button("Il mio QR / Scansiona"){qr=true}}
            if !people.status.isEmpty{Text(people.status).font(.footnote).foregroundStyle(.secondary)}
        }.navigationTitle("Amici").task{await people.load(store);await people.lists(store)}.refreshable{await people.load(store);await people.lists(store)}
        .task(id:query){try? await Task.sleep(for:.milliseconds(400));guard !Task.isCancelled else{return};await people.search(query,store)}
        .onChange(of:store.archive?.owner){_,_ in people.reset();query="";showProfile=false;qr=false;Task{await people.load(store);await people.lists(store)}}
        .sheet(isPresented:$showProfile){if let selected=selected{NavigationStack{NOVASwiftPublicProfile(store:store,people:people,username:selected)}}}
        .sheet(isPresented:$qr){NOVASwiftQR(store:store,people:people)}
        .confirmationDialog("Rimuovere l'amicizia o annullare la richiesta?",isPresented:$confirmRemove,titleVisibility:.visible){Button("Conferma",role:.destructive){if let removal=removal{Task{_ = await people.action("friends/remove",username:removal,store)}}};Button("Annulla",role:.cancel){}}
    }
}
@MainActor struct NOVASwiftPublicProfile:View {
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var people:NOVASwiftPeople
    let username:String
    @Environment(\.dismiss) var dismiss
    @StateObject private var songs=NOVASwiftSongs()
    var body:some View {
        List{if let response=people.profile?.object {let profile=response["profile"]?.object ?? [:]
            Section{HStack{NOVASwiftAvatar(value:profile["avatar"]?.string ?? "",username:username);Text("@"+username).font(.title2.bold())};Text("\(response["followers"]?.integer ?? 0) follower · \(response["following"]?.integer ?? 0) seguiti")}
            if response["limited"]?.flag==true{Text("Diventa amico di @"+username+" per vedere il suo profilo completo.")}else{
                ForEach(["study","skills","hobbies"],id:\.self){key in if let text=profile[key]?.string,!text.isEmpty{Section(key=="study" ? "Dove studia":key=="skills" ? "Punti forti":"Hobby"){Text(text)}}}
                if let song=profile["song"],let title=song.object?["t"]?.string{Section("Canzone preferita"){NOVASwiftSongCard(song:song);Button("Ascolta anteprima"){Task{await songs.preview(song)}};Button("Ferma anteprima"){songs.stop()}}}
                if let badges=profile["badges"]?.array,!badges.isEmpty{Section("Badge"){ForEach(Array(badges.enumerated()),id:\.offset){_,badge in Text(badge.string ?? "")}}}
            }
            Section{Button(response["you_follow"]?.flag==true ? "Smetti di seguire":"Segui"){Task{if await people.action(response["you_follow"]?.flag==true ? "unfollow":"follow",username:username,store){await people.open(username,store)}}}.disabled(people.busy);if response["is_friend"]?.flag != true{Button("Aggiungi agli amici"){Task{if await people.action("friends/request",username:username,store){await people.open(username,store)}}}.disabled(people.busy)}}
        }else{Text(people.status.isEmpty ? "Carico…":people.status)}
        if !songs.status.isEmpty{Text(songs.status).font(.footnote)};if !people.status.isEmpty{Text(people.status).font(.footnote)}
        }.navigationTitle("@"+username).toolbar{Button("Chiudi"){dismiss()}}.task{await people.open(username,store)}.onDisappear{people.closeProfile();songs.stop()}.onChange(of:store.archive?.owner){_,_ in dismiss()}
    }
}
@MainActor struct NOVASwiftQR:View {
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var people:NOVASwiftPeople
    @Environment(\.dismiss) var dismiss
    @State private var photo:PhotosPickerItem?
    @State private var pending=""
    @State private var confirm=false
    @State private var camera=false
    @State private var status=""
    @State private var epoch=0
    var username:String{store.archive?.active.object?["prof"]?.object?["username"]?.string ?? ""}
    var code:UIImage? {Self.render(username)}

    static func render(_ username:String)->UIImage? {
        guard !username.isEmpty else{return nil}
        let value="nova:add:"+username.lowercased(),filter=CIFilter.qrCodeGenerator();filter.message=Data(value.utf8);filter.correctionLevel="H"
        guard let output=filter.outputImage,let cg=CIContext().createCGImage(output,from:output.extent.insetBy(dx:1,dy:1)) else{return nil}
        let width=cg.width,bytes=width*width*4
        var pixels=[UInt8](repeating:0,count:bytes)
        guard let context=CGContext(data:&pixels,width:width,height:width,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
        context.translateBy(x:0,y:CGFloat(width));context.scaleBy(x:1,y:-1)
        context.draw(cg,in:CGRect(x:0,y:0,width:width,height:width))
        let scale:CGFloat=12,quiet:CGFloat=4,total=CGFloat(width)+quiet*2,size=total*scale
        let image=UIGraphicsImageRenderer(size:CGSize(width:size,height:size)).image{renderer in
            UIColor.white.setFill();renderer.fill(CGRect(x:0,y:0,width:size,height:size));UIColor.black.setFill()
            for y in 0..<width{for x in 0..<width{
                let finder=(x<7 && y<7)||(x>=width-7 && y<7)||(x<7 && y>=width-7)
                if pixels[(y*width+x)*4]<128 && !finder{let rect=CGRect(x:(CGFloat(x)+quiet)*scale,y:(CGFloat(y)+quiet)*scale,width:scale,height:scale).insetBy(dx:-0.5,dy:-0.5);UIBezierPath(roundedRect:rect,cornerRadius:scale*0.38).fill()}
            }}
            for (x,y) in [(0,0),(width-7,0),(0,width-7)]{
                let rect=CGRect(x:(CGFloat(x)+quiet)*scale,y:(CGFloat(y)+quiet)*scale,width:7*scale,height:7*scale)
                UIColor.black.setFill();UIBezierPath(roundedRect:rect,cornerRadius:scale*0.55).fill();UIColor.white.setFill();UIBezierPath(roundedRect:rect.insetBy(dx:scale,dy:scale),cornerRadius:scale*0.4).fill();UIColor.black.setFill();UIBezierPath(roundedRect:rect.insetBy(dx:2*scale,dy:2*scale),cornerRadius:scale*0.3).fill()
            }
            let side=5*scale,box=CGRect(x:(size-side)/2,y:(size-side)/2,width:side,height:side)
            UIColor.white.setFill();UIBezierPath(roundedRect:box.insetBy(dx:-scale*0.4,dy:-scale*0.4),cornerRadius:scale).fill()
            UIColor.black.setFill();UIBezierPath(roundedRect:box,cornerRadius:scale).fill()
            let attributes:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:side*0.75,weight:.bold),.foregroundColor:UIColor.white]
            let text=NSAttributedString(string:"N",attributes:attributes),textSize=text.size();text.draw(at:CGPoint(x:(size-textSize.width)/2,y:(size-textSize.height)/2))
        }
        return image
    }
    static func parse(_ text:String)->String? {guard text.hasPrefix("nova:add:") else{return nil};let value=String(text.dropFirst(9)).lowercased();guard (3...20).contains(value.count),value.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="_" || $0==".")}) else{return nil};return value}
    var body:some View {NavigationStack{List{Section("Il mio QR"){if let code=code{VStack(spacing:20){Image(uiImage:code).interpolation(.none).resizable().scaledToFit().frame(maxWidth:260).clipShape(RoundedRectangle(cornerRadius:18));Text("@"+username).font(.title3.bold());Text("Fai scansionare il tuo codice per trovarti su NOVA. La richiesta di amicizia richiede conferma.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)}.frame(maxWidth:.infinity).padding(.vertical,20)}else{Text("Scegli prima il tuo username da Modifica profilo.")}};Section("Aggiungi da un QR"){Button{camera=true}label:{Label("Scansiona con la fotocamera",systemImage:"camera")};PhotosPicker(selection:$photo,matching:.images){Label("Leggi QR da una foto",systemImage:"qrcode.viewfinder")};Text("La lettura propone lo username. La richiesta parte solo dopo la tua conferma.").font(.footnote).foregroundStyle(.secondary)};if !status.isEmpty{Text(status)};if !people.status.isEmpty{Text(people.status)}}.navigationTitle("QR amici").toolbar{Button("Chiudi"){dismiss()}}}
        .sheet(isPresented:$camera){NOVASwiftQRScanner{value in camera=false;if let name=Self.parse(value){pending=name;confirm=true}else{status="QR NOVA non riconosciuto."}}}
        .confirmationDialog("Inviare una richiesta di amicizia a @"+pending+"?",isPresented:$confirm,titleVisibility:.visible){Button("Invia richiesta"){let user=pending;Task{_ = await people.action("friends/request",username:user,store)}};Button("Annulla",role:.cancel){}}
        .onChange(of:photo){_,item in epoch+=1;let expected=epoch,owner=store.archive.flatMap({NOVASession($0.active)});Task{guard let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data),let cg=image.cgImage else{return};let request=VNDetectBarcodesRequest();request.symbologies=[.qr];do{try VNImageRequestHandler(cgImage:cg).perform([request]);guard expected==epoch,store.archive.flatMap({NOVASession($0.active)})==owner else{return};guard let text=request.results?.first?.payloadStringValue,let name=Self.parse(text) else{status="QR NOVA non riconosciuto.";return};pending=name;confirm=true}catch{if expected==epoch{status="QR non letto. Scegli una foto più nitida."}}}}
        .onDisappear{epoch+=1}.onChange(of:store.archive?.owner){_,_ in epoch+=1;dismiss()}
    }
}

@MainActor struct NOVASwiftQRScanner:UIViewControllerRepresentable {
    let found:(String)->Void
    func makeUIViewController(context:Context)->NOVASwiftQRScannerController{let page=NOVASwiftQRScannerController();page.found=found;return page}
    func updateUIViewController(_ page:NOVASwiftQRScannerController,context:Context){}
    static func dismantleUIViewController(_ page:NOVASwiftQRScannerController,coordinator:()){page.stop()}
}
@MainActor final class NOVASwiftQRScannerController:UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    var found:((String)->Void)?
    private let session=AVCaptureSession()
    private var preview:AVCaptureVideoPreviewLayer?
    private let label=UILabel()
    private var closed=false
    private var delivered=false
    override func viewDidLoad(){super.viewDidLoad();view.backgroundColor = .black;label.text="Consenti la fotocamera per leggere il QR NOVA.";label.textColor = .white;label.numberOfLines=0;label.textAlignment = .center;view.addSubview(label)
        Task{let allowed=await AVCaptureDevice.requestAccess(for:.video);guard !closed else{return};guard allowed else{label.text="Fotocamera non autorizzata. Puoi leggere un QR da una foto.";return};configure()}
    }
    private func configure(){guard let device=AVCaptureDevice.default(for:.video),let input=try? AVCaptureDeviceInput(device:device),session.canAddInput(input) else{label.text="Fotocamera non disponibile.";return};session.addInput(input);let output=AVCaptureMetadataOutput();guard session.canAddOutput(output) else{label.text="Lettura QR non disponibile.";return};session.addOutput(output);output.setMetadataObjectsDelegate(self,queue:.main);output.metadataObjectTypes=[.qr];let layer=AVCaptureVideoPreviewLayer(session:session);layer.videoGravity = .resizeAspectFill;view.layer.insertSublayer(layer,at:0);preview=layer;label.text="Inquadra il QR NOVA. Nessuna richiesta viene inviata senza conferma.";view.setNeedsLayout();session.startRunning()}
    override func viewDidLayoutSubviews(){super.viewDidLayoutSubviews();preview?.frame=view.bounds;label.frame=CGRect(x:24,y:view.safeAreaInsets.top+24,width:view.bounds.width-48,height:96)}
    func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput metadataObjects:[AVMetadataObject],from connection:AVCaptureConnection){guard !closed,!delivered,let value=(metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else{return};delivered=true;session.stopRunning();found?(value)}
    func stop(){closed=true;session.stopRunning();found=nil}
    override func viewWillDisappear(_ animated:Bool){super.viewWillDisappear(animated);stop()}
}
