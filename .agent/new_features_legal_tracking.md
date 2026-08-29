# 📋 Tracking Nuove Implementazioni — Impatto Legale/Privacy
> Sessione: 14 Febbraio 2026
> Scopo: Aggiornamento Termini e Condizioni + Privacy Policy

---

## 1. SOS Smarrimento → Auto-creazione Annuncio Bacheca
- **Cosa**: Quando un utente lancia un SOS per pet smarrito, viene automaticamente creato un annuncio nella bacheca (categoria "Smarrito") oltre all'alert SOS sulla mappa.
- **Dati coinvolti**:
  - Nome del pet
  - Numero di telefono di contatto (inserito dall'utente)
  - Messaggio di smarrimento
  - Posizione GPS dell'utente al momento del lancio
- **Visibilità**: L'annuncio è pubblico nella bacheca e visibile a tutti gli utenti nelle vicinanze.
- **Impatto Privacy**: Il numero di telefono e la posizione approssimativa vengono condivisi pubblicamente. L'utente lo inserisce volontariamente nel form SOS.
- **File modificati**: `my_pets_screen.dart`

---

## 2. Notifiche Push per Annunci Bacheca (10 km)
- **Cosa**: Quando un utente pubblica un nuovo annuncio nella bacheca, viene inviata una notifica push a tutti gli utenti nel raggio di 10 km.
- **Dati coinvolti**:
  - Posizione GPS dell'utente (dalla collection `user_locations`)
  - Nome autore dell'annuncio
  - Anteprima del messaggio (primi 100 caratteri)
- **Logica proximity**: Haversine distance su `user_locations`, fallback su zona
- **Impatto Privacy**: La posizione dell'utente viene usata server-side per calcolare la prossimità. I dati di posizione NON vengono condivisi con altri utenti, solo usati per il targeting delle notifiche.
- **File modificati**: `functions/index.js` (Cloud Function `sendAnnouncementNotification`)

---

## 3. Notifiche Push per Offerte Business (10 km)
- **Cosa**: Quando un utente business pubblica una nuova offerta/promozione, viene inviata una notifica push a tutti gli utenti nel raggio di 10 km dalla posizione del business.
- **Dati coinvolti**:
  - Posizione GPS del business owner (dalla collection `user_locations`)
  - Titolo offerta, nome business, percentuale sconto
- **Logica proximity**: Haversine distance su `user_locations`, fallback su zona
- **Impatto Privacy**: Stessa logica degli annunci — posizione usata server-side per targeting, non condivisa.
- **Notifica esempio**: "🏷️ -20% da PetShop Roma!" → "Crocchette Premium 2x1"
- **File modificati**: `functions/index.js` (Cloud Function `sendOfferNotification`)

---

## 4. Badge e Banner In-App per Nuove Offerte
- **Cosa**: Badge numerico sul tab "Offerte" e banner "Nuove offerte vicino a te!" nella lista offerte per offerte create nelle ultime 24 ore.
- **Dati coinvolti**: Timestamp di creazione dell'offerta (campo `createdAt`)
- **Impatto Privacy**: Nessun dato personale aggiuntivo — usa solo il timestamp pubblico delle offerte.
- **File modificati**: `nextdoor_screen.dart`, `offers_screen.dart`

---

## 5. Provider `dogByIdProvider`
- **Cosa**: Nuovo provider Riverpod per recuperare i dati di un singolo pet tramite ID Firestore.
- **Dati coinvolti**: Dati del pet (nome, foto, razza, etc.)
- **Impatto Privacy**: Nessun impatto aggiuntivo — accede a dati già esistenti nella collection `dogs`.
- **File modificati**: `dog_provider.dart`

---

## Riepilogo Impatti Chiave per T&C / Privacy Policy

### Dati Posizione (GPS)
- [x] Posizione utente usata per calcolo prossimità notifiche (10 km per annunci/offerte, 1 km per SOS, 2 km per safety alerts)
- [x] Collection `user_locations` usata server-side nelle Cloud Functions
- [x] Posizione NON condivisa con altri utenti, solo usata per targeting

### Notifiche Push
- [x] Nuove categorie di notifica: annunci bacheca, offerte business
- [x] Notifiche basate sulla prossimità geografica
- [x] L'utente riceve notifiche push per contenuti commerciali (offerte business)

### Dati Personali Condivisi
- [x] Numero di telefono condiviso pubblicamente negli annunci SOS (inserito volontariamente dall'utente)
- [x] Nome utente e anteprima messaggio nelle notifiche push degli annunci

### Contenuti Commerciali
- [x] Offerte business con codici sconto e link esterni
- [x] Notifiche push per promozioni commerciali basate sulla posizione

---

## 6. Moderazione Automatica con AI (già implementato, pre-sessione)
- **Cosa**: Tutti i contenuti generati dagli utenti vengono analizzati automaticamente da sistemi di intelligenza artificiale per rilevare contenuti inappropriati.
- **Tecnologie AI usate**:
  - **Google Cloud Vision SafeSearch**: analisi immagini per contenuti adulti, violenti, offensivi
  - **Google Gemini (Vertex AI)**: analisi testuale per hate speech, molestie, spam, profanità, maltrattamento animali
- **Contenuti moderati (6 trigger)**:
  1. **Post social** (`social_posts`) — testo + immagini
  2. **Commenti ai post** (`social_posts/{id}/comments`) — testo
  3. **Annunci bacheca** (`announcements`) — testo + immagini
  4. **Messaggi chat** (`chats/{id}/messages`) — testo
  5. **Profili utente** (`users`) — bio, nome, foto profilo, immagine copertina
  6. **Auto-ban** — sospensione automatica dopo 5 violazioni
- **Azioni automatiche**:
  - `approved`: contenuto pubblicato normalmente
  - `flagged`: contenuto pubblicato ma registrato per revisione
  - `blocked`: contenuto rimosso/cancellato automaticamente
  - Notifica in-app all'utente quando un contenuto viene rimosso
  - Contatore violazioni (`moderationViolations`) incrementato per ogni blocco
  - Avviso a 3 violazioni, sospensione account a 5 violazioni
- **Dati conservati**:
  - Collection `moderation_log`: tipo contenuto, ID, collection, userId, azione, motivo, dettagli, timestamp
  - Per messaggi chat bloccati: il testo originale viene conservato nel campo `originalText` per revisione admin
- **Impatto Privacy/GDPR**:
  - [x] Tutti i contenuti UGC vengono processati da servizi AI di terze parti (Google Cloud)
  - [x] I contenuti testuali vengono inviati a Gemini (Vertex AI) per analisi
  - [x] Le immagini vengono inviate a Cloud Vision API per analisi SafeSearch
  - [x] I risultati della moderazione vengono archiviati nella collection `moderation_log`
  - [x] Il testo originale dei messaggi chat bloccati viene conservato per revisione admin
  - [x] Sistema di sospensione automatica dell'account (decisione automatizzata con impatto significativo sull'utente — rilevante per GDPR Art. 22)
- **File**: `functions/moderation.js`

---

## 7. Riscatto Esercizi Commerciali (Business Claim)
- **Cosa**: Un utente può riscattare la proprietà di un esercizio commerciale presente sulla mappa (da Google Places). Il processo prevede un form multi-step con verifica della proprietà, revisione manuale da parte del team admin, e richiede un abbonamento "Business Pro" attivo.
- **Dati personali raccolti**:
  - Nome e cognome del titolare/responsabile
  - Ruolo (Titolare, Direttore, Responsabile)
  - Numero di telefono di contatto
  - Email aziendale
  - Partita IVA (P.IVA)
  - Foto di verifica (insegna, Visura Camerale, documento di proprietà)
  - Note aggiuntive (opzionale)
- **Collection Firestore**: `business_claims`
  - Stato: `pending` → `approved` / `rejected`
  - `reviewedAt`, `reviewedBy`, `rejectionReason`
- **Flusso**:
  1. L'utente compila il form a 3 step (Dati → Verifica → Riepilogo)
  2. Viene verificato se ha l'abbonamento Business Pro (RevenueCat)
  3. Se non lo ha, viene reindirizzato al paywall prima di procedere
  4. La richiesta viene salvata in `business_claims` con stato `pending`
  5. L'admin approva/rifiuta dalla dashboard admin (`business_claims_widget.dart`)
  6. Cloud Function `onBusinessClaimUpdate` notifica l'utente del risultato
  7. Se approvato: il business viene assegnato all'utente, il suo `accountType` diventa `business`
- **Dati conservati**:
  - La foto di verifica viene caricata su Firebase Storage in `claims/{userId}_{timestamp}`
  - I dati della claim restano in Firestore anche dopo approvazione/rifiuto
- **Impatto Privacy/GDPR**:
  - [x] Raccolta di dati personali sensibili (P.IVA, email aziendale, documento fotografico)
  - [x] I dati vengono conservati indefinitamente nella collection `business_claims`
  - [x] Revisione manuale dei dati da parte del team admin
  - [x] Abbonamento in-app gestito tramite RevenueCat (servizio di terze parti)
  - [x] Google Places ID associato al profilo business dell'utente
  - [x] Decisione sulla richiesta comunicata tramite notifica in-app
- **File**: `claim_business_screen.dart`, `pet_business_service.dart`, `business_claims_widget.dart`, `functions/index.js`

---

> ✅ **Aggiornamento completato — 14 Febbraio 2026**
> 
> Tutti i documenti legali sono stati aggiornati alla versione 1.2:
> - [x] **Geolocalizzazione GPS** — tracking foreground/background, radar utenti, passeggiata tracciata, prossimità notifiche
> - [x] **Google Ads (AdMob)** — tracking terze parti, device identifier, pubblicità personalizzata
> - [x] **Abbonamenti (RevenueCat)** — piani, rinnovo automatico, cancellazione, rimborsi
> - [x] **Autenticazione (Google/Apple Sign-In, Firebase Auth)** — dati ricevuti dal provider, uso email/nome/foto
> - [x] **Chat privata** — messaggi tra utenti, analizzati da AI moderazione
> - [x] **Social feed** — post, commenti, like, UGC, licenza contenuti, visibilità
> - [x] **FCM Token / Notifiche Push** — identificatore dispositivo, categorie di notifica
> - [x] **Moderazione AI** — Cloud Vision SafeSearch + Gemini, Art. 22 GDPR
> - [x] **Business Claim** — P.IVA, documenti verifica, revisione manuale
> - [x] **Notifiche di prossimità** — annunci, offerte, SOS
> - [x] **SOS auto-annuncio** — condivisione pubblica telefono e posizione

