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
                    HStack{NOVASwiftSongArtwork(song:song,size:56);VStack(alignment:.leading){Text(o["t"]?.string ?? "");Text(o["a"]?.string ?? "").font(.caption).foregroundStyle(.secondary)};Spacer();Button{Task{await songs.preview(song)}}label:{Image(systemName:"play.fill")}.buttonStyle(.bordered).accessibilityLabel("Ascolta anteprima");Button("Scegli"){draft["song"]=song;songs.stop();dismiss()}.buttonStyle(.borderedProminent)}
                }
                Button("Rimuovi canzone",role:.destructive){draft["song"] = .null;songs.stop();dismiss()}
            }.navigationTitle("La tua canzone").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItem(placement:.bottomBar){Button("Ferma anteprima"){songs.stop()}}}
        }.onDisappear{songs.stop()}
    }
}

struct NOVASwiftSongArtwork:View {
    let song:NOVAJSON
    var size:CGFloat=76
    var body:some View{
        Group{if let address=song.object?["art"]?.string,let url=URL(string:address),url.scheme=="https"{
            AsyncImage(url:url){phase in if let image=phase.image{image.resizable().scaledToFill()}else{placeholder}}
        }else{placeholder}}.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.16)).accessibilityLabel("Copertina di "+(song.object?["t"]?.string ?? "canzone"))
    }
    var placeholder:some View{ZStack{LinearGradient(colors:[.pink.opacity(0.55),.purple.opacity(0.5)],startPoint:.topLeading,endPoint:.bottomTrailing);Image(systemName:"music.note").font(.system(size:size*0.35,weight:.medium)).foregroundStyle(.white)}}
}
struct NOVASwiftSongCard:View {
    let song:NOVAJSON
    var body:some View{HStack(spacing:14){NOVASwiftSongArtwork(song:song);VStack(alignment:.leading,spacing:5){Text(song.object?["t"]?.string ?? "").font(.headline);Text(song.object?["a"]?.string ?? "").font(.subheadline).foregroundStyle(.secondary)};Spacer(minLength:0)}.padding(.vertical,6)}
}
