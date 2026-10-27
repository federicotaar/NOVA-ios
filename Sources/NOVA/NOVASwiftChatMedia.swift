import SwiftUI
import PhotosUI
import AVFoundation

@MainActor final class NOVASwiftVoice:ObservableObject {
    @Published private(set) var recording=false
    @Published var draft:Data?
    @Published var status=""
    private var recorder:AVAudioRecorder?
    private var file:URL?
    private var timer:Task<Void,Never>?
    private var generation=0
    func start() async {
        generation += 1;let expected=generation
        let allowed=await withCheckedContinuation{continuation in AVAudioSession.sharedInstance().requestRecordPermission{continuation.resume(returning:$0)}}
        guard expected==generation else{return};guard allowed else{status="Microfono non autorizzato nelle impostazioni di iOS.";return}
        do{
            let session=AVAudioSession.sharedInstance();try session.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker]);try session.setActive(true)
            let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".m4a");file=url
            recorder=try AVAudioRecorder(url:url,settings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:22050,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:64000])
            guard recorder?.record()==true else{throw CocoaError(.fileWriteUnknown)};recording=true;status="Registrazione: massimo 60 secondi."
            timer=Task{try? await Task.sleep(for:.seconds(60));guard expected==generation,!Task.isCancelled else{return};finish()}
        }catch{status="Registrazione non avviata.";cancel()}
    }
    func finish(){recorder?.stop();recording=false;timer?.cancel();timer=nil;if let file=file,let data=try? Data(contentsOf:file),data.count>=500,data.count<=900000{draft=data;status="Vocale in bozza: invia o elimina."}else{draft=nil;status="Registrazione troppo corta o troppo grande."};if let file=file{try? FileManager.default.removeItem(at:file)};file=nil;recorder=nil}
    func cancel(){generation += 1;recorder?.stop();recorder=nil;recording=false;timer?.cancel();timer=nil;draft=nil;if let file=file{try? FileManager.default.removeItem(at:file)};file=nil}
}
final class NOVAMediaRedirectGuard:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){guard let url=request.url,url.scheme=="https",url.host=="api.federicotaranu.site",url.path.hasPrefix("/media/") else{completionHandler(nil);return};completionHandler(request)}
}
enum NOVASwiftPrivateMedia {
    static func load(_ url:URL,session:NOVASession,audio:Bool) async throws -> Data {
        guard url.scheme=="https",url.host=="api.federicotaranu.site",url.path.hasPrefix("/media/") else{throw NOVAServiceError.invalidResponse}
        var request=URLRequest(url:url);request.timeoutInterval=25;request.cachePolicy = .reloadIgnoringLocalCacheData;request.setValue("Bearer "+session.token,forHTTPHeaderField:"Authorization")
        let config=URLSessionConfiguration.ephemeral;let source=URLSession(configuration:config,delegate:NOVAMediaRedirectGuard(),delegateQueue:nil);defer{source.invalidateAndCancel()}
        let (stream,response)=try await source.bytes(for:request)
        guard let http=response as? HTTPURLResponse else{throw NOVAServiceError.invalidResponse}
        guard (200..<300).contains(http.statusCode) else{throw NOVAServiceError.http(http.statusCode,"Media non disponibile")}
        let mime=(http.mimeType ?? "").lowercased();guard audio ? ["audio/mp4","audio/mpeg","audio/wav","audio/x-wav","audio/aac","audio/webm","audio/ogg"].contains(mime):["image/jpeg","image/png","image/webp","image/heic","image/gif"].contains(mime) else{throw NOVAServiceError.invalidResponse}
        guard response.expectedContentLength<=1_050_000 else{throw NOVAServiceError.invalidResponse}
        var data=Data();for try await byte in stream{try Task.checkCancellation();guard data.count<1_050_000 else{throw NOVAServiceError.invalidResponse};data.append(byte)}
        guard data.count>=100 else{throw NOVAServiceError.invalidResponse};return data
    }
}
@MainActor struct NOVASwiftPrivateImage:View {
    let url:URL
    @ObservedObject var store:NOVASwiftStore
    @State private var image:UIImage?
    @State private var failed=false
    @State private var retry=0
    var body:some View {Group{if let image=image{Image(uiImage:image).resizable().scaledToFit()}else if failed{Button("Foto non caricata. Riprova"){retry+=1}.font(.caption)}else{ProgressView()}}
        .task(id:"\(url)-\(store.archive?.owner ?? "")-\(store.archive?.active.object?["acct"]?.object?["token"]?.string ?? "")-\(retry)"){
            image=nil;failed=false;guard let owner=store.archive.flatMap({NOVASession($0.active)}) else{failed=true;return}
            do{let data=try await NOVASwiftPrivateMedia.load(url,session:owner,audio:false);guard !Task.isCancelled,store.archive.flatMap({NOVASession($0.active)})==owner else{return};guard let decoded=UIImage(data:data) else{failed=true;return};image=decoded}catch{if !Task.isCancelled{failed=true}}
        }
    }
}
@MainActor final class NOVASwiftVoicePlayback:ObservableObject {
    @Published private(set) var status=""
    @Published private(set) var loading=false
    private var player:AVAudioPlayer?
    private var task:Task<Void,Never>?
    private var generation=0
    typealias Loader=(URL,NOVASession) async throws -> Data
    private let loader:Loader
    init(loader:Loader?=nil){self.loader=loader ?? {url,session in try await NOVASwiftPrivateMedia.load(url,session:session,audio:true)}}

