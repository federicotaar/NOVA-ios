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
- Campo con Liquid Glass nativo su iOS26 e materiale di sistema sulle versioni precedenti. Variante con tinta chiara mostrata in anteprima e confezionata su richiesta in TEST27.4 per valutazione sul dispositivo; non ancora accettata su iPhone.
- Anteprime effettive dei percorsi Chat > Assistente e Chat > Gruppo con dati sintetici: invio libero da sovrapposizioni, chiusura tastiera in alto e screenshot dopo l'animazione. [Gruppo](https://github.com/federicotaranudev/NOVA-ios/actions/runs/40553852137), [Assistente](https://github.com/federicotaranudev/NOVA-ios/actions/runs/40553977657).
- Avviso generico dentro NOVA solo mentre l'app è attiva, controllo ogni10secondi: prima lettura silenziosa, niente doppioni, propri messaggi o messaggi già letti; risultati di sessioni precedenti scartati. [Sette controlli e schermata integrata](https://github.com/federicotaranudev/NOVA-ios/actions/runs/40553875074). Non è APNs né una notifica di sistema a app chiusa. Nessun servizio a pagamento o app aggiuntiva introdotti.
- Restano da verificare ricezione e uso sul dispositivo con servizi reali. Le schermate sintetiche non dimostrano velocità o consegna reali. Il TEST27.3 pubblicato resta invariato. TEST27.4 verificato: bundle federicotaranu.site, build2704, SDK26.5 nel binario, widget presente e nessun archivio personale o fixture nel pacchetto. [Download esatto27.4](https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.27.4/NOVA-2026.10.27.4.ipa). SHA256: `ec741e6d97d86a61877ae52b7442a53a32e15cb1f12ffa0598edc8b93a4c241d`. Installare sopra la stessa app senza disinstallare.

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



## Candidate after 2026.10.27.4 TEST, not yet packaged
- Compact assistant/social composer keeps 44pt minimum, 22pt corners and four-line draft cap. Clear native glass replaces the isolating tray; real synthetic-photo pixels show transparency and text-shadow readability. Lens-like corner refraction remains under review, not user-approved. Native glass controls now share a GlassEffectContainer sampling region. iOS before26 uses a material fallback, not native Liquid Glass.
- QR camera sheet is medium-height with visible close action. Simulator pixels confirm height; real camera access is unavailable there. Foreground close acceptance remains in progress.
- Voice playback downloads validated same-origin media with Bearer session, ephemeral cache policy, MIME/status checks and streaming decoded-byte cap1,050,000, then activates AVAudioSession and AVAudioPlayer. Native synthetic WAV start/stop/error/cancel checks passed. Account-transition fixture corrected to use the real reviewed account transaction rather than a rejected ordinary update; rerun pending. No claim that the former playback mechanism was the proven root cause.
- Authenticated private-image client added with retry/error state. Server media authentication is NOT rolled out: compatibility and authorization hardening remain open.
- Self-clear client exists but is disabled behind a false server-capability gate until backend rollout. Group settings and backend changes are not deployed. Exact live D1 schema read27October confirmed chat_members composite PK and messages(chat_id,id) index, with zero rows written. No private chat/media rows retrieved.
- 27.4 remains immutable. No new IPA or version until preview review and remaining acceptance checks. No private screenshots or messages committed.

### Candidate acceptance update, October27 20:29 CET
- Native voice gate40564743545 passes all five synthetic checks: AVAudioPlayer starts WAV, stop clears, failure is visible, cancelled load rejected, real reviewed account transition rejects old-session bytes. This does not verify an actual user voice note/device and injected loader tests do not test the HTTP transport.
- Assistant gate40564753018 and social40565355886 pass native keyboard/return interaction. Actual assistant pixels show underlying text refraction near rounded edge. Social fine-detail and clear attachment-circle verification remain pending, not user-approved.
- Scanner40565442287 actual before/after pixels verify medium sheet opens and foreground Chiudi returns to QR amici. Six rendered synthetic QR cases decode. Simulator camera unavailable; real device camera not verified.
- New attachment circle now matches clear native field material. Neutral-underlay diagnostic changes synthetic fixture only, leaving production message bubbles unchanged. Generator quote error blocked latest diagnostic runs before app compile; corrected with Python syntax validation. Replacement gates social40569520607 and neutral assistant40569530442 underway. No IPA or backend rollout.

