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
| 🟡 **In corso** | Impostazioni organizzate | Nuova pagina opaca a sezioni, interruttori nativi Apple e controlli glass. In verifica: nessuna modifica automatica alle scelte o ai permessi. |
| 🟡 **In corso** | Avvisi al centro | Messaggi di stato spostati al centro con vetro nativo, lontani dalla barra. Verifica visiva e su dispositivo in corso. |
| 🟡 **In corso** | Pulsanti glass in tutta l'app | Migrazione progressiva dei controlli, con verifiche schermata per schermata. Non ancora completa. |
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
