import SwiftUI

// First-run tour after setup: four skippable cards, re-openable from settings.
// Client-only; completion is a local flag (tourSeen), nothing leaves the phone.
@MainActor struct NOVASwiftTour:View {
    @ObservedObject var store:NOVASwiftStore
    var onFinish:(()->Void)?=nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page=0
    @State private var forward=true
    private let pages:[(icon:String,title:String,detail:String)]=[
        ("house.fill","Tutto il giorno in una schermata","La Home raccoglie meteo, batteria, compiti e prossime verifiche. Scegli tu quali schede vedere dalle impostazioni."),
        ("chart.bar.fill","Voti e compiti dal registro","Collega ClasseViva per vedere voti, medie e compiti. La password resta solo su questo iPhone."),
        ("bubble.left.and.bubble.right.fill","Chat e gruppi di classe","Scrivi agli amici e crea gruppi con autorizzazioni chiare: tu decidi chi aggiunge membri e chi puo inviare messaggi."),
        ("map.fill","Mappa e profilo","Condividi la posizione solo quando vuoi tu e spegni quando vuoi. Il profilo con foto, scuola e canzone e tuo.")]
    private var pageTransition:AnyTransition{reduceMotion ? .opacity:.asymmetric(insertion:.opacity.combined(with:.move(edge:forward ? .trailing:.leading)),removal:.opacity.combined(with:.move(edge:forward ? .leading:.trailing)))}
    private func move(_ target:Int){forward=target>page;withAnimation(reduceMotion ? .easeOut(duration:0.15):.spring(response:0.5,dampingFraction:0.88)){page=max(0,min(pages.count-1,target))}}
    private func finish(){
        if let owner=store.archive?.owner{try? store.update(owner:owner){root in root["tourSeen"] = .number(1);root["tourPending"] = .number(0)}}
        if let onFinish{onFinish()}else{dismiss()}
    }
    var body:some View {
        NavigationStack{VStack(spacing:0){
            HStack{Spacer();Button("Salta"){finish()}.foregroundStyle(.secondary).accessibilityIdentifier("swiftTourSkip")}.padding(.horizontal).padding(.top,8)
            Spacer()
            let current=pages[page]
            VStack(spacing:18){
                Image(systemName:current.icon).font(.system(size:56)).foregroundStyle(.tint).frame(width:110,height:110).background(.quaternary,in:Circle())
                Text(current.title).font(.title.bold()).multilineTextAlignment(.center)
                Text(current.detail).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
            }.padding(.horizontal,32).id(page).transition(pageTransition).accessibilityElement(children:.combine).accessibilityIdentifier("swiftTourCard"+String(page))
            Spacer()
            HStack(spacing:8){ForEach(0..<pages.count,id:\.self){index in Circle().fill(index==page ? Color.primary:Color.secondary.opacity(0.35)).frame(width:8,height:8)}}.accessibilityHidden(true)
            HStack{
                if page>0{Button("Indietro"){move(page-1)}.accessibilityIdentifier("swiftTourBack")}
                Spacer()
                Button(page==pages.count-1 ? "Inizia":"Avanti"){if page<pages.count-1{move(page+1)}else{finish()}}.buttonStyle(.borderedProminent).accessibilityIdentifier(page==pages.count-1 ? "swiftTourStart":"swiftTourNext")
            }.padding(24)
        }.navigationTitle("Benvenuto in NOVA").navigationBarTitleDisplayMode(.inline)}
    }
}
