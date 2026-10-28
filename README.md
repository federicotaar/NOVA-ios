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

### Candidate reconciliation, October27 22:13 CET
- Group Info/settings and scanner medium-sheet full-bounds appearance reviewed; per-add choice and separate confirmation captured. History prompt is now being simplified to two cards with one-line explanations, preserving explicit scope and final confirmation. New gate40584816829 pending.
- Scanner gate40584826184 restores foreground launch after UI-driver installation and asserts scanner visibility before close testing. Physical camera remains unverified. Setup motion gate40584841143 corrects host readiness and captures forward/back motion; no accepted clip yet.
- Release notices now distinguish dismissible minor suggestions from persistent important notices via release body marker [NOVA_UPDATE:IMPORTANT], without app lockout. Gate40584923437 pending. Older notice implementations cannot gain this distinction retroactively.
- User accepts older unauthenticated builds needing update for protected photos/voice. Fresh worker matches deployed batched baseline exactly, fresh schema-only read found no new group/visibility tables and wrote zero rows. Re-ran68 group+12 media checks and68 group checks against combined auth-media candidate, all pass. Production deployment and capability activation still pending native acceptance; no memberships/history/clear actions used as live tests.

### Preview checks, October27 22:31 CET
- Group40584816829 and setup40584841143 passed native UI navigation. New history cards showed truncated explanation text in actual pixels, corrected wrapping and rerun40587246247. Original per-add final confirmation remains, test cancels without adding.
- Setup actual recorded frames show forward/back slide+fade and progress movement. Simulator recording timestamps are non-monotonic; review clip reconstructed in frame order at30fps, not evidence of exact device timing. Appearance awaits user review.
- Scanner40584826184 actual pixels show full-bounds medium sheet; test failed because overlay text absent from simulator accessibility. Rerun40587255882 uses actual screenshot then visible close coordinate/return check. Physical camera not verified.
- Release40584923437 actual minor notice readable, all7 selection checks true. Harness expected5 and failed, corrected rerun40587265421. Major persistence/dismissal mechanics still require full visual review.
- No production deployment or new IPA. User review remains required for cleaner history and setup motion; backend auth-media compatibility impact accepted but rollout held until technical gates and release readiness.

### Accepted technical gates, October27 22:46 CET
Clean history40587246247, scanner40587255882 and release40587265421 succeed. Actual history card descriptions fully wrap; explicit final Add confirmation follows selection. Scanner open/close actual pixels verify return to QR amici, six synthetic codes decode; physical camera feed still unverified. Setup40584841143 forward/back passes and actual slide/fade frames inspected. Cleaner popup/setup motion remain for user appearance review before packaging. Release major/minor selection7checks pass; adding persistence/no-dismissal and actual important notice coverage. Production unchanged; coordinated backend rollout waits for approved replacement release readiness, not just test completion.

## 2026.10.28.1 reviewed release preparation
User approved morning setup preview and requested IPA. Enable reviewed group and self-clear menus, exact Nova launcher, normal Latest release. Group creator admin, explicit owner configuration without silently assigning permissions, per-add full/new history cards and final confirmation. Private authenticated media rollout coordinates with inspected compatible replacement; old unauthenticated builds must update for photos/voice, accepted by owner. No actual membership/history/clear operations as tests. Passed native group40587246247, scanner40587255882, setup40584841143, release important/minor40589593157. Physical camera feed and actual device motion/playback remain unverified. Existing accounts/data preserved; no personal fixtures. Build/artifact/backend inspection pending, not complete yet.


## 2026.10.28.1 completed rollout

- Reviewed immutable normal Latest release built successfully in run40641156510 from adc16bcc9dacf48d12b09c9417704451ea6bafa6. Exact downloaded IPA2,020,682bytes, SHA25685b2c9bce55400a63cc5f5a74d216d96c7ad3f9c5099a7b3ec4be91089cea60c. Inspected Nova launcher, unchanged federicotaranu.site bundle,2801, NOVASwiftTestBuild true, actual arm64 Mach-O SDK26.5/minimum17.0, private-media loader and history labels.
- Only after compatible published replacement inspection, added four empty schema tables and deployed reviewed combined per-add group/self-clear/auth-media worker. Fresh exact source comparison and bindings/date/flags preservation verified. No account/profile/message/membership/history/clear mutations used as tests. Original media downloads/cache cannot be revoked; older unauthenticated loaders require update as accepted.
- Native reviewed preview/gates and combined68 group/12 media regressions pass. Physical camera feed, actual device animation/voice, Face ID/background and live-user history behavior are not claimed tested. Install over same app, do not delete app/data. This is unsigned TEST Swift, not final production app.


