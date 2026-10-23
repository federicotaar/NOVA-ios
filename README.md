<p align="center">
  <img src="assets/1-icon1024.png" width="120" alt="Icona di NOVA">
</p>

<h1 align="center">NOVA</h1>

<p align="center">
  La dashboard personale per la scuola: compiti, verifiche, voti, orario e widget, con un assistente AI che organizza lo studio al posto tuo.<br>
  Native iOS, dati sul telefono, nessun account obbligatorio.
</p>

<p align="center">
  <a href="https://github.com/federicotaranudev/NOVA-ios/actions/workflows/build-ipa.yml"><img src="https://github.com/federicotaranudev/NOVA-ios/actions/workflows/build-ipa.yml/badge.svg" alt="Build"></a>
  <a href="https://github.com/federicotaranudev/NOVA-ios/releases/latest"><img src="https://img.shields.io/github/v/release/federicotaranudev/NOVA-ios?label=ultima%20versione" alt="Ultima release"></a>
  <img src="https://img.shields.io/badge/piattaforma-iOS%2016%2B-black" alt="iOS 16+">
</p>

---

## Cos'è NOVA

NOVA è un'app per iPhone pensata per la vita scolastica di tutti i giorni. Al centro c'è una dashboard chiara e veloce; intorno, un ponte nativo in Swift che la collega alle funzioni vere di iOS: notifiche locali, aggiornamenti in background, Portachiavi e widget.

L'idea di base: il registro elettronico resta la fonte dei dati, NOVA li rende utili. Compiti e verifiche arrivano da ClasseViva, l'assistente AI li legge e programma i promemoria al momento giusto, e i widget tengono orario e scadenze sempre sott'occhio.

## Funzionalità

### Studio e compiti

- **Compiti e verifiche da ClasseViva**: import automatico di compiti, verifiche e annotazioni dei prof dalle API ufficiali, con aggiornamento manuale dal pulsante "Aggiorna" e periodico a ogni apertura dell'app
- **Compiti manuali**: si possono aggiungere a mano, con priorità (alta/media/bassa) e promemoria singoli
- **Calendario in app** con il dettaglio del giorno e dei compiti, visibile anche in StandBy
- **Voti**: medie per materia e il voto che serve per arrivare al 6
- **Prossima verifica** con conto alla rovescia

### Assistente AI e promemoria intelligenti

- **Pianificazione automatica dei promemoria**: a ogni aggiornamento di ClasseViva, l'assistente legge compiti e verifiche, decide gli orari migliori (mattina presto per le cose del giorno, sera prima per quelle di domani, preavviso per le verifiche) e programma le notifiche locali, che suonano anche ad app chiusa
- **Senza chiave AI**, NOVA usa orari automatici di riserva con la stessa logica di base
- **Avviso per i compiti nuovi**: quando iOS concede un aggiornamento in background e compaiono novità dal registro, arriva una notifica subito
- **Chat dell'assistente** per aiuto su compiti, verifiche e studio (Groq, con la tua chiave gratuita)
- **Foto dell'orario**: l'assistente la legge e compila l'orario settimanale, poi lo controlli tu

### Widget

Quattro widget, su home screen e (dove indicato) lock screen:

| Widget | Cosa mostra | Dove |
| --- | --- | --- |
| **Prossima materia** | Lezione in corso o successiva, con barra di avanzamento e aula | Home + lock screen |
| **Lezioni di oggi** | L'orario del giorno con orari e aule | Home + lock screen |
| **Fine scuola** | Quanto manca all'ultima campanella | Home + lock screen |
| **Calendario del mese** | Il mese con pallino rosso sulle verifiche e blu sui compiti | Home screen |

L'orario settimanale è modificabile nell'app, con un campo **aula** per ogni lezione: i widget seguono le modifiche e mostrano dove andare. La sincronizzazione app → widget richiede che l'App Group sia accessibile: con la firma gratuita può non esserlo (vedi **Limiti noti**), e in quel caso i widget usano l'orario incorporato senza le tue modifiche.

### E in più

- **Meteo** locale e **batteria** reale del telefono
- **Spotify** miniplayer (richiede Premium e un tuo Client ID)
- **Account NOVA** opzionale: salva la configurazione online per ritrovarla dopo una reinstallazione
- Tema chiaro/scuro/automatico, intro solo al primo avvio, animazione di benvenuto alla registrazione

## Privacy

- Password di ClasseViva, chiave Groq e token Spotify restano **solo nel Portachiavi di iOS sul telefono** e vengono usati unicamente verso i servizi ufficiali (ClasseViva, api.groq.com, Spotify). Non sono nel codice né in questo repository
- Compiti, voti e impostazioni vivono nella memoria locale dell'app
- L'account NOVA è facoltativo: online finisce solo la configurazione, mai le credenziali dei servizi

## Installazione

L'app è distribuita come ipa **non firmato**; la firma avviene in fase di installazione:

1. Scarica sempre l'ultima versione da qui: [NOVA.ipa](https://github.com/federicotaranudev/NOVA-ios/releases/latest/download/NOVA.ipa)
2. Installala con [AltStore](https://altstore.io) o [Sideloadly](https://sideloadly.io) (basta un Apple ID gratuito)
3. Aggiorna **sopra** l'installazione esistente, senza cancellare l'app: così impostazioni e accessi restano

Con un Apple ID gratuito la firma dura 7 giorni e va rinnovata da AltStore/Sideloadly. Ogni versione resta disponibile nella sua release, così si può sempre tornare indietro.

## Limiti noti

- **Le notifiche sui compiti nuovi non sono istantanee**: iOS decide quando concedere gli aggiornamenti in background (in base a uso, batteria e risparmio energetico). I promemoria programmati, invece, sono notifiche locali e suonano puntuali anche ad app chiusa
- **Sincronizzazione app → widget**: con la firma gratuita, la condivisione dell'orario con i widget (App Group) può non essere disponibile su alcune installazioni. In quel caso i widget dell'orario usano un orario incorporato come riserva, ma le modifiche fatte nell'app (comprese le aule) e il calendario del mese non possono arrivare ai widget; l'app segnala quando succede
- La pianificazione AI dei promemoria richiede una chiave Groq gratuita e avviene quando l'app aggiorna ClasseViva; senza chiave valgono gli orari automatici di riserva

## Struttura del progetto

```
Sources/NOVA/NOVAApp.swift      Ponte nativo: WebView, notifiche, ClasseViva, Groq, Spotify, Portachiavi
Sources/NOVA/nova.html          La web app locale (dashboard, impostazioni, assistente)
Sources/NOVAWidget/             Estensione widget (home screen e lock screen)
.github/workflows/build-ipa.yml Build automatica dell'ipa a ogni push
xtool.yml, Package.swift        Progetto SwiftPM compilato con xtool, senza Xcode
```

## Build

A ogni push, GitHub Actions compila l'ipa non firmato con [xtool](https://github.com/xtool-org/xtool) e lo pubblica in una release dedicata alla versione (`v<aaaa.mm.gg.n>`), senza mai sovrascrivere le versioni già pubblicate. Il link stabile qui sopra punta sempre all'ultima.
