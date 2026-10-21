# NOVA-ios

NOVA è la mia app per iPhone: una dashboard personale pensata per la scuola.

## Cosa fa

L'app apre a schermo intero una piccola web app locale (`nova.html`) con questi widget:

- **Meteo**: usa la posizione per mostrare il meteo locale
- **Batteria**: livello e stato di carica reali, letti dal telefono
- **Compiti e promemoria**: compiti con scadenza, priorità (alta/media/bassa) e promemoria (10 min prima, 1 ora prima, 1 giorno prima) con notifiche locali. I compiti possono arrivare **da soli da ClasseViva** oppure aggiunti a mano
- **Impostazioni**: nome, tema (auto/chiaro/scuro), widget da mostrare, attivazione notifiche, collegamento a ClasseViva

Il ponte nativo in Swift (`Sources/NOVA/NOVAApp.swift`) dà alla pagina web la batteria vera, le notifiche locali di iOS, tiene lo schermo acceso mentre il telefono è in carica e parla con ClasseViva. I dati dei compiti restano sul telefono (localStorage).

## Collegare ClasseViva

1. Apri NOVA e tocca l'ingranaggio (impostazioni)
2. Nella sezione **ClasseViva** scrivi codice utente e password del registro e tocca "Collega ClasseViva"
3. Se l'account ha più profili (per esempio un account famiglia con più studenti), scegli il tuo
4. I compiti del registro compaiono nel widget con il prefisso **CV** e si aggiornano da soli a ogni apertura dell'app e ogni 30 minuti; il pulsante "ClasseViva" nel widget forza l'aggiornamento

**Privacy**: codice utente e password vengono salvati solo nel Portachiavi di iOS sul telefono e usati unicamente per parlare con i server ufficiali di ClasseViva (web.spaggiari.eu). Non sono nel codice dell'app né in questo repository.

## Come è fatta

- SwiftUI + WKWebView, progetto SwiftPM (`Package.swift`), niente progetto Xcode
- Si compila con [xtool](https://github.com/xtool-org/xtool) (config in `xtool.yml`)
- ClasseViva: chiamate REST ufficiali (`/rest/v1/auth/login` + agenda compiti AGHW) fatte dal codice Swift nativo, credenziali nel Portachiavi iOS

## Build automatica (GitHub Actions)

Il workflow `.github/workflows/build-ipa.yml` compila l'app su un runner macOS a ogni push e produce un ipa **non firmato**:

- come artefatto `NOVA-unsigned-ipa` nella scheda Actions
- come allegato `NOVA.ipa` nella release

## Installazione (ipa non firmato)

L'ipa non è firmato, va firmato in fase di installazione:

1. Scarica `NOVA.ipa` dalla release
2. Installalo con [AltStore](https://altstore.io) o [Sideloadly](https://sideloadly.io) usando un Apple ID (basta quello gratuito)
3. Con l'Apple ID gratuito la firma dura 7 giorni: poi va rinnovata da AltStore/Sideloadly
