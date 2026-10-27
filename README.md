<p align="center">
  <img src="assets/1-icon1024.png" width="104" alt="NOVA">
</p>
<h1 align="center">NOVA</h1>
<p align="center"><strong>Studio, persone e giornata. In un unico posto.</strong></p>
<p align="center">Una dashboard per iPhone con compiti, voti, orario, assistente AI e chat.</p>
<p align="center">
  <a href="#installazione">Installazione</a> · <a href="#anteprima">Anteprima</a> · <a href="#stato-del-progetto">Stato del progetto</a> · <a href="#privacy-e-controllo">Privacy</a>
</p>

---

## Composer e avvisi gruppo in verifica - 27 ottobre, 19:00

- Forma compatta approvata in anteprima: campo vuoto44pt, + separato, angoli22pt, massimo quattro righe visibili con scorrimento; foto, vocali social e invio conservati.
- Campo con Liquid Glass nativo su iOS26 e materiale di sistema sulle versioni precedenti. Variante con tinta chiara in revisione visiva: non ancora accettata su iPhone, nessuna nuova IPA pubblicata.
- Anteprime effettive dei percorsi Chat > Assistente e Chat > Gruppo con dati sintetici: invio libero da sovrapposizioni, chiusura tastiera in alto e screenshot dopo l'animazione. [Gruppo](https://github.com/federicotaranudev/NOVA-ios/actions/runs/40553852137), [Assistente](https://github.com/federicotaranudev/NOVA-ios/actions/runs/40553977657).
- Avviso generico dentro NOVA solo mentre l'app è attiva, controllo ogni10secondi: prima lettura silenziosa, niente doppioni, propri messaggi o messaggi già letti; risultati di sessioni precedenti scartati. [Sette controlli e schermata integrata](https://github.com/federicotaranudev/NOVA-ios/actions/runs/40553875074). Non è APNs né una notifica di sistema a app chiusa. Nessun servizio a pagamento o app aggiuntiva introdotti.
- Restano da verificare ricezione e uso sul dispositivo con servizi reali. Le schermate sintetiche non dimostrano velocità o consegna reali. Il TEST27.3 pubblicato resta invariato.

## La tua giornata, a colpo d'occhio

NOVA riunisce il lavoro scolastico e gli strumenti per organizzarlo: compiti e verifiche, calendario, voti, orario e promemoria. L'assistente AI è una chat a cui chiedere aiuto; amici e gruppi hanno conversazioni separate.

Il progetto è in sviluppo attivo. Una build disponibile al download non significa che ogni funzione sia stata verificata su ogni dispositivo. Le novità in corso sono indicate sotto, senza confonderle con le funzioni già presenti.

## Anteprima

<table>
  <tr>
    <td align="center"><img src="assets/1-chat-list.png" width="250" alt="Elenco chat NOVA con contenuti dimostrativi"><br><strong>Chat</strong><br>Assistente e conversazioni in un solo elenco.</td>
    <td align="center"><img src="assets/2-composer-preview.png" width="250" alt="Anteprima del composer Liquid Glass in sviluppo, con tastiera e messaggi sintetici"><br><strong>Liquid Glass · In sviluppo</strong><br>Anteprima del composer nativo.</td>
  </tr>
</table>

Screenshot reali di una build di sviluppo nel simulatore iOS, con dati e messaggi sintetici. Non sono chat di utenti reali. Il secondo screenshot mostra lavoro in corso, non una promessa che ogni release abbia già lo stesso risultato su iPhone.

## Già presente nell'app

| Area | Cosa offre |
| --- | --- |
| **Dashboard** | Compiti manuali, calendario, prossime verifiche, batteria e meteo su richiesta. |
| **Scuola** | Collegamento a ClasseViva per importare dati del registro, voti e orario modificabile. |
| **Assistente** | Chat AI tramite Groq con la propria chiave, lettura della foto dell'orario e permessi per le azioni. |
| **Persone** | Account NOVA, username, profili, richieste di amicizia, messaggi e gruppi. |
| **Mappa amici** | Condivisione della posizione facoltativa e modalità Fantasma. Nessuna condivisione da attivare per usare il resto dell'app. |
| **Widget** | Orario, lezioni, fine scuola e calendario. La disponibilità dei dati dipende dalla firma e dall'accesso all'App Group. |
| **Notifiche** | Promemoria locali e integrazione ntfy per avvisi sociali. Richiedono configurazione e permessi; non sono un servizio push nativo APNs. |

