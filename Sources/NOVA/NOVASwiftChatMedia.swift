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
@MainActor final class NOVASwiftVoicePlayback:ObservableObject {
    private var player:AVPlayer?
    func play(_ url:URL){player?.pause();try? AVAudioSession.sharedInstance().setCategory(.playback,mode:.default);player=AVPlayer(url:url);player?.play()}
    func stop(){player?.pause();player=nil}
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
