import SwiftUI
import AVFoundation

// Stati animati dell'assistente NOVA (proposta item 13): l'orbe cambia colore
// e movimento in base a cosa sta facendo il bot.
enum NOVABotMood:String,CaseIterable {
    case thinking, searching, connecting, listening
    var title:String {
        switch self {
        case .thinking: return "Sta pensando…"
        case .searching: return "Cerco sul web…"
        case .connecting: return "Collegando…"
        case .listening: return "Ti ascolto…"
        }
    }
    var colors:[Color] {
        switch self {
        case .thinking: return [Color(red:0.44,green:0.48,blue:1.0),Color(red:0.68,green:0.45,blue:1.0)]
        case .searching: return [Color(red:0.20,green:0.85,blue:0.55),Color(red:0.30,green:0.65,blue:1.0)]
        case .connecting: return [Color(red:1.0,green:0.65,blue:0.30),Color(red:1.0,green:0.45,blue:0.55)]
        case .listening: return [Color(red:1.0,green:0.35,blue:0.55),Color(red:0.65,green:0.40,blue:1.0)]
        }
    }
    var pulse:Double { self == .listening ? 6.0 : 2.2 }
}

struct NOVASwiftOrb:View {
    let mood:NOVABotMood
    var size:CGFloat = 56
    var body:some View {
        TimelineView(.animation){timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack{
                Circle().fill(mood.colors[0]).frame(width:size*0.92,height:size*0.92)
                    .offset(x:CGFloat(sin(t*1.3))*size*0.12,y:CGFloat(cos(t*1.1))*size*0.12)
                    .blur(radius:size*0.20)
                Circle().fill(mood.colors[1]).frame(width:size*0.74,height:size*0.74)
                    .offset(x:CGFloat(cos(t*0.9+1.0))*size*0.14,y:CGFloat(sin(t*1.4+2.0))*size*0.14)
                    .blur(radius:size*0.16)
                Circle().fill(Color.white.opacity(0.85)).frame(width:size*0.26,height:size*0.26)
                    .offset(y:CGFloat(sin(t*2.0))*size*0.05)
                    .blur(radius:size*0.08)
            }
            .frame(width:size,height:size)
            .scaleEffect(1.0+0.04*CGFloat(sin(t*mood.pulse)))
        }
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("Stato assistente: \(mood.title)")
        .accessibilityIdentifier("swiftOrb"+mood.rawValue.capitalized)
    }
}

// Fotocamera stile scanner per l'assistente (proposta item 12): anteprima live
// con cornice da scansione, scatto che torna al composer come foto allegata.
@MainActor final class NOVABotCamera:NSObject, ObservableObject {
    @Published var frame:UIImage?
    @Published var ready=false
    let session=AVCaptureSession()
    private let output=AVCapturePhotoOutput()
    private var completion:((UIImage?)->Void)?

    func start(){
        #if targetEnvironment(simulator)
        return
        #endif
        guard AVCaptureDevice.authorizationStatus(for:.video) == .authorized else{return}
        guard !session.isRunning else{return}
        DispatchQueue.global(qos:.userInitiated).async{[weak self] in
            guard let self=self else{return}
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            if let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.back),let input=try? AVCaptureDeviceInput(device:device),self.session.canAddInput(input){self.session.addInput(input)}
            if self.session.canAddOutput(self.output){self.session.addOutput(self.output)}
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async{self.ready=true}
        }
    }
    func stop(){if session.isRunning{DispatchQueue.global(qos:.utility).async{[weak self] in self?.session.stopRunning()}}}
    func capture(_ done:@escaping (UIImage?)->Void){
        completion=done
        let settings=AVCapturePhotoSettings()
        output.capturePhoto(with:settings,delegate:self)
    }
}
extension NOVABotCamera:AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?){
        let image=photo.fileDataRepresentation().flatMap{UIImage(data:$0)}
        Task{@MainActor in self.completion?(image);self.completion=nil}
    }
}

struct NOVASwiftBotCameraPreview:UIViewRepresentable {
    @ObservedObject var camera:NOVABotCamera
    func makeUIView(context:Context)->UIView {
        let view=UIView();view.backgroundColor = .black
        #if targetEnvironment(simulator)
        // Simulatore: niente layer fotocamera (anteprima comunque nera) cosi' XCUITest legge la gerarchia.
        #else
        let layer=AVCaptureVideoPreviewLayer(session:camera.session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.layer=layer
        #endif
        return view
    }
    func updateUIView(_ view:UIView,context:Context){context.coordinator.layer?.frame=view.bounds}
    func makeCoordinator()->Coordinator{Coordinator()}
    final class Coordinator { var layer:AVCaptureVideoPreviewLayer? }
}

struct NOVASwiftBotCameraSheet:View {
    let onCapture:(String)->Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera=NOVABotCamera()
    @State private var shot:UIImage?
    var body:some View {
        VStack(spacing:14){
            HStack{
                Button("Annulla"){dismiss()}.accessibilityIdentifier("swiftBotCamCancel")
                Spacer()
                Text("Scansiona per NOVA").font(.headline)
                Spacer()
                Button("Annulla"){dismiss()}.hidden()
            }
            ZStack{
                NOVASwiftBotCameraPreview(camera:camera)
                    .clipShape(RoundedRectangle(cornerRadius:24))
                if let shot=shot{Image(uiImage:shot).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius:24))}
                NOVASwiftScannerCorners().stroke(Color.white,lineWidth:4).padding(26)
                VStack{Spacer();Text("Inquadra la pagina o l'esercizio dentro la cornice").font(.footnote).foregroundStyle(.white).padding(.horizontal,12).padding(.vertical,6).background(.black.opacity(0.55),in:Capsule()).padding(.bottom,14)}
            }
            .frame(maxWidth:.infinity)
            .layoutPriority(1)
            Button{
                camera.capture{image in if let image=image{shot=image;let scale=min(1,1200/max(image.size.width,image.size.height));let size=CGSize(width:image.size.width*scale,height:image.size.height*scale);let jpeg=UIGraphicsImageRenderer(size:size).jpegData(withCompressionQuality:0.7){_ in image.draw(in:CGRect(origin:.zero,size:size))};onCapture("data:image/jpeg;base64,"+jpeg.base64EncodedString());dismiss()}}
            }label:{
                ZStack{Circle().stroke(Color.primary.opacity(0.35),lineWidth:4).frame(width:64,height:64);Circle().fill(Color.primary).frame(width:50,height:50)}
            }.buttonStyle(.plain).accessibilityLabel("Scatta foto").accessibilityIdentifier("swiftBotCamCapture")
        }
        .padding()
        .onAppear{camera.start()}
        .onDisappear{camera.stop()}
    }
}