### Native lens diagnostic outcomes, October27 20:44 CET
- Social40569520607 and neutral assistant diagnostic40569530442 succeeded. Actual fine-grid/text pixels show separate clear + lens magnification and field edge displacement. Both surfaces use native clear interactive glass and shared sampling; no custom lens imitation.
- Neutral assistant diagnostic changes ONLY synthetic blue bubble background to gray: field becomes gray while text refraction remains. This confirms backdrop-dependent color rather than fixed composer blue tint. Production assistant bubble styling is unchanged and can still impart blue while under glass. Neutral message styling has not been selected.
- Preview review remains open. No IPA/version/backend rollout. Standard assistant workflow restored to production bubble styling after this diagnostic; optional synthetic diagnostic flag retained for reproducibility.

## 2026.10.27.5 TEST release
- Reviewed native clear lens composer and separate +, compact44pt/22pt/four-line shape, readable draft shadow. Existing production assistant blue bubbles preserved; clear glass samples backdrop color. Neutral-bubble diagnostic was not a selected styling change.
- Native downloaded voice playback and visible retry/error handling; synthetic native5checks pass. Actual device voice-note playback remains for user acceptance. Half-height QR scanner and close-return verified in simulator; real camera not available there, synthetic QRdecode6checks pass.
- Gates: social40569520607, voice40564743545, scanner40565442287; assistant production keyboard40564753018 and neutral diagnostic40569530442. No private screenshots/data embedded.
- Self-clear hidden behind false capability guard. Group policy/media server authorization changes remain private and undeployed, no migration/data/account changes. Legal documents remain BOZZA. Free unsigned TEST IPA, existing free sideload/signing route, no paid signing or closed-app push claim.

### 27.5 exact artifact inspection, October27 21:17 CET
Build40574951246 succeeded. Exact published NOVA-2026.10.27.5.ipa is1,894,761bytes, SHA25686d579d24565c30637424042e6341e38dcddf39af7d6e6ed16ad794ebfb953dc. Actual arm64 Mach-O SDK26.5/min17, Info TESTtrue/build2705/label2026.10.27.5/bundlefedericotaranu.site; widget present, no fixture/account/cache/screenshot archive entries.27.4 preserved. This is an unsigned TEST package using the existing free sideload route, not AppStore distribution or physical-device acceptance.
- Release: https://github.com/federicotaranudev/NOVA-ios/releases/tag/v2026.10.27.5
- IPA: https://github.com/federicotaranudev/NOVA-ios/releases/download/v2026.10.27.5/NOVA-2026.10.27.5.ipa

## Candidate after27.5: scanner geometry and group menus
- Physical report scanner preview only in black child below header: camera view now spans medium sheet behind overlaid native-glass controls and bottom safe area. Capture setup/start/stop moved to serial background queue, runtime/interruption/running status observed. Actual device feed not yet verified. Synthetic geometry preview explicitly labeled NOT CAMERA, never proof of working camera.
- Group native title > Info > Impostazioni menus prepared, large header/member list/reference-inspired grouped settings. Invite/join and fake call/video actions excluded. Creator owner is administrator. Configurable add/send/edit rules + approval, explicit per-add whole/new history choice then Add confirmation, choice visible to approver. Server capability remains disabled pending safe rollout.
- Backend per-add candidate68 exact-schema group +12 media tests pass privately. No migration/actual member/history change. Complete attachment-history enforcement requires separate compatible server media-auth rollout, not silently enabled.
- Next launcher display name Nova, bundle unchanged. Next approved release workflow uses normal Latest rather than prerelease while keeping test/device caveats.27.5 package/assets unchanged.
- Current compile/geometry gates scanner40580173757 and group40580164384 pending. Prior scanner compiled but UI driver failed launch; prior group test path corrected before rerun. No new version/package yet.

### Active candidate preview follow-through, October27 21:58 CET
Group Info and settings actual simulator pixels inspected and appearance approved; scanner synthetic geometry reaches full medium-sheet bounds behind header and to corners, appearance approved but physical feed unverified. Navigation acceptance found test selectors failing native BackButton/scanner close; corrected tests pending. Separate per-add Add confirmation/restricted-history refusal added. No backend rollout or new IPA. New-user setup now prepares directional spring/fade transitions with animated progress and Reduce Motion fade fallback; existing setup controls, data writes, permissions and completed-user skip condition unchanged. Motion clip inspection pending.
