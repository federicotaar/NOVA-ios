import SwiftUI

@MainActor struct NOVASwiftProfile:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var edit=false
    @State private var settings=false
    @State private var qr=false
    @StateObject private var people=NOVASwiftPeople()
    @StateObject private var songs=NOVASwiftSongs()
    var profile:[String:NOVAJSON]{store.archive?.active.object?["prof"]?.object ?? [:]}
    var body:some View{NavigationStack{List{
        Section{HStack(spacing:16){NOVASwiftAvatar(value:profile["avatar"]?.string ?? "",username:profile["username"]?.string ?? "N");VStack(alignment:.leading){Text(store.archive?.active.object?["name"]?.string ?? "Il tuo profilo").font(.title2.bold());Text("@"+(profile["username"]?.string ?? "")).foregroundStyle(.secondary)}};Button("Modifica profilo"){edit=true}}
        Section{HStack{NavigationLink("Amici e richieste"){NOVASwiftPeopleView(store:store)};Text("\(people.friends.count)").foregroundStyle(.secondary)};NavigationLink("Follower (\(people.followers.count))"){NOVASwiftPeopleView(store:store)};NavigationLink("Seguiti (\(people.following.count))"){NOVASwiftPeopleView(store:store)};Button("Il mio QR / Scansiona"){qr=true}}
        ForEach(["study","skills","hobbies"],id:\.self){key in if let value=profile[key]?.string,!value.isEmpty{Section(key=="study" ? "Dove studi":key=="skills" ? "Punti forti":"Hobby"){Text(value)}}}
        if let song=profile["song"],let title=song.object?["t"]?.string{Section("La tua canzone"){Text(title).font(.headline);Text(song.object?["a"]?.string ?? "").foregroundStyle(.secondary);Button("Ascolta anteprima"){Task{await songs.preview(song)}};Button("Ferma anteprima"){songs.stop()}}}
        if let badges=profile["badges"]?.array,!badges.isEmpty{Section("Badge"){ForEach(Array(badges.enumerated()),id:\.offset){_,badge in Text(badge.string ?? "")}}}
        if !songs.status.isEmpty{Text(songs.status).font(.footnote)}
        if !people.status.isEmpty{Text(people.status).font(.footnote)}
        Section{Button("Impostazioni"){settings=true}}
    }.navigationTitle("Profilo").toolbar{Button{settings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Impostazioni")}.task{await people.load(store);await people.lists(store)}.refreshable{await people.load(store);await people.lists(store)}}
    .sheet(isPresented:$edit){NOVASwiftProfileEditor(store:store)}
    .sheet(isPresented:$settings){NOVASwiftSettings(store:store)}
    .sheet(isPresented:$qr){NOVASwiftQR(store:store,people:people)}
    .onDisappear{songs.stop();people.reset()}
    .onChange(of:store.archive?.owner){_,_ in songs.stop();people.reset();edit=false;settings=false;qr=false}
    }
}
