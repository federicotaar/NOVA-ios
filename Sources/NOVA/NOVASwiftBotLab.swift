import SwiftUI
import AVFoundation

// Stati animati dell'assistente NOVA (item 13): orbe di punti su sfera che
// replica in nativo il look e il moto dei "Thinking orbs" di libraries.dev
// (niente libreria: i kit Pro sono a pagamento). ~200 punti quadrati su un
// reticolo di Fibonacci, proiezione prospettica, profondita' in scala e
// opacita'; ogni stato ha il suo movimento caratteristico.
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
    var speed:Double {
        switch self {
        case .thinking: return 2.4
        case .searching: return 0.9
        case .connecting: return 0.7
        case .listening: return 0.45
        }
    }
}

struct NOVASwiftOrb:View {
    let mood:NOVABotMood
    var size:CGFloat = 56
    private let count=207
    var body:some View {
        TimelineView(.animation){timeline in
            let t=timeline.date.timeIntervalSinceReferenceDate
            Canvas{context,rect in
                let cx=rect.midX, cy=rect.midY
                var R=rect.width*0.40
                if mood == .listening { R *= 1.0+0.04*sin(t*2.2) }
                let tilt=0.42
                let a=t*mood.speed
                let persp=3.2
                struct Dot { var sx:CGFloat; var sy:CGFloat; var d:CGFloat; var o:Double; var tx:CGFloat; var ty:CGFloat }
                var dots:[Dot]=[]
                dots.reserveCapacity(count)
                for i in 0..<count {
                    let fi=Double(i)
                    let y0=1.0-2.0*(fi+0.5)/Double(count)
                    let rr=(1.0-y0*y0).squareRoot()
                    let th=fi*2.399963229728653
                    let x0=cos(th)*rr, z0=sin(th)*rr
                    let xr=x0*cos(a)+z0*sin(a)
                    let zr = -x0*sin(a)+z0*cos(a)
                    let y=y0*cos(tilt)-zr*sin(tilt)
                    let z=y0*sin(tilt)+zr*cos(tilt)
                    let scale=persp/(persp-z)
                    var dot=Double(rect.width)*0.045*scale
                    var opacity=0.25+0.75*((z+1)/2)
                    switch mood {
                    case .thinking:
                        let sweep=a.truncatingRemainder(dividingBy:Double.pi*2)
                        var rel=(sweep-atan2(z,xr)).truncatingRemainder(dividingBy:Double.pi*2)
                        if rel<0 {rel += Double.pi*2}
                        if rel<1.5 {opacity*=0.10+0.90*(rel/1.5)}
                    case .connecting:
                        opacity*=0.55+0.45*sin(t*3.0-atan2(z,xr)*2.0)
                    case .listening:
                        dot*=1.0+0.45*sin(t*5.2-(x0+y0+z0)*3.0)
                    case .searching:
                        break
                    }
                    let sx=cx+CGFloat(xr*scale)*R
                    let sy=cy+CGFloat(y*scale)*R
                    var tx=sx, ty=sy
                    if mood == .thinking {
                        let a2=a-0.10
                        let x2=x0*cos(a2)+z0*sin(a2)
                        let z2r = -x0*sin(a2)+z0*cos(a2)
                        let y2=y0*cos(tilt)-z2r*sin(tilt)
                        let z2=y0*sin(tilt)+z2r*cos(tilt)
                        let scale2=persp/(persp-z2)
                        tx=cx+CGFloat(x2*scale2)*R
                        ty=cy+CGFloat(y2*scale2)*R
                    }
                    dots.append(Dot(sx:sx,sy:sy,d:CGFloat(max(dot,Double(rect.width)*0.012)),o:opacity,tx:tx,ty:ty))
                }
                // Algoritmo del pittore: prima i punti sul retro.
                dots.sort{ $0.o < $1.o }
                let ink=Color.primary
                for dot in dots {
                    if mood == .thinking {
                        var path=Path();path.move(to:CGPoint(x:dot.tx,y:dot.ty));path.addLine(to:CGPoint(x:dot.sx,y:dot.sy))
                        context.stroke(path,with:.color(ink.opacity(dot.o*0.6)),lineWidth:max(dot.d*0.7,1))
                    }
                    context.fill(Path(CGRect(x:dot.sx-dot.d/2,y:dot.sy-dot.d/2,width:dot.d,height:dot.d)),with:.color(ink.opacity(dot.o)))
                }
            }
            .frame(width:size,height:size)
        }
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
        .sheet(isPresented:$cameraOpen){NOVASwiftBotCameraSheet{data in fixture.attached=data}.presentationDetents([.medium]).presentationDragIndicator(.visible)}
        .onAppear{if autoOpenCamera{DispatchQueue.main.asyncAfter(deadline:.now()+0.8){cameraOpen=true}}}
    }
}