"Presente" descrive la funzione disponibile nel progetto, non una garanzia di assenza di bug. Per i limiti pratici, leggi le note di installazione e lo stato qui sotto.

## Stato del progetto

| Stato | Attività | Nota |
| --- | --- | --- |
| 🟡 **In corso** | **Implementazione Liquid Glass** | Composer, navigazione con lente Apple, rifrazione ai bordi e controlli della mappa. Verifiche visive e integrazione su dispositivo ancora in corso. |
| 🟡 **In corso** | Impostazioni organizzate | Nuova pagina opaca a sezioni, scorrimento sotto l’intestazione separato, interruttori nativi Apple e controlli glass. In verifica: nessuna modifica automatica alle scelte o ai permessi. |
| 🟡 **In corso** | Avvisi al centro | Messaggi di stato poco sopra il centro con vetro nativo, lontani dalla barra. Verifica visiva e su dispositivo in corso. |
| 🟡 **In corso** | Pulsanti glass in tutta l'app | Superfici native Apple per i pulsanti di azione e selezione, lasciando i tocchi e i permessi ai controlli originali. Verifiche schermata per schermata ancora in corso. |
| 🟡 **In corso** | Ritorno dalla chat AI all'elenco | Correzione della visibilità dell'elenco e test di navigazione. |
| 🟡 **In corso** | Avatar e isolamento account | Foto del profilo nella navigazione, visibilità tra amici accettati e aggiornamenti al cambio account. |
| 🟡 **In verifica** | Foto, vocali e notifiche | Controlli su annullamento, cambio chat, permessi e comportamento sui dispositivi. |
| 🔜 **Prossimamente** | Consegna delle correzioni in corso | Dopo le verifiche della build. Nessuna data promessa. |

Le voci "In corso" e "Prossimamente" non sono funzioni da considerare concluse. Le priorità possono cambiare in base ai test.

## Installazione

