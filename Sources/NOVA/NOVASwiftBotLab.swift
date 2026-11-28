import SwiftUI
import AVFoundation

// Stati animati dell'assistente NOVA (item 13): le vere "Thinking orbs" di
// libraries.dev, vendored come ThinkingOrbsKit (MIT, (c) 2026 Jakub Antalik -
// vedi Sources/NOVA/ThinkingOrbs-LICENSE.txt). Un disegno diverso per stato:
// pensando = working, ricerca = searching, collegando = connecting,
// ascolto = listening. Le etichette italiane restano nostre.
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
}

struct NOVASwiftOrb:View {
    let mood:NOVABotMood
    var size:CGFloat = 56
    private var orbState:OrbState {
        switch mood {
        case .thinking: return .working
        case .searching: return .searching
        case .connecting: return .connecting
        case .listening: return .listening
        }
    }
    var body:some View {
        ThinkingOrb(state:orbState, size:.px64, displaySize:Double(size))
            .frame(width:size,height:size)
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
    func makeUIView(context:Context)->NOVABotCameraPreviewView {
        let view=NOVABotCameraPreviewView();view.backgroundColor = .black
        #if targetEnvironment(simulator)
        // Simulatore: niente layer fotocamera (anteprima comunque nera) cosi' XCUITest legge la gerarchia.
        #else
        let layer=AVCaptureVideoPreviewLayer(session:camera.session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        view.previewLayer=layer
        #endif
        return view
    }
    func updateUIView(_ view:NOVABotCameraPreviewView,context:Context){}
}
final class NOVABotCameraPreviewView:UIView {
    var previewLayer:AVCaptureVideoPreviewLayer?
    override func layoutSubviews(){super.layoutSubviews();CATransaction.begin();CATransaction.setDisableActions(true);previewLayer?.frame=bounds;CATransaction.commit()}
}

struct NOVASwiftBotCameraSheet:View {
    let onCapture:(String)->Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera=NOVABotCamera()
    @State private var shot:UIImage?
    var body:some View {
        ZStack(alignment:.top){
            NOVASwiftBotCameraPreview(camera:camera).ignoresSafeArea()
            if let shot=shot{Image(uiImage:shot).resizable().scaledToFill().ignoresSafeArea()}
            VStack{
                Spacer()
                Text("Inquadra la pagina o l'esercizio").font(.footnote).foregroundStyle(.white).padding(.horizontal,12).padding(.vertical,6).background(.black.opacity(0.55),in:Capsule())
                Button{
                    camera.capture{image in if let image=image{shot=image;let scale=min(1,1200/max(image.size.width,image.size.height));let size=CGSize(width:image.size.width*scale,height:image.size.height*scale);let jpeg=UIGraphicsImageRenderer(size:size).jpegData(withCompressionQuality:0.7){_ in image.draw(in:CGRect(origin:.zero,size:size))};onCapture("data:image/jpeg;base64,"+jpeg.base64EncodedString());dismiss()}}
                }label:{
                    ZStack{Circle().stroke(Color.white.opacity(0.9),lineWidth:4).frame(width:64,height:64);Circle().fill(Color.white).frame(width:50,height:50)}
                }.buttonStyle(.plain).accessibilityLabel("Scatta foto").accessibilityIdentifier("swiftBotCamCapture").padding(.top,14).padding(.bottom,34)
            }
            HStack{Text("Scansiona per NOVA").font(.headline).padding(.horizontal,16).padding(.vertical,12).modifier(NOVASwiftAssistantGlass(circle:false));Spacer();Button("Chiudi"){dismiss()}.font(.body.weight(.medium)).padding(.horizontal,16).padding(.vertical,12).modifier(NOVASwiftAssistantGlass(circle:false)).accessibilityIdentifier("swiftBotCamCancel")}.foregroundStyle(.white).padding(.horizontal,16).padding(.top,22)
        }
        .onAppear{camera.start()}
        .onDisappear{camera.stop()}
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
    var autoOpenCamera=false
    @State private var cameraOpen=false
    private let demo:[(Bool,String)] = [
        (true,"Mi spieghi le derivate per la verifica di domani?"),
        (false,"Certo! Una derivata misura quanto velocemente cambia una funzione. Partiamo dalla definizione con il limite del rapporto incrementale, poi facciamo due esempi sui polinomi."),
        (true,"E come capisco se una funzione è derivabile in un punto?"),
        (true,"dammi il link al suo github"),
        (false,"Ecco il profilo GitHub di **Federico Taranu**: https://github.com/federicotaar (fonte: Web)."),
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
                            Group{if msg.0{Text(msg.1)}else{NOVASwiftAssistantBubbleText(text:msg.1)}}
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
        .sheet(isPresented:$cameraOpen){NOVASwiftBotCameraSheet{data in fixture.attached=data}.presentationDetents([.medium]).presentationDragIndicator(.visible)}
        .onAppear{if autoOpenCamera{DispatchQueue.main.asyncAfter(deadline:.now()+0.8){cameraOpen=true}}}
    }
}
