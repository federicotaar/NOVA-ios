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
    private let manager=CLLocationManager()
    private var stream:Task<Void,Never>?
    private var timer:Task<Void,Never>?
    private var activity:CLBackgroundActivitySession?
    private var start:Date?
    private var previous:CLLocation?
    private var sentAt:Date?
    private var pending=false
    private var observations:[NSObjectProtocol]=[]
    override init(){super.init();manager.delegate=self;observations.append(NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main){[weak self] _ in Task{@MainActor in self?.tick()}})}
    func request(){guard !active else{return};pending=true
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse:begin()
        case .notDetermined:manager.requestWhenInUseAuthorization();status="Scegli il permesso di posizione di iOS."
        default:pending=false;status="Permesso negato. Nessun test avviato. Puoi cambiarlo nelle impostazioni di iOS."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){if [.denied,.restricted].contains(manager.authorizationStatus){stop();status="Permesso negato: test fermato."}else if pending,[.authorizedAlways,.authorizedWhenInUse].contains(manager.authorizationStatus){begin()}}
    private func begin(){guard pending else{return};pending=false;accepted=0;rejected=0;foregroundCount=0;backgroundCount=0;previous=nil;sentAt=nil;elapsed=0;start=Date();active=true
        if background{activity=CLBackgroundActivitySession()}
        status=background ? "Test locale con background attivo":"Test locale solo in primo piano"
        timer=Task{[weak self] in while !Task.isCancelled{try? await Task.sleep(for:.seconds(1));guard !Task.isCancelled else{return};self?.tick()}}
        stream=Task{[weak self] in do{for try await update in CLLocationUpdate.liveUpdates(){guard !Task.isCancelled,let self=self,self.active else{return};self.tick();guard self.active else{return};if let fix=update.location{self.receive(fix)};if update.isStationary{self.status="Dispositivo fermo: iOS può ridurre gli aggiornamenti."}}}catch{guard !Task.isCancelled else{return};self?.stop();self?.status="iOS ha interrotto il test. Nessun dato inviato."}}
    }
    private func tick(){guard active,let start=start else{return};elapsed=Int(Date().timeIntervalSince(start));if elapsed>=600{stop();status="10 minuti conclusi. Test fermato, nessun dato inviato."}}
    private func receive(_ fix:CLLocation){guard active else{return};let now=Date(),age=now.timeIntervalSince(fix.timestamp);lastAge=String(format:"%.0f secondi",max(0,age));lastAccuracy=String(format:"± %.0f metri",fix.horizontalAccuracy)
        guard age>=(-5),age<30,fix.horizontalAccuracy>=0,fix.horizontalAccuracy<=200 else{rejected+=1;return}
        if let sentAt=sentAt{let elapsed=now.timeIntervalSince(sentAt);guard elapsed>=15,(previous.map{fix.distance(from:$0)>=15} ?? true)||elapsed>=120 else{rejected+=1;return}}
        guard background || UIApplication.shared.applicationState == .active else{rejected+=1;return}
        accepted+=1;if UIApplication.shared.applicationState == .active{foregroundCount+=1}else{backgroundCount+=1};previous=fix;sentAt=now
    }
    func stop(){pending=false;active=false;stream?.cancel();stream=nil;timer?.cancel();timer=nil;activity?.invalidate();activity=nil;previous=nil;sentAt=nil;start=nil;status="Test fermato. Nessun dato inviato."}
    #if DEBUG
    func syntheticActive(){synthetic();active=true;background=true;start=Date().addingTimeInterval(-195);status="Test sintetico attivo. Nessun sensore avviato."}
    func syntheticChecks()->[String:Bool]{
        syntheticActive();stop();let stopped = !active && stream==nil && timer==nil && activity==nil && previous==nil && sentAt==nil && start==nil
        syntheticActive();start=Date().addingTimeInterval(-601);tick();let timeout = !active && stream==nil && timer==nil && activity==nil && previous==nil && sentAt==nil
        syntheticActive();stop();let cancellation = !active && stream==nil && timer==nil && activity==nil
        return ["stop_clears_state":stopped,"ten_minute_timeout_clears_state":timeout,"background_resources_cleared":cancellation,"synthetic_never_started_sensor":stream==nil && activity==nil]
    }
    func synthetic(){accepted=9;rejected=22;foregroundCount=6;backgroundCount=3;lastAge="2 secondi";lastAccuracy="± 18 metri";elapsed=195;status="Anteprima sintetica. Nessun sensore avviato."}
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
            if model.active{Button("Ferma test",role:.destructive){model.stop()}}else{Button("Avvia test locale"){confirm=true}}
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
        Section{Text("Filtro: letture recenti meno di 30 secondi e precisione entro 200 metri. Minimo 15 secondi tra letture accettate mentre ti muovi; da fermo circa 120 secondi, solo se iOS fornisce una nuova lettura. Nessun invio al server.").font(.caption)}
    }.navigationTitle("NOVA Live Lab")}.confirmationDialog("Avviare il test locale di posizione?",isPresented:$confirm,titleVisibility:.visible){Button("Avvia 10 minuti"){model.request()};Button("Annulla",role:.cancel){}}message:{Text("Usa la posizione reale su questo iPhone per valutare gli aggiornamenti di iOS. Nessun dato lascia il telefono; più consumo di batteria durante la prova. Puoi fermarla in qualsiasi momento.")}.task{
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if args.contains("--synthetic-preview"){model.synthetic()}
        if args.contains("--synthetic-active"){model.syntheticActive()}
        if args.contains("--synthetic-confirm"){model.synthetic();confirm=true}
        if args.contains("--synthetic-checks"){let checks=model.syntheticChecks();print("LIVE_LAB_CHECKS "+String(data:try! JSONSerialization.data(withJSONObject:checks,options:.sortedKeys),encoding:.utf8)!);precondition(checks.values.allSatisfy{$0})}
        #endif
    }}
}
@main struct LiveLabApp:App {var body:some Scene{WindowGroup{LiveLabView()}}}
