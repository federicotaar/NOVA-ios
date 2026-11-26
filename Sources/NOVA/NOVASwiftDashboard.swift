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
    var openHomeTasks:[NOVAJSON]{(root["tasks"]?.array ?? []).filter{$0.object?["done"]?.flag != true && $0.object?["kind"]?.string != "test"}}
    var overdueHomeTasks:[NOVAJSON]{let todayKey=NOVASwiftTaskDay.key(Date());return openHomeTasks.filter{let key=NOVASwiftCompiti.dayKey($0);return !key.isEmpty && key<todayKey}}
    var tomorrowHomeTasks:[NOVAJSON]{let tomorrowKey=NOVASwiftTaskDay.key(Calendar.current.date(byAdding:.day,value:1,to:Date()) ?? Date());return openHomeTasks.filter{NOVASwiftCompiti.dayKey($0)==tomorrowKey}}
    @ViewBuilder var meteoCard:some View {
        if visible("wx"){card("Meteo"){
            if let c=weather.value?.object?["current"]?.object {
                let wxTemp=c["temperature_2m"]?.integer ?? 0
                Text("\(wxTemp)°").font(.system(size:42,weight:.semibold))
                let wxCity=root["city"]?.object?["name"]?.string ?? ""
                let wxDesc=NOVASwiftWeather.description(c["weather_code"]?.integer ?? 0)
                Text(wxCity+" · "+wxDesc).foregroundStyle(.secondary)
            }
            if !weather.status.isEmpty{Text(weather.status).foregroundStyle(.secondary)}
            if weather.value != nil{Text(dailyRange).font(.footnote)}
            Button("Usa la mia posizione"){locationOwner=store.archive?.owner ?? "";position.read()}
            if !position.status.isEmpty{Text(position.status).font(.footnote).foregroundStyle(.secondary)}
            HStack{TextField("Città",text:$cityQuery).textInputAutocapitalization(.words);Button("Cerca"){findCity()}.disabled(searching||cityQuery.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}
            if !cityError.isEmpty{Text(cityError).font(.footnote).foregroundStyle(.red)}
        }}
    }
    @ViewBuilder private var homeHeader:some View {
        HStack{Text("Ciao "+(root["name"]?.string ?? "")).font(.largeTitle.bold());Spacer();Button{settings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Impostazioni")}
    }
    @ViewBuilder private var homeClock:some View {
        TimelineView(.periodic(from:.now,by:60)){context in VStack(alignment:.leading){Text(context.date,style:.time).font(.system(size:54,weight:.bold,design:.rounded));Text(context.date,format:.dateTime.weekday(.wide).day().month(.wide)).foregroundStyle(.secondary)}}
    }
    @ViewBuilder private var batteriaCard:some View {
        if visible("bat"){card("Batteria"){
            TimelineView(.periodic(from:.now,by:60)){_ in
                let device=UIDevice.current
                HStack{Image(systemName:device.batteryState == .charging || device.batteryState == .full ? "battery.100percent.bolt":"battery.100percent");Text(device.batteryLevel<0 ? "Livello non disponibile":"\(Int(device.batteryLevel*100))%");Spacer();Text(device.batteryState == .charging || device.batteryState == .full ? "In carica":"Non in carica").foregroundStyle(.secondary)}
            }
        }}
    }
    @ViewBuilder private var compitiCard:some View {
        if visible("task"){card("Compiti"){
            let open=openHomeTasks
            let overdue=overdueHomeTasks
            let tomorrow=tomorrowHomeTasks
            if !open.isEmpty{Text(homeworkSummary(open.count,overdue.count,tomorrow.count)).font(.footnote).foregroundStyle(overdue.isEmpty ? Color.secondary:Color.red).accessibilityIdentifier("swiftCompitiSummary")}
            Button("Nuovo compito"){createTask=true}
            if open.isEmpty{Text("Nessun compito").foregroundStyle(.secondary)}
            ForEach(Array(open.filter{!($0.object?["id"]?.string ?? "").hasPrefix("cvag")}.enumerated()),id:\.offset){_,task in taskRow(task)}
            NavigationLink("Tutti i compiti"){NOVASwiftCompiti(store:store)}.accessibilityIdentifier("swiftCompitiAll")
        }}
    }
    @ViewBuilder private var verificheCard:some View {
        if visible("nx"){card("Prossime verifiche"){
            let tests=(root["tasks"]?.array ?? []).filter{($0.object?["kind"]?.string=="test" || ($0.object?["id"]?.string ?? "").hasPrefix("cvag")) && $0.object?["done"]?.flag != true}
            if tests.isEmpty{Text("Nessuna verifica salvata.").foregroundStyle(.secondary)}
            ForEach(Array(tests.enumerated()),id:\.offset){_,task in taskRow(task)}
        }}
    }
    @ViewBuilder private var calendarioCard:some View {
        if visible("cal"){card(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier:"it_IT")))){
            HStack{Button{changeMonth(-1)}label:{Image(systemName:"chevron.left")}.accessibilityLabel("Mese precedente");Spacer();Button{changeMonth(1)}label:{Image(systemName:"chevron.right")}.accessibilityLabel("Mese successivo")}
            calendar
        }}
    }
    @ViewBuilder private var orarioCard:some View {
        card("Il tuo orario"){Button("Modifica orario"){timetable=true};Text("\(root["tt"]?.object?["lessons"]?.array.count ?? 0) \((root["tt"]?.object?["lessons"]?.array.count ?? 0)==1 ? "lezione salvata":"lezioni salvate")").foregroundStyle(.secondary)
            let domani=orarioDomani()
            if !domani.isEmpty{Text("Domani: "+domani).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("swiftOrarioDomani")}
            NavigationLink("Orario da ClasseViva"){NOVASwiftOrario(store:store)}.accessibilityIdentifier("swiftOrarioLink")}
    }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20){
                    homeHeader
                    homeClock
                    meteoCard
                    if visible("sp"){card("Spotify"){NOVASwiftMusicCard()}}
                    batteriaCard
                    compitiCard
                    verificheCard
                    calendarioCard
                    orarioCard
                    if !status.isEmpty{Text(status).foregroundStyle(.red)}
                }.padding(20).padding(.bottom,80)
            }.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("NOVA").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:Binding(get:{assistantTask != nil},set:{if !$0{assistantTask=nil}})){if let task=assistantTask{NOVASwiftTaskHelp(store:store,task:task)}}
            .sheet(isPresented:$createTask){NOVASwiftTaskEditor(store:store)}.sheet(isPresented:$timetable){NOVASwiftTimetable(store:store)}.sheet(isPresented:$settings){NOVASwiftSettings(store:store)}
            .sheet(item:Binding(get:{selectedDay.map{NOVASwiftSelectedDay(date:$0)}},set:{selectedDay=$0?.date})){day in NavigationStack{List{if NOVASwiftTaskDay.tasks(root["tasks"]?.array ?? [],on:day.date).isEmpty{ContentUnavailableView("Nessun compito per questo giorno",systemImage:"calendar",description:Text("I compiti degli altri giorni restano nella Home."))};ForEach(Array(NOVASwiftTaskDay.tasks(root["tasks"]?.array ?? [],on:day.date).enumerated()),id:\.offset){_,task in taskRow(task)}}.navigationTitle(day.date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier:"it_IT")))).toolbar{Button("Fatto"){selectedDay=nil}}}}
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
    func hasTasks(_ date:Date)->Bool{!NOVASwiftTaskDay.tasks(root["tasks"]?.array ?? [],on:date).isEmpty}
    func changeMonth(_ direction:Int){month=Calendar.current.date(byAdding:.month,value:direction,to:month) ?? month}
    func homeworkSummary(_ open:Int,_ overdue:Int,_ tomorrow:Int)->String{let a="\(open) "+(open==1 ? "aperto":"aperti"),o=overdue==0 ? "" : " · \(overdue) in ritardo",d=tomorrow==0 ? "" : " · \(tomorrow) per domani";return a+o+d}
    func orarioDomani()->String{let key=NOVASwiftTaskDay.key(Calendar.current.date(byAdding:.day,value:1,to:Date()) ?? Date());let rows=(root["ls"]?.array ?? []).filter{$0.object?["d"]?.string==key}.sorted{($0.object?["b"]?.string ?? "")<($1.object?["b"]?.string ?? "")};return rows.prefix(3).map{($0.object?["s"]?.string ?? "")+" "+NOVASwiftOrario.clock($0.object?["b"]?.string ?? "")}.joined(separator:" · ")}
    func useWeatherPosition(){guard locationOwner==store.archive?.owner,let owner=store.archive?.owner,let coordinate=position.coordinate else{return};let city:NOVAJSON = .object(["name":.string("Posizione attuale"),"lat":.number(coordinate.latitude),"lon":.number(coordinate.longitude)]);Task{await weather.load(city:city);guard store.archive?.owner==owner else{return};let existing=root["city"]?.object;if existing?["name"]?.string=="Posizione attuale",abs((existing?["lat"]?.double ?? 0)-coordinate.latitude)<0.01,abs((existing?["lon"]?.double ?? 0)-coordinate.longitude)<0.01{return};try? store.update(owner:owner){$0["city"] = city}}}
    func findCity(){
        let query=cityQuery.trimmingCharacters(in:.whitespacesAndNewlines),owner=store.archive?.owner ?? ""
        cityGeneration += 1;let expected=cityGeneration;searching=true;cityError=""
        Task{do{let city=try await weather.search(query);guard expected==cityGeneration,store.archive?.owner==owner else{return};try store.update(owner:owner){$0["city"] = city};cityQuery=""}catch{if expected==cityGeneration{cityError="Città non trovata o rete assente."}};if expected==cityGeneration{searching=false}}
    }
}
struct NOVASwiftSelectedDay:Identifiable {let date:Date;var id:Date{date}}
@MainActor enum NOVASwiftGradeShare {
    // CI fixtures only: when set, the grades screen shows these rows and skips the network.
    static var fixtureShares:[NOVAJSON]?
    static func payload(_ grades:[NOVAJSON])->NOVAJSON? {
        let grouped=Dictionary(grouping:grades,by:{$0.object?["subj"]?.string ?? "Materia"})
        var subjects:[NOVAJSON]=[];var avgs:[Double]=[]
        for subject in grouped.keys.sorted(){
            let values=(grouped[subject] ?? []).compactMap{row -> Double? in if case .number(let n)?=row.object?["v"]{return n};return nil}
            guard !values.isEmpty else{continue}
            let avg=values.reduce(0,+)/Double(values.count);avgs.append(avg)
            subjects.append(.object(["name":.string(subject),"avg":.number(avg)]))
        }
        guard !avgs.isEmpty else{return nil}
        return .object(["overall":.number(avgs.reduce(0,+)/Double(avgs.count)),"subjects":.array(subjects)])
    }
    static func upload(_ store:NOVASwiftStore) async {
        if fixtureShares != nil{return}
        guard let archive=store.archive,let session=NOVASession(archive.active) else{return}
        guard let data=payload(archive.active.object?["gr"]?.array ?? []) else{return}
        _ = try? await NOVAAccountService(session:session).request("grades/share",method:"PUT",body:.object(["data":data]))
    }
    static func remove(_ store:NOVASwiftStore) async {
        guard let archive=store.archive,let session=NOVASession(archive.active) else{return}
        _ = try? await NOVAAccountService(session:session).request("grades/share",method:"DELETE")
    }
    static func sharedDate(_ iso:String)->String{let parser=ISO8601DateFormatter();guard let date=parser.date(from:iso) else{return ""};return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier:"it_IT")))}
}
@MainActor struct NOVASwiftGrades:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var pagella=false
    @State private var shares:[NOVAJSON]=[]
    var shareOn:Bool{store.archive?.active.object?["shareGrades"]?.flag==true}
    var grades:[NOVAJSON]{store.archive?.active.object?["gr"]?.array ?? []}
    var absences:[NOVAJSON]{store.archive?.active.object?["ab"]?.array ?? []}
    var grouped:[String:[NOVAJSON]]{Dictionary(grouping:grades,by:{$0.object?["subj"]?.string ?? "Materia"})}
    func target(_ subject:String)->Double{store.archive?.active.object?["targets"]?.object?[subject]?.double ?? 6}
    func setTarget(_ subject:String,_ value:Double){if let owner=store.archive?.owner{try? store.update(owner:owner){root in var map=root["targets"]?.object ?? [:];map[subject] = .number(value);root["targets"] = .object(map)}}}
    var body:some View {
        NavigationStack{List{
            absencesSection
            if grades.isEmpty{Text("Nessun voto numerico salvato.").foregroundStyle(.secondary)}
            ForEach(grouped.keys.sorted(),id:\.self){subject in subjectSection(subject)}
            if shareOn{
                Section("Medie degli amici"){
                    if shares.isEmpty{Text("Nessun amico condivide la media al momento.").foregroundStyle(.secondary).accessibilityIdentifier("swiftGradeSharesEmpty")}
                    ForEach(Array(shares.enumerated()),id:\.offset){_,share in let data=share.object?["data"]?.object ?? [:];HStack{Text("@"+(share.object?["username"]?.string ?? ""));Spacer();if let date=share.object?["updated_at"]?.string,!NOVASwiftGradeShare.sharedDate(date).isEmpty{Text(NOVASwiftGradeShare.sharedDate(date)).font(.caption).foregroundStyle(.secondary)};Text((data["overall"]?.double ?? 0).formatted(.number.precision(.fractionLength(1)))).font(.headline)}.accessibilityIdentifier("swiftGradeShareRow")}
                }
            }
        }.navigationTitle("Voti").task{await loadShares()}.toolbar{ToolbarItem(placement:.primaryAction){Button{pagella=true}label:{Image(systemName:"square.and.arrow.up")}.accessibilityIdentifier("swiftPagellaOpen")}}}.sheet(isPresented:$pagella){NOVASwiftPagella(store:store)}.environment(\.locale,Locale(identifier:"it_IT"))
    }
    @ViewBuilder var absencesSection:some View{
        if !absences.isEmpty{
            let counts=Dictionary(grouping:absences,by:{$0.object?["k"]?.string ?? "altro"}).mapValues{$0.count}
            let pending=absences.filter{$0.object?["j"]?.flag != true && $0.object?["k"]?.string=="assenza"}.count
            Section("Assenze"){
                Text(absenceSummary(counts)).font(.headline).accessibilityIdentifier("swiftGradesAbsences")
                if pending>0{Text("\(pending) ancora da giustificare").font(.caption).foregroundStyle(.orange)}
                ForEach(Array(absences.sorted{($0.object?["d"]?.string ?? "")>($1.object?["d"]?.string ?? "")}.prefix(5).enumerated()),id:\.offset){_,row in HStack{Text(row.object?["k"]?.string ?? "").font(.subheadline);Spacer();if row.object?["j"]?.flag==true{Image(systemName:"checkmark.circle.fill").foregroundStyle(.green).imageScale(.small)};Text(row.object?["d"]?.string ?? "").font(.caption).foregroundStyle(.secondary)}}
            }
        }
    }
    func loadShares() async {
        if let fixture=NOVASwiftGradeShare.fixtureShares{shares=shareOn ? fixture:[];return}
        guard let archive=store.archive,let session=NOVASession(archive.active) else{shares=[];return}
        if shareOn{await NOVASwiftGradeShare.upload(store)}
        guard shareOn else{shares=[];return}
        if let result=try? await NOVAAccountService(session:session).request("grades/share"),let list=result.object?["shares"]?.array{shares=list}else{shares=[]}
    }
    @ViewBuilder func subjectSection(_ subject:String)->some View{
        let rows=grouped[subject] ?? []
        let values=rows.compactMap{row -> Double? in if case .number(let n)?=row.object?["v"]{return n};return nil}
        if !values.isEmpty{
            let total=values.reduce(0,+),average=total/Double(values.count),goal=target(subject),need=goal*Double(values.count+1)-total
            Section(subject){
                Text(average.formatted(.number.precision(.fractionLength(1)))+" · \(values.count) "+(values.count==1 ? "voto":"voti")).font(.title2)
                trendChart(rows).accessibilityIdentifier("swiftGradeTrend")
                Text(verdict(average,need,goal)).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("swiftGradeVerdict")
                Stepper(value:Binding(get:{target(subject)},set:{setTarget(subject,$0)}),in:1...10,step:0.5){Text("Obiettivo: "+target(subject).formatted(.number.precision(.fractionLength(1))))}.accessibilityIdentifier("swiftGradeTarget")
                ForEach(Array(rows.sorted{($0.object?["date"]?.string ?? "")>($1.object?["date"]?.string ?? "")}.enumerated()),id:\.offset){_,grade in gradeRow(grade)}
            }
        }
    }
    func absenceSummary(_ counts:[String:Int])->String{let a=counts["assenza"] ?? 0,r=counts["ritardo"] ?? 0,u=counts["uscita anticipata"] ?? 0;return "\(a) "+(a==1 ? "assenza":"assenze")+" · \(r) "+(r==1 ? "ritardo":"ritardi")+" · \(u) "+(u==1 ? "uscita anticipata":"uscite anticipate")}
    func verdict(_ average:Double,_ need:Double,_ goal:Double)->String{let g=goal.formatted(.number.precision(.fractionLength(1)));if average>=goal{return need<=1 ? "Sei al sicuro sopra il "+g : "Puoi scendere fino a "+need.formatted(.number.precision(.fractionLength(1)))+" e restare al "+g};return need>10 ? "Servono più voti per arrivare al "+g : "Serve almeno "+need.formatted(.number.precision(.fractionLength(1)))+" per arrivare al "+g}
    func trendPoints(_ rows:[NOVAJSON])->[Double] {
        let sorted=rows.sorted{($0.object?["date"]?.string ?? "")<($1.object?["date"]?.string ?? "")}
        var sum=0.0,count=0.0,points:[Double]=[]
        for row in sorted{if case .number(let n)?=row.object?["v"]{sum+=n;count+=1;points.append(sum/count)}}
        return points
    }
    @ViewBuilder func trendChart(_ rows:[NOVAJSON])->some View {
        let points=trendPoints(rows)
        if points.count>1{
            let low=points.min() ?? 0,high=points.max() ?? 10,span=max(high-low,0.5)
            Canvas{context,size in
                var path=Path()
                for index in points.indices{let x=size.width*Double(index)/Double(points.count-1),y=size.height*CGFloat(1-(points[index]-low)/span);if index==points.startIndex{path.move(to:CGPoint(x:x,y:y))}else{path.addLine(to:CGPoint(x:x,y:y))}}
                context.stroke(path,with:.color(.accentColor),lineWidth:2)
            }.frame(height:36)
        }
    }
    func gradeRow(_ grade:NOVAJSON)->some View{VStack(alignment:.leading,spacing:4){HStack{Text(grade.object?["d"]?.string ?? String(grade.object?["v"]?.double ?? 0)).font(.headline);Spacer();Text(grade.object?["date"]?.string ?? "").font(.caption).foregroundStyle(.secondary)};if let kind=grade.object?["k"]?.string,!kind.isEmpty{Text(kind).font(.caption)};if let note=grade.object?["n"]?.string,!note.isEmpty{Text(note).font(.footnote).foregroundStyle(.secondary)}}}
}

