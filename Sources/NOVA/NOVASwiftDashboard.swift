import SwiftUI
import UIKit

@MainActor final class NOVASwiftWeather:ObservableObject {
    @Published var status="Scegli la città per il meteo."
    @Published var value:NOVAJSON?
    private var generation=0
    func cancel(){generation += 1}
    func load(city:NOVAJSON) async {
        value=nil
        guard let o=city.object,case .number(let lat)?=o["lat"],case .number(let lon)?=o["lon"],lat.isFinite,lon.isFinite,abs(lat)<=90,abs(lon)<=180 else{status="Scegli la città per il meteo.";return}
        generation += 1;let expected=generation;status="Carico il meteo…"
        var parts=URLComponents(string:"https://api.open-meteo.com/v1/forecast")!
        parts.queryItems=[URLQueryItem(name:"latitude",value:String(lat)),URLQueryItem(name:"longitude",value:String(lon)),URLQueryItem(name:"current",value:"temperature_2m,apparent_temperature,weather_code"),URLQueryItem(name:"daily",value:"temperature_2m_max,temperature_2m_min"),URLQueryItem(name:"timezone",value:"auto"),URLQueryItem(name:"forecast_days",value:"1")]
        do{let (data,response)=try await URLSession.shared.data(from:parts.url!);guard expected==generation else{return};guard (response as? HTTPURLResponse)?.statusCode==200 else{throw NOVAServiceError.invalidResponse};value=try JSONDecoder().decode(NOVAJSON.self,from:data);status=""}catch{if expected==generation{status="Meteo non aggiornato. Riprova."}}
    }
    func search(_ name:String) async throws -> NOVAJSON {
        var parts=URLComponents(string:"https://geocoding-api.open-meteo.com/v1/search")!
        parts.queryItems=[URLQueryItem(name:"name",value:name),URLQueryItem(name:"count",value:"1"),URLQueryItem(name:"language",value:"it")]
        let(data,response)=try await URLSession.shared.data(from:parts.url!)
        guard (response as? HTTPURLResponse)?.statusCode==200,let city=try JSONDecoder().decode(NOVAJSON.self,from:data).object?["results"]?.array.first?.object,
              let name=city["name"],let lat=city["latitude"],let lon=city["longitude"] else{throw NOVAServiceError.invalidResponse}
        return .object(["name":name,"lat":lat,"lon":lon])
    }
    static func description(_ code:Int)->String {
        if [0,1].contains(code){return "Sereno"};if [2,3].contains(code){return "Nuvoloso"};if [45,48].contains(code){return "Nebbia"};if [71,73,75,77,85,86].contains(code){return "Neve"};if [95,96,99].contains(code){return "Temporale"};return "Pioggia"
    }
}
@MainActor struct NOVASwiftDashboard:View {
    @ObservedObject var store:NOVASwiftStore
    @StateObject private var weather=NOVASwiftWeather()
    @StateObject private var position=NOVASwiftPosition()
    @State private var locationOwner=""
    @State private var cityQuery=""
    @State private var cityError=""
    @State private var searching=false
    @State private var cityGeneration=0
    @State private var month=Calendar.current.date(from:Calendar.current.dateComponents([.year,.month],from:Date()))!
    @State private var selectedDay:Date?
    @State private var createTask=false
    @State private var timetable=false
    @State private var settings=false
    @State private var status=""
    var root:[String:NOVAJSON]{store.archive?.active.object ?? [:]}
    @State private var assistantTask:NOVAJSON?
    var dailyRange:String {let daily=weather.value?.object?["daily"]?.object ?? [:];let low=daily["temperature_2m_min"]?.array.first?.double ?? 0;let high=daily["temperature_2m_max"]?.array.first?.double ?? 0;return "Min "+String(Int(low.rounded()))+"° · Max "+String(Int(high.rounded()))+"°"}
    func visible(_ key:String)->Bool {root["w"]?.object?[key]?.flag ?? true}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20){
                    HStack{Text("Ciao "+(root["name"]?.string ?? "")).font(.largeTitle.bold());Spacer();Button{settings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Impostazioni")}
                    TimelineView(.periodic(from:.now,by:60)){context in VStack(alignment:.leading){Text(context.date,style:.time).font(.system(size:54,weight:.bold,design:.rounded));Text(context.date,format:.dateTime.weekday(.wide).day().month(.wide)).foregroundStyle(.secondary)}}
                    if visible("wx"){card("Meteo"){
                        if let c=weather.value?.object?["current"]?.object {
                            Text("\(c["temperature_2m"]?.integer ?? 0)°").font(.system(size:42,weight:.semibold))
                            Text((root["city"]?.object?["name"]?.string ?? "")+" · "+NOVASwiftWeather.description(c["weather_code"]?.integer ?? 0)).foregroundStyle(.secondary)
                        }
                        if !weather.status.isEmpty{Text(weather.status).foregroundStyle(.secondary)}
                        if weather.value != nil{Text(dailyRange).font(.footnote)}
                        Button("Usa la mia posizione"){locationOwner=store.archive?.owner ?? "";position.read()}
                        if !position.status.isEmpty{Text(position.status).font(.footnote).foregroundStyle(.secondary)}
                        HStack{TextField("Città",text:$cityQuery).textInputAutocapitalization(.words);Button("Cerca"){findCity()}.disabled(searching||cityQuery.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}
                        if !cityError.isEmpty{Text(cityError).font(.footnote).foregroundStyle(.red)}
                    }}
                    if visible("sp"){card("Spotify"){NOVASwiftMusicCard()}}
                    if visible("bat"){card("Batteria"){
                        TimelineView(.periodic(from:.now,by:60)){_ in
                            let device=UIDevice.current
                            HStack{Image(systemName:device.batteryState == .charging || device.batteryState == .full ? "battery.100percent.bolt":"battery.100percent");Text(device.batteryLevel<0 ? "Livello non disponibile":"\(Int(device.batteryLevel*100))%");Spacer();Text(device.batteryState == .charging || device.batteryState == .full ? "In carica":"Non in carica").foregroundStyle(.secondary)}
                        }
                    }}
                    if visible("task"){card("Compiti"){
                        Button("Nuovo compito"){createTask=true}
                        if (root["tasks"]?.array ?? []).isEmpty{Text("Nessun compito").foregroundStyle(.secondary)}
                        ForEach(Array((root["tasks"]?.array ?? []).filter{$0.object?["done"]?.flag != true && $0.object?["kind"]?.string != "test" && !($0.object?["id"]?.string ?? "").hasPrefix("cvag")}.enumerated()),id:\.offset){_,task in taskRow(task)}
                    }}
                    if visible("nx"){card("Prossime verifiche"){
                        let tests=(root["tasks"]?.array ?? []).filter{($0.object?["kind"]?.string=="test" || ($0.object?["id"]?.string ?? "").hasPrefix("cvag")) && $0.object?["done"]?.flag != true}
                        if tests.isEmpty{Text("Nessuna verifica salvata.").foregroundStyle(.secondary)}
                        ForEach(Array(tests.enumerated()),id:\.offset){_,task in taskRow(task)}
                    }}
                    if visible("cal"){card(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier:"it_IT")))){
                        HStack{Button{changeMonth(-1)}label:{Image(systemName:"chevron.left")}.accessibilityLabel("Mese precedente");Spacer();Button{changeMonth(1)}label:{Image(systemName:"chevron.right")}.accessibilityLabel("Mese successivo")}
                        calendar
                    }}
                    card("Il tuo orario"){Button("Modifica orario"){timetable=true};Text("\(root["tt"]?.object?["lessons"]?.array.count ?? 0) \((root["tt"]?.object?["lessons"]?.array.count ?? 0)==1 ? "lezione salvata":"lezioni salvate")").foregroundStyle(.secondary)}
                    
                    if !status.isEmpty{Text(status).foregroundStyle(.red)}
                }.padding(20)
            }.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("NOVA").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:Binding(get:{assistantTask != nil},set:{if !$0{assistantTask=nil}})){if let task=assistantTask{NOVASwiftTaskHelp(store:store,task:task)}}
            .sheet(isPresented:$createTask){NOVASwiftTaskEditor(store:store)}.sheet(isPresented:$timetable){NOVASwiftTimetable(store:store)}.sheet(isPresented:$settings){NOVASwiftSettings(store:store)}
            .sheet(item:Binding(get:{selectedDay.map{NOVASwiftSelectedDay(date:$0)}},set:{selectedDay=$0?.date})){day in NavigationStack{List{ForEach(Array((root["tasks"]?.array ?? []).filter{task in guard let due=task.object?["due"]?.string else{return false};return due.hasPrefix(day.date.formatted(.iso8601.year().month().day().dateSeparator(.dash)))}.enumerated()),id:\.offset){_,task in taskRow(task)}}.navigationTitle(day.date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier:"it_IT")))).toolbar{Button("Fatto"){selectedDay=nil}}}}
            .task(id:root["city"]?.object?["name"]?.string){UIDevice.current.isBatteryMonitoringEnabled=true;if let city=root["city"]{await weather.load(city:city)}}
            .onChange(of:position.fixVersion){_,_ in useWeatherPosition()}
            .onChange(of:store.archive?.owner){_,_ in position.stop();weather.cancel();cityGeneration+=1;searching=false;cityQuery=""}
            .onDisappear{position.stop();weather.cancel();cityGeneration += 1}
        }.environment(\.locale,Locale(identifier:"it_IT"))
    }
    @ViewBuilder func card<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {
        VStack(alignment:.leading,spacing:12){Text(title).font(.headline);content()}.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:24))
    }
    func taskRow(_ task:NOVAJSON)->some View {
        let o=task.object ?? [:]
        return HStack(alignment:.top){Button{do{try NOVASwiftTaskActions.mutate(store,owner:store.archive?.owner ?? "",id:o["id"]?.string ?? "")}catch{status="Compito non modificato."}}label:{Image(systemName:o["done"]?.flag==true ? "checkmark.circle.fill":"circle")}.buttonStyle(.plain);VStack(alignment:.leading,spacing:4){Button{assistantTask=task}label:{Text(o["title"]?.string ?? "Compito").foregroundStyle(.primary)}.buttonStyle(.plain);Text(NOVASwiftOverview.deadline(o["due"]?.string ?? "")).font(.caption).foregroundStyle(.secondary);if let note=o["note"]?.string,!note.isEmpty{Text(note).font(.footnote).foregroundStyle(.secondary)}};Spacer();Button(role:.destructive){do{try NOVASwiftTaskActions.mutate(store,owner:store.archive?.owner ?? "",id:o["id"]?.string ?? "",remove:true)}catch{status="Compito non eliminato."}}label:{Image(systemName:"trash")}.accessibilityLabel("Elimina compito")}
    }
    var calendar:some View {
        let cal=Calendar(identifier:.gregorian),first=cal.component(.weekday,from:month),offset=(first+5)%7,count=cal.range(of:.day,in:.month,for:month)?.count ?? 0
        return LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:7),spacing:8){
            ForEach(Array(["L","M","M","G","V","S","D"].enumerated()),id:\.offset){_,day in Text(day).font(.caption.bold()).foregroundStyle(.secondary)}
            ForEach(0..<(offset+count),id:\.self){index in if index<offset{Color.clear.frame(height:36)}else{let number=index-offset+1,date=cal.date(byAdding:.day,value:number-1,to:month)!;Button{selectedDay=date}label:{VStack(spacing:1){Text(String(number));if hasTasks(date){Circle().frame(width:4,height:4)}}.frame(maxWidth:.infinity,minHeight:36).background(cal.isDateInToday(date) ? Color.blue.opacity(0.15):Color.clear,in:Capsule())}.buttonStyle(.plain)}}
        }
    }
    func hasTasks(_ date:Date)->Bool{let f=DateFormatter();f.dateFormat="yyyy-MM-dd";let day=f.string(from:date);return(root["tasks"]?.array ?? []).contains{($0.object?["due"]?.string ?? "").hasPrefix(day)}}
    func changeMonth(_ direction:Int){month=Calendar.current.date(byAdding:.month,value:direction,to:month) ?? month}
    func useWeatherPosition(){guard locationOwner==store.archive?.owner,let coordinate=position.coordinate else{return};let city:NOVAJSON = .object(["name":.string("Posizione attuale"),"lat":.number(coordinate.latitude),"lon":.number(coordinate.longitude)]);Task{await weather.load(city:city)}}
    func findCity(){
        let query=cityQuery.trimmingCharacters(in:.whitespacesAndNewlines),owner=store.archive?.owner ?? ""
        cityGeneration += 1;let expected=cityGeneration;searching=true;cityError=""
        Task{do{let city=try await weather.search(query);guard expected==cityGeneration,store.archive?.owner==owner else{return};try store.update(owner:owner){$0["city"] = city};cityQuery=""}catch{if expected==cityGeneration{cityError="Città non trovata o rete assente."}};if expected==cityGeneration{searching=false}}
    }
}
struct NOVASwiftSelectedDay:Identifiable {let date:Date;var id:Date{date}}
@MainActor struct NOVASwiftGrades:View {
    @ObservedObject var store:NOVASwiftStore
    var grades:[NOVAJSON]{store.archive?.active.object?["gr"]?.array ?? []}
    var grouped:[String:[NOVAJSON]]{Dictionary(grouping:grades,by:{$0.object?["subj"]?.string ?? "Materia"})}
    var body:some View {
        NavigationStack{List{
            if grades.isEmpty{Text("Nessun voto numerico salvato.").foregroundStyle(.secondary)}
            ForEach(grouped.keys.sorted(),id:\.self){subject in subjectSection(subject)}
        }.navigationTitle("Voti")}.environment(\.locale,Locale(identifier:"it_IT"))
    }
    @ViewBuilder func subjectSection(_ subject:String)->some View{
        let rows=grouped[subject] ?? []
        let values=rows.compactMap{row -> Double? in if case .number(let n)?=row.object?["v"]{return n};return nil}
        if !values.isEmpty{
            let total=values.reduce(0,+),average=total/Double(values.count),need=6*Double(values.count+1)-total
            Section(subject){
                Text(average.formatted(.number.precision(.fractionLength(1)))+" · \(values.count) voti").font(.title2)
                Text(target(average,need)).font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(rows.sorted{($0.object?["date"]?.string ?? "")>($1.object?["date"]?.string ?? "")}.enumerated()),id:\.offset){_,grade in gradeRow(grade)}
            }
        }
    }
    func target(_ average:Double,_ need:Double)->String{if average>=6{return need<=1 ? "Sei al sicuro":"Puoi scendere fino a "+need.formatted(.number.precision(.fractionLength(1)))+" e restare al 6"};return need>10 ? "Servono piu voti per arrivare al 6":"Serve almeno "+need.formatted(.number.precision(.fractionLength(1)))+" per arrivare al 6"}
    func gradeRow(_ grade:NOVAJSON)->some View{VStack(alignment:.leading,spacing:4){HStack{Text(grade.object?["d"]?.string ?? String(grade.object?["v"]?.double ?? 0)).font(.headline);Spacer();Text(grade.object?["date"]?.string ?? "").font(.caption).foregroundStyle(.secondary)};if let kind=grade.object?["k"]?.string,!kind.isEmpty{Text(kind).font(.caption)};if let note=grade.object?["n"]?.string,!note.isEmpty{Text(note).font(.footnote).foregroundStyle(.secondary)}}}
}
