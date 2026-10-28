import SwiftUI
import CoreLocation
import UIKit

// Isolated device gate. No networking, account access, files, or coordinate display.
@MainActor final class LiveLabModel:NSObject,ObservableObject,CLLocationManagerDelegate {
    @Published var status="Test locale non avviato"
    @Published var active=false
    @Published var background=false
    @Published var accepted=0
    @Published var rejected=0
    @Published var foregroundCount=0
    @Published var backgroundCount=0
    @Published var lastAge="Nessuna lettura"
    @Published var lastAccuracy="Non disponibile"
    @Published var elapsed=0
    @Published var deliveredForeground=0
    @Published var deliveredNonactive=0
    @Published var filteredForeground=0
    @Published var filteredNonactive=0
    @Published var qualityFiltered=0
    @Published var timingFiltered=0
    @Published var movementFiltered=0
    @Published var consentFiltered=0
    @Published var nonactiveReasons=[0,0,0,0]
    @Published var foregroundSeconds=0
    @Published var nonactiveSeconds=0
    private var stateSince:Date?
    private var observedActive=true
    private let manager=CLLocationManager()
    private var stream:Task<Void,Never>?
    private var timer:Task<Void,Never>?
    private var activity:CLBackgroundActivitySession?
    private var start:Date?
    private var previous:CLLocation?
    private var sentAt:Date?
    private var pending=false
    private var observations:[NSObjectProtocol]=[]
    override init(){super.init();manager.delegate=self
        for name in [UIApplication.didBecomeActiveNotification,UIApplication.willResignActiveNotification]{
            observations.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main){[weak self] notification in
                let observedAt=Date()
                let becameActive=notification.name == UIApplication.didBecomeActiveNotification
                Task{@MainActor in self?.transition(to:becameActive,at:observedAt);self?.tick()}
            })
        }
    }
    private func transition(to isActive:Bool,at now:Date){guard active else{return};accountTime(at:now);observedActive=isActive}
    private func accountTime(at now:Date){guard active,let since=stateSince else{return};let seconds=max(0,Int(now.timeIntervalSince(since)));if observedActive{foregroundSeconds+=seconds}else{nonactiveSeconds+=seconds};stateSince=since.addingTimeInterval(Double(seconds))}
    private func resetDiagnostics(){deliveredForeground=0;deliveredNonactive=0;filteredForeground=0;filteredNonactive=0;nonactiveReasons=[0,0,0,0];qualityFiltered=0;timingFiltered=0;movementFiltered=0;consentFiltered=0;foregroundSeconds=0;nonactiveSeconds=0;stateSince=Date();observedActive=UIApplication.shared.applicationState == .active;lastAge="Nessuna lettura";lastAccuracy="Non disponibile"}
    func request(){guard !active else{return};pending=true
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse:begin()
        case .notDetermined:manager.requestWhenInUseAuthorization();status="Scegli il permesso di posizione di iOS."
        default:pending=false;status="Permesso negato. Nessun test avviato. Puoi cambiarlo nelle impostazioni di iOS."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){if [.denied,.restricted].contains(manager.authorizationStatus){stop();status="Permesso negato: test fermato."}else if pending,[.authorizedAlways,.authorizedWhenInUse].contains(manager.authorizationStatus){begin()}}
    private func begin(){guard pending else{return};pending=false;resetDiagnostics();accepted=0;rejected=0;foregroundCount=0;backgroundCount=0;previous=nil;sentAt=nil;elapsed=0;start=Date();active=true
        if background{activity=CLBackgroundActivitySession()}
        status=background ? "Test locale con background attivo":"Test locale solo in primo piano"
        timer=Task{[weak self] in while !Task.isCancelled{try? await Task.sleep(for:.seconds(1));guard !Task.isCancelled else{return};self?.tick()}}
        stream=Task{[weak self] in do{for try await update in CLLocationUpdate.liveUpdates(){guard !Task.isCancelled,let self=self,self.active else{return};self.tick();guard self.active else{return};if let fix=update.location{self.receive(fix)};if update.isStationary{self.status="Dispositivo fermo: iOS può ridurre gli aggiornamenti."}}}catch{guard !Task.isCancelled else{return};self?.stop();self?.status="iOS ha interrotto il test. Nessun dato inviato."}}
    }
    private func tick(){guard active,let start=start else{return};accountTime(at:Date());elapsed=Int(Date().timeIntervalSince(start));if elapsed>=600{stop();status="10 minuti conclusi. Test fermato, nessun dato inviato."}}
    private func receive(_ fix:CLLocation){receive(fix,at:Date(),isActive:UIApplication.shared.applicationState == .active)}
    private func receive(_ fix:CLLocation,at now:Date,isActive:Bool){guard active else{return}
        if isActive{deliveredForeground+=1}else{deliveredNonactive+=1}
        let age=now.timeIntervalSince(fix.timestamp);lastAge=String(format:"%.0f secondi",max(0,age));lastAccuracy=String(format:"± %.0f metri",fix.horizontalAccuracy)
        func reject(_ reason:Int){rejected+=1;if isActive{filteredForeground+=1}else{filteredNonactive+=1;nonactiveReasons[reason]+=1};switch reason{case 0:qualityFiltered+=1;case 1:timingFiltered+=1;case 2:movementFiltered+=1;default:consentFiltered+=1}}
        guard age>=(-5),age<30,fix.horizontalAccuracy>=0,fix.horizontalAccuracy<=200 else{reject(0);return}
        if let sentAt=sentAt{let elapsed=now.timeIntervalSince(sentAt);guard elapsed>=15 else{reject(1);return};guard (previous.map{fix.distance(from:$0)>=15} ?? true)||elapsed>=120 else{reject(2);return}}
        guard background || isActive else{reject(3);return}
        accepted+=1;if isActive{foregroundCount+=1}else{backgroundCount+=1};previous=fix;sentAt=now
    }
    func stop(){accountTime(at:Date());stateSince=nil;pending=false;active=false;stream?.cancel();stream=nil;timer?.cancel();timer=nil;activity?.invalidate();activity=nil;previous=nil;sentAt=nil;start=nil;status="Test fermato. Nessun dato inviato."}
    #if DEBUG
    func syntheticActive(){resetDiagnostics();synthetic();active=true;background=true;start=Date().addingTimeInterval(-195);timer=Task{try? await Task.sleep(for:.seconds(3600))};stream=Task{try? await Task.sleep(for:.seconds(3600))};status="Test sintetico attivo. Nessun sensore avviato."}
    func syntheticChecks()->[String:Bool]{
        syntheticActive();stop();let stopped = !active && stream==nil && timer==nil && activity==nil && previous==nil && sentAt==nil && start==nil
        syntheticActive();start=Date().addingTimeInterval(-601);tick();let timeout = !active && stream==nil && timer==nil && activity==nil && previous==nil && sentAt==nil
        syntheticActive();stop();let cancellation = !active && stream==nil && timer==nil && activity==nil
        resetDiagnostics();accepted=0;rejected=0;foregroundCount=0;backgroundCount=0;previous=nil;sentAt=nil;active=true;background=true
        let base=Date()
        func fix(_ delta:Double,_ lat:Double=44.0,_ accuracy:Double=12)->CLLocation{CLLocation(coordinate:CLLocationCoordinate2D(latitude:lat,longitude:11),altitude:0,horizontalAccuracy:accuracy,verticalAccuracy:12,timestamp:base.addingTimeInterval(delta))}
        receive(fix(0),at:base,isActive:true)
        receive(fix(5),at:base.addingTimeInterval(5),isActive:false)
        receive(fix(20),at:base.addingTimeInterval(20),isActive:false)
        receive(fix(25,44.001,250),at:base.addingTimeInterval(25),isActive:false)
        receive(fix(40,44.001),at:base.addingTimeInterval(40),isActive:false)
        background=false;receive(fix(60,44.002),at:base.addingTimeInterval(60),isActive:false)
        let counters=accepted==2 && rejected==4 && deliveredForeground==1 && deliveredNonactive==5 && filteredForeground==0 && filteredNonactive==4 && foregroundCount==1 && backgroundCount==1
        let reasons=qualityFiltered==1 && timingFiltered==1 && movementFiltered==1 && consentFiltered==1 && nonactiveReasons==[1,1,1,1] && qualityFiltered+timingFiltered+movementFiltered+consentFiltered==rejected
        stateSince=base;observedActive=true;foregroundSeconds=0;nonactiveSeconds=0;transition(to:false,at:base.addingTimeInterval(10));transition(to:true,at:base.addingTimeInterval(50));accountTime(at:base.addingTimeInterval(60));let lifecycle=foregroundSeconds==20 && nonactiveSeconds==40
        stop()
        return ["diagnostic_counters_partition":counters,"diagnostic_filter_reasons":reasons,"observed_lifecycle_time":lifecycle,"stop_clears_state":stopped,"ten_minute_timeout_clears_state":timeout,"background_resources_cleared":cancellation,"synthetic_never_started_sensor":stream==nil && activity==nil]
    }
    func synthetic(){accepted=9;rejected=22;foregroundCount=6;backgroundCount=3;lastAge="2 secondi";lastAccuracy="± 18 metri";elapsed=195;deliveredForeground=15;deliveredNonactive=16;filteredForeground=9;filteredNonactive=13;nonactiveReasons=[1,7,5,0];qualityFiltered=2;timingFiltered=12;movementFiltered=8;foregroundSeconds=75;nonactiveSeconds=120;status="Anteprima sintetica. Nessun sensore avviato."}
    #endif
}
struct LiveLabView:View {
    @StateObject private var model=LiveLabModel()
    @State private var confirm=false
    var body:some View{NavigationStack{Form{
        Section{Text("Test separato da NOVA").font(.headline);Text("Non accede al tuo account. Non invia dati e non condivide posizioni con gli amici. Le coordinate restano solo in memoria durante il test e non sono mostrate o salvate.")}
        Section("Sessione locale · massimo 10 minuti"){
            Toggle("Prova anche in background",isOn:$model.background).disabled(model.active)
            Text("iOS può mostrare l'indicatore posizione e sospendere gli aggiornamenti. Chiudere forzatamente l'app interrompe la prova. Non è un servizio sempre garantito.").font(.caption)
            if model.active{Text("Test in corso. Ferma test dalla barra in alto.")}else{Button("Avvia test locale"){confirm=true}}
            Text(model.status).accessibilityIdentifier("liveLabStatus")
        }
        Section("Risultati locali, senza coordinate"){
            LabeledContent("Tempo trascorso",value:"\(model.elapsed / 60)m \(model.elapsed % 60)s")
            LabeledContent("Letture accettabili",value:String(model.accepted))
            LabeledContent("Letture filtrate",value:String(model.rejected))
            LabeledContent("In primo piano",value:String(model.foregroundCount))
            LabeledContent("In background",value:String(model.backgroundCount))
            LabeledContent("Età dell'ultima lettura",value:model.lastAge)
            LabeledContent("Precisione",value:model.lastAccuracy)
        }
        Section("Diagnostica consegna · stato al callback"){
            LabeledContent("Ricevute · app attiva",value:String(model.deliveredForeground))
            LabeledContent("Ricevute · app non attiva",value:String(model.deliveredNonactive))
            LabeledContent("Filtrate · app attiva",value:String(model.filteredForeground))
            LabeledContent("Filtrate · app non attiva",value:String(model.filteredNonactive))
            Text("Motivi filtro: totale / app non attiva").font(.caption)
            LabeledContent("Filtro età o precisione",value:"\(model.qualityFiltered) / \(model.nonactiveReasons[0])")
            LabeledContent("Filtro intervallo < 15s",value:"\(model.timingFiltered) / \(model.nonactiveReasons[1])")
            LabeledContent("Filtro movimento / attesa",value:"\(model.movementFiltered) / \(model.nonactiveReasons[2])")
            LabeledContent("Filtro background non scelto",value:"\(model.consentFiltered) / \(model.nonactiveReasons[3])")
            LabeledContent("Tempo osservato · attiva",value:"\(model.foregroundSeconds)s")
            LabeledContent("Tempo osservato · non attiva",value:"\(model.nonactiveSeconds)s")
            Text("Non attiva include blocco schermo, cambio app e interruzioni. Lo stato è quello al momento della consegna, non quando il GPS ha misurato la posizione. Non prova l'esecuzione continua mentre iOS sospende l'app.").font(.caption)
        }
        Section{Text("Età e precisione descrivono l'ultima lettura ricevuta, anche se filtrata. Dopo Stop i valori restano fermi. I motivi di filtro sono esclusivi: viene contato il primo controllo non superato.").font(.caption)}
        Section{Text("Filtro: letture recenti meno di 30 secondi e precisione entro 200 metri. Minimo 15 secondi tra letture accettate mentre ti muovi; da fermo circa 120 secondi, solo se iOS fornisce una nuova lettura. Nessun invio al server.").font(.caption)}
    }.navigationTitle("NOVA Live Lab").toolbar{if model.active{ToolbarItem(placement:.topBarTrailing){Button("Ferma test",role:.destructive){model.stop()}}}}}.alert("Avviare il test locale di posizione?",isPresented:$confirm){Button("Avvia 10 minuti"){model.request()};Button("Annulla",role:.cancel){}}message:{Text("Usa la posizione reale su questo iPhone per valutare gli aggiornamenti di iOS. Nessun dato lascia il telefono; più consumo di batteria durante la prova. Puoi fermarla in qualsiasi momento.")}.task{
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if args.contains("--synthetic-preview"){model.synthetic()}
        if args.contains("--synthetic-active"){model.syntheticActive()}
        if args.contains("--synthetic-confirm"){model.synthetic();confirm=true}
        if args.contains("--synthetic-checks"){let checks=model.syntheticChecks();try! JSONSerialization.data(withJSONObject:checks,options:.sortedKeys).write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("checks.json"));precondition(checks.values.allSatisfy{$0})}
        #endif
    }}
}
@main struct LiveLabApp:App {var body:some Scene{WindowGroup{LiveLabView()}}}
