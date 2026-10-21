# NOVA-ios

NOVA è la mia app per iPhone: una dashboard personale pensata per la scuola.

## Cosa fa

L'app apre a schermo intero una piccola web app locale (`nova.html`) con questi widget:

- **Meteo**: usa la posizione per mostrare il meteo locale
- **Batteria**: livello e stato di carica reali, letti dal telefono
- **Compiti e promemoria**: aggiungi compiti con scadenza, priorità (alta/media/bassa) e promemoria (10 min prima, 1 ora prima, 1 giorno prima) con notifiche locali
- **Impostazioni**: nome, tema (auto/chiaro/scuro), widget da mostrare, attivazione notifiche

Il ponte nativo in Swift (`Sources/NOVA/NOVAApp.swift`) dà alla pagina web la batteria vera, le notifiche locali di iOS e tiene lo schermo acceso mentre il telefono è in carica. I dati dei compiti restano sul telefono (localStorage).

## Come è fatta

- SwiftUI + WKWebView, progetto SwiftPM (`Package.swift`), niente progetto Xcode
- Si compila con [xtool](https://github.com/xtool-org/xtool) (config in `xtool.yml`)

## Build automatica (GitHub Actions)

Il workflow `.github/workflows/build-ipa.yml` compila l'app su un runner macOS e produce un ipa **non firmato**:

- come artefatto `NOVA-unsigned-ipa` nella scheda Actions
- come allegato `NOVA.ipa` nella release

## Installazione (ipa non firmato)

L'ipa non è firmato, va firmato in fase di installazione:

1. Scarica `NOVA.ipa` dalla release
2. Installalo con [AltStore](https://altstore.io) o [Sideloadly](https://sideloadly.io) usando un Apple ID (basta quello gratuito)
3. Con l'Apple ID gratuito la firma dura 7 giorni: poi va rinnovata da AltStore/Sideloadly
