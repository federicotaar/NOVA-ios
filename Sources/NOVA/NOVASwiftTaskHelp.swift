import SwiftUI

@MainActor struct NOVASwiftTaskHelp:View {
    @ObservedObject var store:NOVASwiftStore
    let task:NOVAJSON
    @State private var assistant=false
    var o:[String:NOVAJSON]{task.object ?? [:]}
    var prompt:String{"Aiutami "+(o["kind"]?.string=="test" ? "a prepararmi per questa verifica":"con questo compito")+" di "+(o["subj"]?.string ?? "studio")+" ("+(o["due"]?.string ?? "")+"): "+(o["title"]?.string ?? "")+". Spiegami come procedere passo passo."}
    var body:some View{NavigationStack{List{Section(o["subj"]?.string ?? "Compito"){Text(o["title"]?.string ?? "").font(.title2.bold());Text(NOVASwiftOverview.deadline(o["due"]?.string ?? "")).foregroundStyle(.secondary);if let note=o["note"]?.string,!note.isEmpty{Text(note)};if let teacher=o["teacher"]?.string,!teacher.isEmpty{Text(teacher).font(.footnote)};Text(o["src"]?.string=="cv" ? "ClasseViva":"Aggiunto da te").font(.caption).foregroundStyle(.secondary)};Section{Button("Chiedi all'AI"){assistant=true}}}.navigationTitle("Dettaglio")}.sheet(isPresented:$assistant){NOVASwiftAssistant(store:store,initialDraft:prompt)}}
}
