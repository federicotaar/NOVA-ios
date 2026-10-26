import SwiftUI
import AVFoundation

@MainActor final class NOVASwiftSongs:ObservableObject {
    @Published var results:[NOVAJSON]=[]
    @Published var status=""
    private var generation=0
    private var player:AVPlayer?
    func stop(){generation += 1;player?.pause();player=nil}
    func search(_ query:String) async {
        generation += 1;let expected=generation;let query=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard query.count>=2 else{results=[];status="Scrivi almeno 2 caratteri.";return}
        status="Cerco…"
        do{let result=try await Self.fetch(query);guard generation==expected else{return};results=result;status=result.isEmpty ? "Nessun risultato.":""}catch{if generation==expected{results=[];status="Ricerca non disponibile. Riprova."}}
    }
    static func fetch(_ query:String) async throws -> [NOVAJSON] {
        var parts=URLComponents(string:"https://api.federicotaranu.site/song/search")!;parts.queryItems=[URLQueryItem(name:"q",value:query)]
        let(data,response)=try await URLSession.shared.data(from:parts.url!)
        guard (response as? HTTPURLResponse)?.statusCode==200 else{throw NOVAServiceError.invalidResponse}
        let value=try JSONDecoder().decode(NOVAJSON.self,from:data)
        guard value.object?["ok"]?.flag != false else{throw NOVAServiceError.invalidResponse};return value.object?["results"]?.array ?? []
    }
    func preview(_ song:NOVAJSON) async {
        player?.pause();generation += 1;let expected=generation;status="Carico anteprima…"
        let object=song.object ?? [:],title=object["t"]?.string ?? "",artist=object["a"]?.string ?? ""
        do{
            let found=try await Self.fetch(title+" "+artist)
            func normalized(_ value:String)->String{value.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"en_US_POSIX")).filter{$0.isLetter||$0.isNumber}}
            guard generation==expected else{return}
            guard let hit=found.first(where:{normalized($0.object?["t"]?.string ?? "")==normalized(title) && normalized($0.object?["a"]?.string ?? "")==normalized(artist)}),let address=hit.object?["prev"]?.string,let url=URL(string:address),url.scheme=="https" else{throw NOVAServiceError.invalidResponse}
            try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default);try AVAudioSession.sharedInstance().setActive(true)
            player=AVPlayer(url:url);player?.play();status="Anteprima in riproduzione."
        }catch{if generation==expected{status="Anteprima non disponibile ora."}}
    }
}
@MainActor struct NOVASwiftSongPicker:View {
    @Binding var draft:[String:NOVAJSON]
    @Environment(\.dismiss) var dismiss
    @StateObject private var songs=NOVASwiftSongs()
    @State private var query=""
    var body:some View {
        NavigationStack {
            List {
                HStack{TextField("Titolo o artista",text:$query).autocorrectionDisabled();Button("Cerca"){Task{await songs.search(query)}}}
                if !songs.status.isEmpty{Text(songs.status).font(.footnote).foregroundStyle(.secondary)}
                ForEach(Array(songs.results.enumerated()),id:\.offset){_,song in let o=song.object ?? [:]
                    HStack{if let art=o["art"]?.string,let url=URL(string:art),url.scheme=="https"{AsyncImage(url:url){image in image.resizable().scaledToFill()}placeholder:{Color.secondary.opacity(0.1)}.frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:8))};VStack(alignment:.leading){Text(o["t"]?.string ?? "");Text(o["a"]?.string ?? "").font(.caption).foregroundStyle(.secondary)};Spacer();Button{Task{await songs.preview(song)}}label:{Image(systemName:"play.fill")}.buttonStyle(.bordered).accessibilityLabel("Ascolta anteprima");Button("Scegli"){draft["song"]=song;songs.stop();dismiss()}.buttonStyle(.borderedProminent)}
                }
                Button("Rimuovi canzone",role:.destructive){draft["song"] = .null;songs.stop();dismiss()}
            }.navigationTitle("La tua canzone").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItem(placement:.bottomBar){Button("Ferma anteprima"){songs.stop()}}}
        }.onDisappear{songs.stop()}
    }
}