## Map support investigation October28 (not released)

- Private28.1 report: friend pins absent. No reporter/friend coordinates, location rows or settings inspected or changed. Source inspection reproduces missing native refresh after later friend activity, hidden collapsed-card feed errors, and overlapping refresh acceptance. Candidate refreshes only while map screen is active (60seconds, foreground/account keyed, manual refresh retained), validates feed success, rejects stale async results and shows separate own/friend timestamps/status. No background tracking/permissions or sharing defaults changed.
- Exact live backend source still28.1 SHA9bd99a11fc60347df1ce8d22d35e3ed337ae6d979ed9167cdb10f891cf55e00d. Accepted-friend/privacy opt-out/ghost/30minute freshness filters unchanged. Additional synthetic coverage finds /map lacks an explicit either-direction block filter (block route normally removes friendship); prepared defense-in-depth candidate restores it,10/10 synthetic checks vs8/10 baseline. No observed disclosure or live-account test. Backend candidate not deployed.
- Native functional/visual regression gate pending. No new IPA, version, backend deployment or mailbox reply. Private report screenshot is not in repository.

- Gate40662560155 native13 checks passed but actual pixels lacked feed/status: scenePhase environment in UIKit hosting did not represent foreground activation reliably. Candidate now uses UIApplication active/resign notifications scoped to map visibility, and gate explicitly asserts synthetic friend pin/status before screenshots. Not accepted on compile-only result.

- Chat URL support candidate: local NSDataDetector, underlined http/https links only with nonempty host/no credentials, native open on explicit tap, message text/selection preserved. No previews/background fetches, custom/file/javascript schemes blocked. Synthetic parser and intercepted-tap gate pending; no actual private shared URLs used.

- Chat gate40666201551 succeeds:8/8 safe-link/text checks, actual synthetic link tap routed to injected native open handler, keyboard/back preserved. Inspected real screenshot: underlined blue link within surrounding message text. No external page fetched.
- Map gate40666172849 visually shows synthetic pin + feed status/timestamp after UIApplication fix; gate assertion failed because map annotations are not exposed as standalone accessibility text. Update assertion to friend list row after expansion, keeping collapsed feed-status check; replacement gate pending. No new release/backend deployment.

- Final map gate40668355014 passes all13 checks and direct collapsed-status/expanded-friend-row UI assertions. Inspected actual screenshots: synthetic pin/list/status and geometry accepted, blank ocean tiles are not live map-service proof.
- Light composer readability candidate adds only a0.75pt12%-black outline in light appearance, no fill or glass material/geometry changes; dark is unchanged. Both appearance previews pending before packaging.

- New support reports28.1: admin confirmation moved into tapped member row with explicit cancel/confirm, no top-of-Form popover. Permission setup retains explicit choices/no automatic defaults; now shows missing choices beside disabled Save. Reproducing actual picker-to-save path with synthetic server before calling save issue fixed. No real promotion/settings changes.

- Live-location expansion candidate (not released/activated): new per-session foreground and separate background consent, CoreLocation liveUpdates with background activity indicator, Ghost/session/account cancellation,15s moving upload floor/15m movement or120s stationary heartbeat, fresh accuracy-checked fixes and explicit last-sent/error state. Old sharing/background flags cannot enable live. Existing60s friend-feed fix is not claimed continuous tracking. Free shared budget/physical device/battery/OS permission/lifecycle verification still block rollout; no paid upgrades or real coordinate testing.

- Voice draft overlap report: recording/draft controls moved to dedicated native material panel above composer using safeAreaInset, separate delete/stop/send circles, explicit recording/ready status and no sending until tap. Text entry disabled while recording/draft exists. No actual microphone/private voice used in tests; upload failure not established by still screenshot. Synthetic draft/recording previews pending.