struct NOVASwiftScannerCorners:Shape {
    func path(in rect:CGRect)->Path {
        var p=Path();let l:CGFloat=30
        p.move(to:CGPoint(x:rect.minX,y:rect.minY+l));p.addLine(to:CGPoint(x:rect.minX,y:rect.minY));p.addLine(to:CGPoint(x:rect.minX+l,y:rect.minY))
        p.move(to:CGPoint(x:rect.maxX-l,y:rect.minY));p.addLine(to:CGPoint(x:rect.maxX,y:rect.minY));p.addLine(to:CGPoint(x:rect.maxX,y:rect.minY+l))
        p.move(to:CGPoint(x:rect.maxX,y:rect.maxY-l));p.addLine(to:CGPoint(x:rect.maxX,y:rect.maxY));p.addLine(to:CGPoint(x:rect.maxX-l,y:rect.maxY))
        p.move(to:CGPoint(x:rect.minX+l,y:rect.maxY));p.addLine(to:CGPoint(x:rect.minX,y:rect.maxY));p.addLine(to:CGPoint(x:rect.minX,y:rect.maxY-l))
        return p
    }
}

// Anteprima del redesign della chat del bot (item 13): orbe di stato in testa,
// bolle rinnovate, composer con fotocamera scanner a meta schermo.
@MainActor final class NOVABotLabFixture:ObservableObject {
    static let shared=NOVABotLabFixture()
    @Published var attached:String?
}

struct NOVASwiftBotChatPreview:View {
    let mood:NOVABotMood
    @ObservedObject var fixture:NOVABotLabFixture
    @State private var cameraOpen=false
    private let demo:[(Bool,String)] = [
        (true,"Mi spieghi le derivate per la verifica di domani?"),
        (false,"Certo! Una derivata misura quanto velocemente cambia una funzione. Partiamo dalla definizione con il limite del rapporto incrementale, poi facciamo due esempi sui polinomi."),
        (true,"E come capisco se una funzione è derivabile in un punto?"),
    ]
    var body:some View {
        VStack(spacing:0){
            VStack(spacing:6){
                NOVASwiftOrb(mood:mood,size:64)
                Text(mood.title).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }.padding(.top,18).padding(.bottom,10)
            ScrollView{
                LazyVStack(alignment:.leading,spacing:12){
                    ForEach(Array(demo.enumerated()),id:\.offset){_,msg in
                        HStack{
                            if msg.0{Spacer(minLength:40)}
                            Text(msg.1)
                                .padding(.horizontal,14).padding(.vertical,10)
                                .background(msg.0 ? Color.accentColor.opacity(0.16):Color.secondary.opacity(0.10),in:RoundedRectangle(cornerRadius:20))
                                .foregroundStyle(.primary)
                            if !msg.0{Spacer(minLength:40)}
                        }
                    }
                }.padding(.horizontal)
            }
            if let attached=fixture.attached,let data=Data(base64Encoded:attached.components(separatedBy:",").last ?? ""),let ui=UIImage(data:data){
                HStack{Image(uiImage:ui).resizable().scaledToFit().frame(height:72).clipShape(RoundedRectangle(cornerRadius:12));Text("Foto allegata").font(.footnote).foregroundStyle(.secondary);Spacer()}.padding(.horizontal)
            }
            HStack(spacing:10){
                Button{cameraOpen=true}label:{Image(systemName:"camera").font(.system(size:20)).frame(width:42,height:42).contentShape(Circle())}
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scansiona con la fotocamera")
                    .accessibilityIdentifier("swiftBotCamOpen")
                Text("Scrivi un messaggio…").foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,14).padding(.vertical,10)
                    .background(Color.secondary.opacity(0.10),in:Capsule())
            }.padding(.horizontal,14).padding(.vertical,10)
        }
        .navigationTitle("NOVA").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented:$cameraOpen){NOVASwiftBotCameraSheet{data in fixture.attached=data}.presentationDetents([.medium])}
    }
}
