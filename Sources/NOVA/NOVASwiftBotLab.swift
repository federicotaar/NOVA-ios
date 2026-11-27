import SwiftUI
import AVFoundation

// Stati animati dell'assistente NOVA (item 13): un disegno diverso per stato,
// replicati in nativo dai "Thinking orbs" di libraries.dev (niente libreria:
// i kit Pro sono a pagamento). Pensando = cupola di barre verticali che
// ondeggiano; ricerca = sfera di punti; collegando = arco aperto che ruota;
// ascolto = sfera con cupola luminosa che pulsa.
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

private struct NOVAOrbDot { var sx:CGFloat; var sy:CGFloat; var d:CGFloat; var o:Double; var tx:CGFloat; var ty:CGFloat }

private let NOVAOrbBasePoints:[(x:Double,y:Double,z:Double)]=(0..<207).map{i in
    let fi=Double(i)
    let y=1.0-2.0*(fi+0.5)/207.0
    let r=(1.0-y*y).squareRoot()
    let th=fi*2.399963229728653
    return (cos(th)*r,y,sin(th)*r)
}

private struct NOVAOrbCanvas:View {
    let mood:NOVABotMood
    let t:Double
    var body:some View {
        Canvas{context,rect in
            let cx=rect.width/2, cy=rect.height/2
            let R=rect.width*0.40
            let ink=Color.primary
            switch mood {
            case .searching, .listening:
                // Sfera di punti: ricerca con luce uniforme, ascolto con cupola luminosa che pulsa.
                let tilt=0.42
                let a=t*mood.speed
                let persp=3.2
                let pulse=0.5+0.5*sin(t*2.4)
                var dots:[NOVAOrbDot]=[]
                dots.reserveCapacity(NOVAOrbBasePoints.count)
                for p in NOVAOrbBasePoints {
                    let xr=p.x*cos(a)+p.z*sin(a)
                    let zr = -p.x*sin(a)+p.z*cos(a)
                    let y=p.y*cos(tilt)-zr*sin(tilt)
                    let z=p.y*sin(tilt)+zr*cos(tilt)
                    let scale=persp/(persp-z)
                    let dot=Double(rect.width)*0.045*scale
                    var opacity=0.25+0.75*((z+1)/2)
                    var rScale=1.0
                    if mood == .listening {
                        let cap=0.5-0.5*y
                        opacity*=0.15+0.85*cap*(0.45+0.55*pulse)
                        rScale=1.0+0.04*sin(t*2.4)
                    }
                    let sx=cx+CGFloat(xr*scale*rScale)*R
                    let sy=cy+CGFloat(y*scale*rScale)*R
                    dots.append(NOVAOrbDot(sx:sx,sy:sy,d:CGFloat(max(dot,Double(rect.width)*0.012)),o:opacity,tx:sx,ty:sy))
                }
                dots.sort{ $0.o < $1.o }
                for dot in dots {
                    context.fill(Path(CGRect(x:dot.sx-dot.d/2,y:dot.sy-dot.d/2,width:dot.d,height:dot.d)),with:.color(ink.opacity(dot.o)))
                }
            case .thinking:
                // Cupola di barre verticali che ondeggiano (look "Thinking" del sito).
                let bw=Double(rect.width)*0.030
                let sp=Double(rect.width)*0.075
                var bars:[NOVAOrbBar]=[]
                for gx in -5...5 {
                    for gy in -4...4 {
                        let fx=Double(gx), fy=Double(gy)
                        let rr=(fx*fx+fy*fy).squareRoot()
                        if rr>5.4 {continue}
                        let wave=0.5+0.5*sin(t*2.8+fx*0.85+fy*0.5)
                        let h=(0.25+0.75*wave)*Double(rect.width)*0.16
                        let fall=1.0-rr/6.2
                        let o=(0.25+0.75*fall)*(0.35+0.65*wave)
                        bars.append(NOVAOrbBar(x:Double(cx)+fx*sp,y:Double(cy)+fy*sp*0.82,w:bw,h:h,o:o))
                    }
                }
                bars.sort{ $0.o < $1.o }
                for bar in bars {
                    let r2=CGRect(x:CGFloat(bar.x-bar.w/2),y:CGFloat(bar.y-bar.h/2),width:CGFloat(bar.w),height:CGFloat(bar.h))
                    context.fill(Path(roundedRect:r2,cornerRadius:CGFloat(bar.w/2)),with:.color(ink.opacity(bar.o)))
                }
            case .connecting:
                // Arco aperto di punti che ruota con testa luminosa (look "Connecting" del sito).
                let n=44
                let head=t*2.0
                for i in 0..<n {
                    let th=Double(i)/Double(n)*Double.pi*2+t*0.55
                    var rel=(head-th).truncatingRemainder(dividingBy:Double.pi*2)
                    if rel<0 {rel += Double.pi*2}
                    let b=1.0-rel/(Double.pi*1.7)
                    if b<=0.22 {continue}
                    let dot=Double(rect.width)*(0.020+0.030*b)
                    let sx=cx+CGFloat(cos(th))*R
                    let sy=cy+CGFloat(sin(th)*0.92)*R
                    context.fill(Path(CGRect(x:sx-CGFloat(dot/2),y:sy-CGFloat(dot/2),width:CGFloat(dot),height:CGFloat(dot))),with:.color(ink.opacity(0.15+0.85*b)))
                }
                for k in 0..<2 {
                    let th=t*0.9+Double(k)*Double.pi
                    let rr=0.35+0.10*sin(t*1.4+Double(k)*2.0)
                    let dot=Double(rect.width)*0.022
                    let sx=cx+CGFloat(cos(th)*rr)*R
                    let sy=cy+CGFloat(sin(th)*rr*0.92)*R
                    context.fill(Path(CGRect(x:sx-CGFloat(dot/2),y:sy-CGFloat(dot/2),width:CGFloat(dot),height:CGFloat(dot))),with:.color(ink.opacity(0.5)))
                }
            }
        }
    }
}

private struct NOVAOrbBar { var x:Double; var y:Double; var w:Double; var h:Double; var o:Double }

struct NOVASwiftOrb:View {
    let mood:NOVABotMood
    var size:CGFloat = 56
    var body:some View {
        TimelineView(.animation(minimumInterval:1.0/30)){timeline in
            NOVAOrbCanvas(mood:mood,t:timeline.date.timeIntervalSinceReferenceDate)
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