    func play(_ url:URL,_ store:NOVASwiftStore){
        stop();guard let owner=store.archive.flatMap({NOVASession($0.active)}) else{status="Accedi per ascoltare il vocale.";return}
        let expected=generation;loading=true;status="Caricamento vocale…"
        task=Task{do{
            let bytes=try await loader(url,owner)
            guard !Task.isCancelled,expected==generation,store.archive.flatMap({NOVASession($0.active)})==owner else{if expected==generation{loading=false;status=""};return}
            let audio=AVAudioSession.sharedInstance();try audio.setCategory(.playback,mode:.default);try audio.setActive(true)
            let candidate=try AVAudioPlayer(data:bytes);candidate.prepareToPlay();guard candidate.play() else{throw NOVAServiceError.invalidResponse};player=candidate;loading=false;status="Riproduzione vocale."
        }catch{guard !Task.isCancelled,expected==generation else{return};loading=false;status="Vocale non riprodotto. Controlla la connessione e riprova."}}
    }
    func stop(){generation+=1;task?.cancel();task=nil;player?.stop();player=nil;loading=false;status=""}
}
@MainActor struct NOVASwiftChatCreation:View {
    @ObservedObject var store:NOVASwiftStore
    @ObservedObject var social:NOVASwiftSocial
    @Environment(\.dismiss) var dismiss
    @State private var selected:Set<String>=[]
    @State private var name=""
    @State private var hasExam=false
    @State private var exam=Date()
    @State private var busy=false
    var body:some View {
        NavigationStack{Form{
            Section("Scegli gli amici"){
                if social.friends.isEmpty{Text("Aggiungi prima un amico dal profilo.").foregroundStyle(.secondary)}
                ForEach(Array(social.friends.enumerated()),id:\.offset){_,friend in let username=friend.object?["username"]?.string ?? "";Toggle("@"+username,isOn:Binding(get:{selected.contains(username)},set:{if $0{selected.insert(username)}else{selected.remove(username)}}))}
            }
            if selected.count>1{Section("Gruppo"){TextField("Nome gruppo",text:$name);Toggle("Data esame",isOn:$hasExam);if hasExam{DatePicker("Esame",selection:$exam,displayedComponents:.date)}}}
            if !social.status.isEmpty{Text(social.status).font(.footnote).foregroundStyle(.secondary)}
        }.navigationTitle("Nuova chat").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Crea"){busy=true;Task{if await social.create(selected.sorted(),name:name,exam:hasExam ? exam:nil,store) != nil{dismiss()};busy=false}}.disabled(selected.isEmpty||busy)}}.task{await social.loadFriends(store)}}
    }
}