@MainActor struct NOVASwiftCompiti:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var showDone=false
    @State private var status=""
    var tasks:[NOVAJSON]{store.archive?.active.object?["tasks"]?.array ?? []}
    static func dayKey(_ task:NOVAJSON)->String{String((task.object?["due"]?.string ?? "").prefix(10))}
    static func label(_ key:String)->String{let parser=DateFormatter();parser.locale=Locale(identifier:"en_US_POSIX");parser.dateFormat="yyyy-MM-dd";guard let date=parser.date(from:key) else{return key};let output=DateFormatter();output.locale=Locale(identifier:"it_IT");output.dateFormat="EEEE d MMMM";return output.string(from:date).capitalized}
    var body:some View {
        let today=NOVASwiftTaskDay.key(Date()),tomorrow=NOVASwiftTaskDay.key(Calendar.current.date(byAdding:.day,value:1,to:Date()) ?? Date())
        let open=tasks.filter{$0.object?["done"]?.flag != true && $0.object?["kind"]?.string != "test"}
        let done=tasks.filter{$0.object?["done"]?.flag==true && $0.object?["kind"]?.string != "test"}
        let grouped=Dictionary(grouping:open,by:{NOVASwiftCompiti.dayKey($0)})
        let overdueDays=grouped.keys.filter{!$0.isEmpty && $0<today}.sorted()
        let futureDays=grouped.keys.filter{$0>tomorrow}.sorted()
        return List{
            if open.isEmpty{Text("Nessun compito da fare.").foregroundStyle(.secondary)}
            if !overdueDays.isEmpty{Section(header:Text("In ritardo").foregroundStyle(.red)){ForEach(overdueDays,id:\.self){day in ForEach(Array((grouped[day] ?? []).enumerated()),id:\.offset){_,task in row(task,red:true)}}}.accessibilityIdentifier("swiftCompitiOverdue")}
            if !(grouped[today] ?? []).isEmpty{Section("Oggi"){ForEach(Array((grouped[today] ?? []).enumerated()),id:\.offset){_,task in row(task,red:false)}}}
            if !(grouped[tomorrow] ?? []).isEmpty{Section("Domani"){ForEach(Array((grouped[tomorrow] ?? []).enumerated()),id:\.offset){_,task in row(task,red:false)}}}
            ForEach(futureDays,id:\.self){day in Section(NOVASwiftCompiti.label(day)){ForEach(Array((grouped[day] ?? []).enumerated()),id:\.offset){_,task in row(task,red:false)}}}
            if !(grouped[""] ?? []).isEmpty{Section("Senza scadenza"){ForEach(Array((grouped[""] ?? []).enumerated()),id:\.offset){_,task in row(task,red:false)}}}
            if !done.isEmpty{Section{Toggle("Mostra completati (\(done.count))",isOn:$showDone).accessibilityIdentifier("swiftCompitiShowDone");if showDone{ForEach(Array(done.enumerated()),id:\.offset){_,task in row(task,red:false)}}}}
            if !status.isEmpty{Text(status).foregroundStyle(.red)}
        }.navigationTitle("Compiti").environment(\.locale,Locale(identifier:"it_IT"))
    }
    @ViewBuilder func row(_ task:NOVAJSON,red:Bool)->some View {
        let o=task.object ?? [:]
        HStack(alignment:.top,spacing:12){Button{do{try NOVASwiftTaskActions.mutate(store,owner:store.archive?.owner ?? "",id:o["id"]?.string ?? "")}catch{status="Compito non modificato."}}label:{Image(systemName:o["done"]?.flag==true ? "checkmark.circle.fill":"circle")}.buttonStyle(.plain).accessibilityIdentifier("swiftCompitiToggle");VStack(alignment:.leading,spacing:4){Text(o["title"]?.string ?? "Compito");if let note=o["note"]?.string,!note.isEmpty{Text(note).font(.footnote).foregroundStyle(.secondary)}};Spacer();Text(NOVASwiftOverview.deadline(o["due"]?.string ?? "")).font(.caption).foregroundStyle(red ? .red:.secondary)}
    }
}
@MainActor struct NOVASwiftOrario:View {
    @ObservedObject var store:NOVASwiftStore
    @State private var selected=""
    var lessons:[NOVAJSON]{store.archive?.active.object?["ls"]?.array ?? []}
    var days:[String]{Array(Set(lessons.compactMap{$0.object?["d"]?.string})).sorted()}
    static func clock(_ value:String)->String{let parts=value.split(separator:"T");return parts.count==2 ? String(parts[1]):value}
    func defaultDay()->String{let today=NOVASwiftTaskDay.key(Date()),tomorrow=NOVASwiftTaskDay.key(Calendar.current.date(byAdding:.day,value:1,to:Date()) ?? Date());return days.contains(today) ? today:days.contains(tomorrow) ? tomorrow:days.first ?? ""}
    var body:some View {
        let current=selected.isEmpty ? defaultDay():selected
        let rows=lessons.filter{$0.object?["d"]?.string==current}.sorted{($0.object?["b"]?.string ?? "")<($1.object?["b"]?.string ?? "")}
        return List{
            if lessons.isEmpty{Text("Nessuna lezione importata. Collega ClasseViva e aggiorna.").foregroundStyle(.secondary)}
            if !days.isEmpty{Section{ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){ForEach(days,id:\.self){day in Button(NOVASwiftCompiti.label(day)){selected=day}.buttonStyle(.bordered).tint(day==current ? Color.accentColor:Color.secondary).accessibilityIdentifier("swiftOrarioDay")}}}}}
            Section(current.isEmpty ? "Lezioni":NOVASwiftCompiti.label(current)){
                if rows.isEmpty{Text("Nessuna lezione per questo giorno.").foregroundStyle(.secondary)}
                ForEach(Array(rows.enumerated()),id:\.offset){_,lesson in lessonRow(lesson)}
            }
        }.navigationTitle("Orario").environment(\.locale,Locale(identifier:"it_IT"))
    }
    @ViewBuilder func lessonRow(_ lesson:NOVAJSON)->some View {
        let o=lesson.object ?? [:]
        HStack(alignment:.top){VStack(alignment:.leading,spacing:4){Text(o["s"]?.string ?? "Lezione").font(.headline).accessibilityIdentifier("swiftOrarioLesson");if let teacher=o["t"]?.string,!teacher.isEmpty{Text(teacher).font(.footnote).foregroundStyle(.secondary)};if let arg=o["arg"]?.string,!arg.isEmpty{Text(arg).font(.footnote).foregroundStyle(.secondary)}};Spacer();VStack(alignment:.trailing,spacing:4){Text(NOVASwiftOrario.clock(o["b"]?.string ?? "")).font(.subheadline);Text(o["h"]?.string ?? "").font(.caption).foregroundStyle(.secondary)}}
    }
}
@MainActor struct NOVASwiftPagella:View {
    @ObservedObject var store:NOVASwiftStore
    @Environment(\.dismiss) var dismiss
    @State private var status=""
    var grades:[NOVAJSON]{store.archive?.active.object?["gr"]?.array ?? []}
    var absences:[NOVAJSON]{store.archive?.active.object?["ab"]?.array ?? []}
    var grouped:[String:[NOVAJSON]]{Dictionary(grouping:grades,by:{$0.object?["subj"]?.string ?? "Materia"})}
    func average(_ subject:String)->Double{let values=(grouped[subject] ?? []).compactMap{row -> Double? in if case .number(let n)?=row.object?["v"]{return n};return nil};guard !values.isEmpty else{return 0};return values.reduce(0,+)/Double(values.count)}
    var subjects:[String]{grouped.keys.sorted()}
    var overall:Double{let all=subjects.map{average($0)};guard !all.isEmpty else{return 0};return all.reduce(0,+)/Double(all.count)}
    var body:some View {
        NavigationStack{ScrollView{VStack(spacing:20){pagellaCard;Button{share()}label:{Label("Condividi immagine",systemImage:"square.and.arrow.up")}.accessibilityIdentifier("swiftPagellaShare");if !status.isEmpty{Text(status).foregroundStyle(.red)}}.padding(20)}.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Pagella").toolbar{Button("Chiudi"){dismiss()}}}.environment(\.locale,Locale(identifier:"it_IT"))
    }
    var pagellaCard:some View {
        VStack(alignment:.leading,spacing:12){
            Text("NOVA · Pagella").font(.headline)
            Text(store.archive?.active.object?["name"]?.string ?? "").font(.subheadline).foregroundStyle(.secondary)
            Divider()
            ForEach(subjects,id:\.self){subject in HStack{Text(subject);Spacer();Text(average(subject).formatted(.number.precision(.fractionLength(1)))).font(.headline)}}
            if subjects.isEmpty{Text("Nessun voto numerico salvato.").foregroundStyle(.secondary)}
            Divider()
            HStack{Text("Media generale").font(.headline);Spacer();Text(overall.formatted(.number.precision(.fractionLength(1)))).font(.title2.bold()).accessibilityIdentifier("swiftPagellaOverall")}
            Text(absenceLine()).font(.footnote).foregroundStyle(.secondary)
            Text("Dati ClasseViva · "+Date().formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier:"it_IT")))).font(.caption2).foregroundStyle(.secondary)
        }.padding(24).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:24)).accessibilityIdentifier("swiftPagellaCard")
    }
    func absenceLine()->String{let counts=Dictionary(grouping:absences,by:{$0.object?["k"]?.string ?? "altro"}).mapValues{$0.count};let a=counts["assenza"] ?? 0,r=counts["ritardo"] ?? 0,u=counts["uscita anticipata"] ?? 0;return "\(a) "+(a==1 ? "assenza":"assenze")+" · \(r) "+(r==1 ? "ritardo":"ritardi")+" · \(u) "+(u==1 ? "uscita anticipata":"uscite anticipate")}
    func share(){let renderer=ImageRenderer(content:pagellaCard.frame(width:360));renderer.scale=3;guard let image=renderer.uiImage else{status="Immagine non generata.";return};guard let scene=UIApplication.shared.connectedScenes.first as? UIWindowScene,let window=scene.windows.first,let root=window.rootViewController else{status="Condivisione non disponibile.";return};var top=root;while let presented=top.presentedViewController{top=presented};let sheet=UIActivityViewController(activityItems:[image],applicationActivities:nil);if let pop=sheet.popoverPresentationController{pop.sourceView=window;pop.sourceRect=CGRect(x:window.bounds.midX,y:window.bounds.midY,width:0,height:0)};top.present(sheet,animated:true)}
}

// A due date without a timezone belongs to the local calendar day, never UTC.
enum NOVASwiftTaskDay {
 static func key(_ date:Date,timeZone:TimeZone = .current)->String{var calendar=Calendar(identifier:.gregorian);calendar.timeZone=timeZone;let c=calendar.dateComponents([.year,.month,.day],from:date);return String(format:"%04d-%02d-%02d",c.year ?? 0,c.month ?? 0,c.day ?? 0)}
 static func tasks(_ values:[NOVAJSON],on date:Date,timeZone:TimeZone = .current)->[NOVAJSON]{let day=key(date,timeZone:timeZone);return values.filter{guard let due=$0.object?["due"]?.string else{return false};return due==day || due.hasPrefix(day+"T") || due.hasPrefix(day+" ")}}
}