1. Apri [Releases](https://github.com/federicotaranudev/NOVA-ios/releases) e scegli una versione, leggendo le sue note. Le versioni precedenti restano disponibili.
2. Scarica il file `.ipa` della versione scelta. È **non firmato**: serve un metodo di sideloading, per esempio AltStore o Sideloadly.
3. Per aggiornare, mantieni lo stesso identificativo dell'app e installa sopra la copia esistente. Non cancellare l'app come primo tentativo per correggere un problema.

**Requisiti:** iOS 17 o successivo. I nuovi controlli Liquid Glass richiedono iOS 26; sui sistemi precedenti resta l'interfaccia alternativa.

La firma gratuita ha limiti di durata e di App ID. I widget possono richiedere un App ID aggiuntivo. La sincronizzazione tra app e widget può essere limitata se l'App Group non è disponibile con la firma usata.

## Privacy e controllo

- L'account NOVA può salvare online configurazione e dati dell'app per il ripristino. Il progetto non va descritto come "tutto solo sul telefono".
- Credenziali ClasseViva e chiavi dei servizi restano sul dispositivo e non fanno parte del backup NOVA. Le richieste ai servizi usati dall'app passano ai rispettivi fornitori.
- Le conversazioni sociali usano il backend NOVA. Non sono dichiarate cifrate end-to-end.
- La condivisione della posizione è facoltativa. Fantasma disattiva la visibilità; gli orari di aggiornamento contano, e una posizione vecchia non è una posizione in diretta.
- Il codice ntfy personale è privato: non pubblicarlo in screenshot o segnalazioni.

## Limiti da conoscere

- iOS decide quando concedere attività in background. Non c'è una promessa di controllo continuo del registro o di aggiornamenti istantanei ad app chiusa.
- Promemoria e notifiche dipendono dai permessi e dalla configurazione del dispositivo. L'integrazione ntfy richiede l'app ntfy e l'iscrizione al proprio codice.
- L'assistente richiede una chiave Groq e una connessione. Le risposte AI possono sbagliare: controlla i dati importanti prima di usarli.
- Le immagini del simulatore non sostituiscono una verifica sul telefono. Le release di prova possono avere difetti aperti.

## Struttura

```text
Sources/NOVA/NOVAApp.swift    Interfaccia e integrazioni native iOS
Sources/NOVA/nova.html        Dashboard e logica dell'app locale
Sources/NOVAWidget/           Widget iOS
.github/workflows/           Build e controlli automatici
```

Le build vengono pubblicate come release versionate. Le vecchie release vengono conservate, non sostituite dal file di una nuova versione.

### Verifica sincronizzazione foto

Il ripristino del profilo attende il backup account prima di confrontare la foto locale con quella condivisa agli amici. I due caricamenti non partono più in parallelo; le copie in conflitto restano da scegliere, senza sovrascritture automatiche. Se il profilo sul server non contiene una foto, la nuova versione può sincronizzare la foto già conservata sul telefono del proprietario. Non ricostruisce immagini assenti e non copia foto da altri account.

I pulsanti nativi rispettano la dimensione del testo del controllo originale e restano sotto la barra di navigazione, senza spostare i bersagli di tocco. Le schermate di verifica restano separate dai dati reali.

### Copertura controlli personalizzati

La migrazione include il pulsante Nuova chat, giorni del calendario, azioni dei compiti, scelte a chip, reazioni e pulsanti testuali. Le righe chat con foto e anteprima conservano il contenuto originale: la loro presentazione resta da verificare separatamente. Nessun bersaglio di tocco, conferma o permesso viene sostituito.

### Righe chat native

Le righe chat usano una superficie Apple Glass con foto, titolo e anteprima separati. L’immagine fornita dal profilo resta nella riga, senza ricavare foto mancanti o alterare i dati degli amici. Le azioni restano sui controlli originali.

La conversazione e il pannello reazioni nascondono le superfici native della pagina sottostante. Le icone dei compiti sono mappate esplicitamente; le altre icone SVG vengono confrontate dopo normalizzazione del markup.

Il filtro della barra di navigazione non si applica ai pulsanti di un pannello azioni aperto: anche Chiudi mantiene la superficie nativa. Intro e onboarding restano fuori da questa migrazione e non sono dichiarati completati.

### Prima apertura

Le superfici native includono i pulsanti della configurazione iniziale: Indietro, Avanti, Salta, scelte tema/widget e azioni dei servizi. I bersagli originali conservano eventi, conferme e permessi. Nessun servizio viene autorizzato o configurato automaticamente. L’intro conserva il gesto Tocca per saltare e la durata originale: non viene aggiunto un nuovo pulsante né un nuovo passaggio.

### 2026.10.25.29

Anche il selettore foto nella configurazione iniziale usa un pulsante glass: apre lo stesso selettore di sistema e mantiene la gestione originale della foto. Nessuna attivazione automatica di account o permessi. Verifica visiva e su dispositivo ancora distinta.

### 2026.10.25.30

Il selettore del file di personalità dell’assistente usa lo stesso pulsante glass degli altri caricamenti. Tipi di file, lettura locale e conferma del testo restano invariati. Nessun file viene scelto o letto senza il gesto dell’utente.

### 2026.10.25.31

Aprendo agent.md, il focus iniziale va al titolo invece di aprire subito l’editor. Altezza del testo limitata alla finestra: selettore e conferme restano nel dialogo. Lettura locale e salvataggio esplicito invariati.

### 2026.10.25.32

Il dialogo agent.md segue la finestra visibile durante la modifica, con titolo e conferme nel pannello scorrevole. Nessuna modifica ai file, ai permessi o al salvataggio.

### 2026.10.25.33

Prima schermata nativa: Impostazioni usa una lista UIKit con campi, interruttori e azioni nello stesso scorrimento. Non usa più controlli posizionati sopra righe HTML. Lo stato e le conferme restano nei gestori esistenti; le destinazioni separate profilo, orario e introduzione restano disponibili. Il resto dell’app continua la migrazione: non è ancora interamente nativo. Verifica su dispositivo ancora necessaria.

### 2026.10.25.34

Impostazioni native: gruppi dedicati a profilo, nome, account e preferenze; le spiegazioni restano a piè di gruppo invece di diventare righe separate. Intestazione nativa opaca con titolo visibile. Verifiche di scorrimento e azioni in corso.

### 2026.10.25.35

Anche i collegamenti presenti nelle spiegazioni dei servizi hanno un’azione nella pagina nativa. Proseguono i controlli su campi, interruttori, isolamento account e ritorno alle destinazioni esistenti.

### 2026.10.25.36

Editor del profilo in pagina nativa: selettore foto iOS, username, scuola, punti forti, hobby, ricerca canzone e Salva/Annulla. Gestori originali per disponibilità username e salvataggio. La migrazione continua su dashboard, chat, mappa e altre schermate: non sono ancora tutte native.

### 2026.10.25.37

Titolo e azione di chiusura del profilo nativo distinti da Impostazioni. Restano Salva esplicito, Annulla e vincolo del primo profilo.

### 2026.10.25.38

Ricerca canzone nel profilo nativo: risultati aggiornati senza togliere il focus al campo. Username senza maiuscola automatica. Salvataggio del profilo ancora esplicito.

### 2026.10.25.39

Campi nativi con limiti di lunghezza originali, niente correzione automatica username. Cambi account/sessione terminano la modifica del campo prima di aggiornare la pagina. Risultati di ricerca aggiornati anche a parità di numero di righe.

### 2026.10.25.40

Aggiornamenti del modulo nativo preservano il campo attivo anche nelle righe Punti forti e Hobby.

### 2026.10.25.41

Transizioni dei moduli nativi serializzate: una riapertura rapida non viene persa durante la chiusura della pagina precedente.

### 2026.10.25.42

Home nativa UIKit con scorrimento e schede per ora, meteo, batteria, verifiche, compiti, calendario e Spotify. Dati e azioni restano negli handler esistenti; controlli nativi senza coordinate ricavate dal layout HTML. StandBy continua nel percorso originale. Azioni protette da account, sessione, pagina e modali aperti.

### 2026.10.25.43

Home nativa: intestazione con comandi a icone, testo compiti con spazio dedicato, giorni del calendario non spezzati su due righe. Epoch rinnovato anche uscendo e rientrando nella Home.

### 2026.10.25.44

Home nativa con titolo e scadenza compiti separati, marcatori calendario per compiti/verifiche e percentuale batteria. Il saluto viene aggiornato anche a schede invariate.

### 2026.10.25.45

Pagina Voti nativa: media generale, voti recenti e medie per materia con gli stessi calcoli e suggerimenti della versione precedente. Dati ClasseViva e account non modificati.

### 2026.10.25.46

Accesso alle impostazioni dalla pagina Voti nativa mantenendo i controlli account/sessione/modali.

### 2026.10.25.47

Nuovo compito nativo con titolo, descrizione multilinea, data e ora, priorità e promemoria tramite controlli UIKit. Conferma/cancellazione e validazione restano negli handler esistenti.

### 2026.10.25.48

Valori dei menu priorità/promemoria visibili nel modulo nativo; descrizione con etichetta di sezione esplicita.

### 2026.10.25.49

Correzioni da video e schermate reali: rimossi i duplicati nativi posizionati sopra le pagine web che restavano indietro durante lo scroll; i pulsanti originali restano usabili fino alla migrazione di quelle pagine. Spotify nativo a icone con etichette accessibilità. Separatore verifiche/scadenza. StandBy spento e pulsante rimosso. Batteria aggiornata al ritorno in primo piano; valori UIKit indicati come approssimativi, livello sconosciuto mai presentato come100%.

### 2026.10.25.50

L'editor dell'orario usa una pagina UIKit: giorni, lezioni, materie/aula, selettori dell'ora e azioni Salva/Annulla. I dati restano in bozza fino al salvataggio e mantengono lo stesso invio ai widget. L'importazione usa il selettore foto di sistema senza ritagliare la griglia dell'orario, poi lo stesso servizio Groq con la chiave locale. La lettura della foto resta da verificare sul dispositivo e non salva automaticamente il risultato.

### 2026.10.25.51

L'importazione dell'orario scarta i risultati se si chiude la bozza, si cambia account o si avvia una lettura più recente. Il risultato resta da controllare e salvare esplicitamente.

 workflow manuale test IPA, non avviato: flag Swift dedicato, prerelease immutabile, blocco tramite marker assente finché i gate integrati non sono accettati. Aggiunto typecheck del percorso con flag; non costituisce accettazione o pubblicazione.

- Launch2 ha eseguito import esplicito e mostrato Home con dati sintetici corretti, condivisione spenta. Interazione poi ferma al hideKeyboard generico del driver, tastiera ancora visibile in pixel. Aggiunto vero pulsante tastiera Fine tastiera e chiusura interattiva tramite scroll nel form compito; nuovo test usa il pulsante. Salvataggio/riavvio ancora pendenti.

- Launch3 ha rivelato concorrenza nel fixture: vecchia pagina sintetica riscriveva storage dopo il seed. Screenshot e archivio mostravano entrambi Synthetic invece del dato atteso. Ora interrompiamo navigazione/script fixture e passiamo a pagina inerte della stessa origine prima del seed. Non è prova di perdita dati reali, né un gate accettato.

## Swift test: gate simulatore accettato
- Launch5: import esplicito, tastiera Fine tastiera, compito salvato, impostazioni, ritorno setup, chiusura/riavvio con compito presente. Archivio conferma condivisione/background/sessioni disattivati. Artifact: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40358218516/artifacts/12667752258
- Manual296:76 controlli tutti veri e cinque schede reali ispezionate.
- Preparazione 2026.10.26.1 TEST Swift, non versione definitiva: IPA ancora da verificare. Installa sopra la stessa app, non eliminarla. Face ID, permessi, background su iPhone e servizi/account reali ancora non verificati.

## 2026.10.26.1 TEST Swift: IPA verificato
[Scarica IPA di prova](https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.26.1/NOVA-2026.10.26.1.ipa) - prerelease, non versione definitiva.
- File1.678.691byte, SHA256 `38eca6c85a2b05f2f24a4d2adff3d73cedfe6cd6008f588470a7e8782ebfdf0b`. Bundle `federicotaranu.site`, versione2601, SDK iOS26.5 confermato dal binario. Nome visibile NOVA Test Swift.
- Avvio reale `NOVASwiftLaunchRoot` con flag dedicato: schermate, stato e servizi Swift. HTML precedente conservato solo come risorsa/origine di migrazione una tantum, non come modello delle schermate del test. Widget e quattro clip narrazione inclusi. Nessun archivio personale confezionato.
- Gate simulatore: import esplicito, tastiera, salvataggio compito, impostazioni/setup e chiusura/riavvio;76 controlli sintetici/import/shell passati. Installare sopra la stessa app, senza eliminarla; controllare i propri dati prima di abilitare servizi.
- Ancora da verificare su iPhone: Face ID, foto/microfono, notifiche, comportamento background e servizi/account reali. La posizione non si attiva dalla migrazione. Pubblicatore normale disabilitato, release precedenti preservate.

## Correzione chat Swift: verifica in corso
- Riscontro iPhone nella build TEST: barra globale sopra il composer. Conversazioni e assistente ora richiedono di nascondere le tab globali; ritornano all'uscita.
- Messaggi compatti allineati a sinistra/destra, blu per i propri, neutri per gli altri. Foto limitate in larghezza; azioni, bozze e reazioni conservate.
- Gate dedicato sulla conversazione reale Swift con soli contenuti sintetici: apertura, tastiera, testo in bozza e ritorno all'elenco. Nessuna nuova IPA dichiarata pronta finché verifica e pacchetto non sono controllati.

## Mappa e copertine: batch successivo in verifica
- Mappa a tutto schermo, controlli flottanti a destra e pannello compatto espandibile. Nessuna lettura posizione automatica o autorizzazione richiesta all'apertura.
- Le vecchie flag di condivisione non bastano più per nuovi invii: conferma esplicita per condivisione e scelta separata per background. Uno stato precedente non confermato non viene presentato come server spento. Fantasma ferma gli invii locali e richiede conferma server.
- Copertine canzoni in profilo, modifica profilo, profilo pubblico e ricerca con componenti Swift nativi.
- Verifiche simulatore e pacchetto TEST ancora in corso. I riscontri iPhone non costituiscono accettazione finale di tutti i servizi.

## QR amici con N: verifica in corso
- Codice amici `nova:add:username` invariato, moduli arrotondati e N centrale; nessun collegamento a pagamenti. La scansione propone lo username e non invia richieste senza conferma.
- Correzione errore alta, bordo libero conservato. Gate dedicato decodifica tre username sintetici a due dimensioni prima di accettare l'IPA.

## 2026.10.26.2 TEST Swift: preparazione pacchetto
- Chat: conversazione Swift con composer libero dalla barra globale e messaggi compatti stile iMessage. Gate apertura/tastiera/bozza/ritorno passato nel run40373264331.
- Mappa a tutto schermo con pannello espandibile e controlli flottanti; cinque controlli di consenso separato passati nel run40371884896. Copertine native verificate nel run40369561161.
- QR amici arrotondato con N centrale: corretta la matrice verticale che produceva un quarto finder. Nel run40384003462 Vision revision1 legge esattamente tutti i sei casi sintetici a240/480, come il controllo standard. Il default revision4 nel simulatore non legge neppure il controllo standard. Il gate usa revision1 solo nel fixture; il lettore foto di produzione e la fotocamera restano invariati. Lettura su iPhone ancora da confermare.
- Pacchetto combinato di prova in preparazione, non ancora dichiarato pronto. Nessun reset account/dati, nessuna attivazione automatica posizione. Installare sopra la stessa app senza eliminarla. Accettazione reale di permessi, background e servizi/account resta aperta.

## 2026.10.26.2 TEST Swift: pacchetto verificato
- [IPA26.2](https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.26.2/NOVA-2026.10.26.2.ipa), prerelease immutabile. Bundle `federicotaranu.site`, versione2602, SDK26.5 confermato nel Mach-O, flag Swift TEST e widget presenti. SHA256 `bf29bcaf10a5d04f1e9e8ec2bc867db03568101aa27d7b29890321cde7ab7098`.
- Gate finale QR: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40386040814 riuscito, sei decodifiche sintetiche esatte; screenshot del codice arrotondato/N controllato. Build: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40386143579 riuscita.
- Solo build di prova: installazione sopra la stessa app senza eliminarla; verificare dati e QR su iPhone. Fotocamera, permessi, background e servizi/account reali non dichiarati accettati.26.1 e release precedenti conservate.

## Schermata legale: bozza in revisione (27 ottobre 2026)
- Impostazioni > Termini, privacy e licenze (bozza), schermata Swift nativa. Testi separati per uso app, dati e licenze, con stato BOZZA chiaro in ogni pagina. Nessuna accettazione, data di efficacia, nuova licenza NOVA o modifica dei consensi.
- Inventario tratto dal codice: archivio/copie locali, API account e social/backup/posizione, invii di contesto e foto a Groq, ClasseViva, Spotify, meteo, ntfy e risorsa HTML precedente. Nessuna promessa di solo-locale, cifratura end-to-end o cancellazione server verificata.
- Testi originali Leaflet BSD2, QRCode.js MIT e jsQR Apache2 inclusi come crediti della risorsa HTML; Package.swift non dichiara pacchetti esterni. Dati Open-Meteo attribuiti CC BY4. La licenza del codice NOVA non è scelta da questa aggiunta.
- Prima di finalizzare: gestore/contatto pubblico, pubblico/età, condizioni d’uso e scelta licenza; audit backend per conservazione, destinatari/trasferimenti, basi giuridiche e diritti/cancellazione. Non è una certificazione di conformità. Gate visivo dedicato in corso; nessuna nuova IPA pronta dichiarata.

## Segnalazioni bug: verifica in corso
- Scuoti il telefono nel percorso Swift sbloccato o apri Impostazioni > Segnala un bug. Il report è una bozza: descrizione obbligatoria, screenshot facoltativo visibile/rimovibile e conferma di controllo prima di preparare l’email.
- Destinatario supporto indicato: novasupporthelp@gmail.com. Mail di iOS prepara l’allegato e richiede Invia; il risultato non certifica la consegna. Senza Mail configurata, pannello di condivisione con istruzioni sul destinatario, nessuna promessa di invio automatico. Nessuna credenziale mail o nuovo backend.
- Schermate bloccate e campi sicuri visibili non vengono catturati; le altre schermate possono contenere dati personali, perciò la revisione resta obbligatoria. Nessuna raccolta automatica di log o segreti, nessun invio di test reale. La bozza viene svuotata alla chiusura/background. Gate sintetico in corso; comportamento fisico shake/Mail da verificare su iPhone.

## 2026.10.27.1 TEST: preparazione revisione legale e segnalazioni
- Gate bug report run40474914269 riuscito: apertura, screenshot sintetico, rimozione, descrizione, chiusura e tre controlli privacy/handler/destinatario. Nessuna email reale inviata. Aggiunto Fine tastiera per ricontrollare la parte finale prima di preparare l’invio.
- Gate legale run40476736224 riuscito: pagine informative e navigazione nativa. Contenuti ancora BOZZA, nessuna attivazione di termini/licenze o nuove accettazioni. Supporto pubblico autorizzato: novasupporthelp@gmail.com; non viene automaticamente designato contatto privacy/titolare.
- In preparazione IPA immutabile TEST2026.10.27.1. Da verificare su iPhone: shake fisico, compositore Mail e consegna. Il fallback Condividi richiede scelta dell’app e del destinatario, non garantisce invio al supporto. Decisioni legali e audit backend restano aperti.

## 2026.10.27.1 TEST verificato
- [Scarica IPA](https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.27.1/NOVA-2026.10.27.1.ipa):1.795.793byte, SHA256 `c6e408b29abdb6a91bf6ea6b36c553edd77be61cd3445a6cd8c7e44cd800ea5d`. Bundle invariato `federicotaranu.site`, build2701, Swift TEST, SDK26.5 confermato nel binario. Widget presente, nessun archivio personale incluso.
- Gate bug completo con screenshot/rimozione/descrizione/chiusura e parte finale: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40478637653 riuscito. Gate navigazione legale: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40476736224 riuscito. Screenshot reali sintetici ispezionati.
- Testi legali solo BOZZA da rivedere, non informativa/contratto definitivo. Supporto pubblico indicato, altre decisioni legali ancora aperte. Nessun invio email reale di test. Shake fisico, Mail e consegna da verificare sul dispositivo. Installare sopra la stessa app senza eliminarla; release precedenti conservate.

## 2026.10.27.2 TEST: calendario e composer assistente
- Calendario: il punto e il foglio del giorno usano la stessa chiave di data locale. Il vecchio filtro ISO8601 UTC poteva selezionare il giorno precedente a mezzanotte italiana. Aggiunto stato esplicito quando il giorno non contiene compiti; nessuna modifica ai compiti salvati.
- Assistente: composer nativo interattivo in safe-area inferiore, con contenuto scorrevole dietro e tastiera senza sovrapposizione. Il vetro nativo era gia' presente: questo intervento cambia disposizione/interazione, non dichiara la precedente assenza dell'API.
- Gate https://github.com/federicotaranudev/NOVA-ios/actions/runs/40499857226 riuscito: quattro controlli di data, giorno con compito corretto, giorno vuoto, bozza e tastiera senza invio. Pixel sintetici ispezionati. Verifica scura con cronologia sintetica riuscita: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40503744865 . Vetro e tastiera ispezionati anche in tema scuro. Nessuna email o richiesta AI reale, nessuno screenshot personale nel repository.
- IPA27.2 in preparazione. Release27.1 e precedenti immutate. Account, dati e permessi conservati; installare sopra senza eliminare l'app. Aspetto su iPhone e accettazione completa dei servizi reali restano da confermare; testi legali ancora BOZZA.

## 2026.10.27.2 TEST verificato
- [Scarica IPA](https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.27.2/NOVA-2026.10.27.2.ipa):1.798.988byte, SHA256 `fe6a567489ba7c1648aa98c5d2d155b786f7c95de8c2f9e232ce73dd46555464`. Bundle `federicotaranu.site`, build2702, Swift TEST, SDK26.5 confermato nel Mach-O; widget presente, nessun archivio personale nel pacchetto.
- Build riuscita: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40505762877 . Gate calendario/composer chiaro40499857226 e scuro40503744865 riusciti. Quattro controlli data e interazioni native verificati; screenshot reali sintetici ispezionati.
- Correzioni dei report: selezione dei compiti per data locale coerente con il calendario, stato vuoto esplicito, composer glass interattivo con contenuto dietro e posizione sopra la tastiera. Nessun invio AI o email di test reale.
- Prerelease immutabile, non app definitiva. Installare sopra la stessa app senza eliminarla;27.1 e precedenti conservate. Aspetto e servizi reali su iPhone restano da confermare; permessi/background e decisioni legali precedenti ancora aperti, testi legali BOZZA.

## 2026.10.27.3 TEST: verifica in corso
- Assistente aperto da Chat: rimosso lo stack di navigazione annidato, spazio verticale completo e piano di lettura separato dai messaggi dietro il composer glass. Pixel sintetici del percorso effettivo verificati con bozza vuota e multilinea; chiusura tastiera esplicita in verifica. Nessuno screenshot personale pubblicato, nessun invio AI reale.
- Profilo/amici: richieste indipendenti per amici/follower/seguiti avviate insieme. Gate https://github.com/federicotaranudev/NOVA-ios/actions/runs/40542344190 riuscito: tre richieste sintetiche da300ms caricano in0,413s, liste complete, risultati del vecchio account scartati. Non e' una misura della rete o dell'account reale.
- Backend27ottobre: letture liste social in batch, senza migrazioni o cache tra account.16 confronti SQLite sintetici con output/status equivalenti: inclusi blocchi nei due versi, avatar pubblici/amicizie, assenze e richieste senza autenticazione. Caso chat sintetico19->5viaggi DB, follower7->3, amici8->4; non e' un tempo reale misurato. Binding/servizi gratuiti e dati esistenti conservati.
- Avviso non bloccante di nuova IPA pubblicata in verifica. Solo i client che ricevono questa funzione potranno mostrare l'avviso:27.2 e build precedenti gia' installate non la acquisiscono dal server. Nessun download/installazione automatica o blocco d'uso.
-27.3 non ancora distribuita: restano verifica finale tastiera/avviso e ispezione IPA.27.2 e precedenti conservate, testi legali ancora BOZZA.

###27.3: controlli completati, pacchetto in preparazione
- Percorso reale Chat > Assistente, bozza vuota/multilinea/tastiera chiusa: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40543760565 riuscito; pixel sintetici ispezionati.
- Avviso nuova release: https://github.com/federicotaranudev/NOVA-ios/actions/runs/40543603063 riuscito; cinque controlli filtro versione/IPA/bozza e layout ispezionato. Avviso non bloccante, solo dopo una nuova IPA pubblicata; nessuna installazione automatica. I vecchi client senza questa funzione richiedono un primo aggiornamento manuale.
- Il miglioramento delle letture backend e' gia' attivo, versione09adbfc9-6590-46da-bcf6-f125079fe9de; nessuna modifica di schema/dati. I risultati sintetici non garantiscono i tempi reali sul telefono.

## 2026.10.27.3 TEST verificato
- [IPA27.3](https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.27.3/NOVA-2026.10.27.3.ipa):1.823.256byte, SHA256 `4b4ef6bb3f954364a25e071cd4777d0ba29dd4dfb66c8be9fbdb2e415de8a93f`. Bundle `federicotaranu.site`, build2703, Swift TEST, SDK26.5 verificato nel Mach-O, widget presente, nessun archivio personale incluso.
- Build https://github.com/federicotaranudev/NOVA-ios/actions/runs/40546193867 riuscita. Percorso Chat > Assistente con bozza vuota/multilinea e tastiera chiusa verificato nel simulatore; letture social parallele e avviso nuove IPA con i controlli sopra. Backend in batch gia' attivo, nessuna migrazione di dati o cambio delle regole di accesso.
- Aggiornamento manuale iniziale necessario:27.2/precedenti gia' installate non possono ricevere da remoto una funzione assente dal loro codice. Da27.3 in avanti l'avviso confronta release pubblicate con una IPA presente, senza bloccare l'app o installare automaticamente.
- Prerelease di prova, non accettazione completa su iPhone. Tempi di caricamento reali non misurati sul telefono/account. Installare sopra senza eliminare l'app;27.2 e precedenti immutate. Servizi/permessi/background da confermare e testi legali BOZZA restano aperti.
