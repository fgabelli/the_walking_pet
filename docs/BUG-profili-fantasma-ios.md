# BUG CRITICO — Utenti iOS bloccati fuori dall'app da documenti "fantasma"

Progetto Firebase: `thewalkingpet-a1578` (app DOGZN)
Diagnosi completata il 2026-09-01. Root cause identificata e confermata sui dati di produzione.
Il fix NON è ancora stato implementato: è il contenuto di questo documento.

---

## 1. TL;DR

Dal 14 luglio 2026, un utente iOS che si registra viene **bloccato permanentemente su una
schermata di errore** e non raggiunge mai la creazione del profilo.

Ad agosto 2026 ne sono stati colpiti **42 su 46 nuovi iscritti (91%)**. In totale **59 utenti**
hanno un account Firebase Auth valido ma nessun profilo, e a ogni riapertura dell'app rivedono
lo stesso errore. Non è un abbandono volontario: è un blocco tecnico e permanente.

La causa è una **race condition**: il salvataggio del token push crea il documento
`users/{uid}` *prima* che l'utente compili il profilo. Da quel momento il documento "esiste
ma è vuoto", e il parsing del modello va in crash su un campo null.

---

## 2. Evidenze raccolte (dati reali di produzione)

Verificate via REST API su Firestore e Identity Toolkit:

| Metrica | Valore |
|---|---|
| Account su Firebase Auth | 166 |
| Documenti nella collection `users` | 167 |
| Documenti con profilo vero (campo `createdAt` presente) | **108** |
| Documenti FANTASMA (nessun `createdAt`) | **59** |
| Account Auth senza alcun documento ("orfani") | 0 |

I 59 documenti fantasma contengono **esclusivamente** questi campi, nient'altro:

```
fcmTokens, apnsTokenPrefix, apnsTokenLength,
tokenPlatform, tokenStatus, tokenUpdatedAt
```

Nessun `firstName`, `email`, `createdAt`, `updatedAt`. Sono scritti solo dal registratore di
token push. In tutti e 59 `updateTime == createTime`: creati e mai più toccati.

**Tutti e 59 hanno `tokenPlatform: "ios"`. Nessun Android.**
I provider di login sono misti (23 google.com, 17 apple.com, 18 password, 1 apple+google):
quindi il problema NON dipende dal metodo di autenticazione, ma dalla piattaforma.

Distribuzione temporale (per mese di creazione del documento):

```
2026-05:  42 nuovi,   0 bloccati
2026-06:   8 nuovi,   0 bloccati
2026-07:  56 nuovi,  17 bloccati   <- primo caso: 14 luglio 2026
2026-08:  46 nuovi,  42 bloccati   <- 91%
```

### 2.1 Perché nessuno se n'era accorto

La dashboard admin interroga la collection con `orderBy('createdAt')`
(`lib/features/admin/presentation/widgets/users_table_widget.dart:58` e `:74`).
**Firestore esclude silenziosamente dai risultati i documenti privi del campo usato in
`orderBy`.** Quindi il pannello mostra 108 utenti e i 59 rotti sono invisibili.

Anche lo script `functions/cleanup_orphan_auth_users.js` dà falso "tutto pulito": verifica solo
*se il documento esiste*, e il documento fantasma esiste. **Non usarlo come validazione del fix,
e soprattutto non eseguirlo senza `--dry-run`**: la sua logica attuale considera "utente reale"
chiunque abbia un documento, quindi non cancellerebbe i fantasma, ma resta uno strumento che
elimina account Auth e va trattato con prudenza.

---

## 3. Catena causale (confermata leggendo il codice)

1. L'utente completa la registrazione → Firebase Auth crea l'account.

2. `NotificationService` ha un listener sui cambi di stato auth:
   `lib/core/services/notification_service.dart:151-156`
   ```dart
   _auth.authStateChanges().listen((User? user) {
     if (user != null) {
       updateToken();   // parte SUBITO alla registrazione
     }
   });
   ```

3. `updateToken()` / `_saveTokenToDatabase()` scrivono su `users/{uid}` con
   `set(..., SetOptions(merge: true))` → **il documento viene CREATO**, contenente solo i token:
   `lib/core/services/notification_service.dart:431-441`
   ```dart
   await _firestore.collection('users').doc(userId).set({
     'fcmTokens': FieldValue.arrayUnion([token]),
   }, SetOptions(merge: true));
   ```
   Il commento nel codice dichiara l'intenzione ("so it works even for newly registered users
   whose Firestore document doesn't exist yet"): è proprio questa scelta a innescare il bug.

4. All'avvio, il routing legge il profilo con:
   `lib/core/services/user_service.dart:23-29`
   ```dart
   .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
   ```
   `doc.exists` è **true** (il documento fantasma c'è) → tenta il parsing.

5. Il parsing esplode:
   `lib/shared/models/user_model.dart:116-117`
   ```dart
   createdAt: (data['createdAt'] as Timestamp).toDate(),   // data['createdAt'] è null
   updatedAt: (data['updatedAt'] as Timestamp).toDate(),
   ```
   → `TypeError: null is not a subtype of type 'Timestamp'` → lo stream emette errore.

6. Il routing mostra la schermata di errore invece della creazione profilo:
   `lib/app.dart:69-87`
   ```dart
   return profileAsync.when(
     data: (profile) {
       if (profile != null) { ...MainScreen... }
       else { return const CreateProfileScreen(); }   // riga 82: MAI RAGGIUNTA
     },
     loading: () => const SplashScreen(),
     error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),  // riga 86: QUI
   );
   ```

7. Il documento fantasma resta in Firestore per sempre → **a ogni riapertura si ripete il
   passo 4-6**. Blocco permanente, l'utente non può recuperare in alcun modo.

---

## 4. TUTTI i punti che creano il documento fantasma

Vanno corretti tutti, non solo il primo. File
`lib/core/services/notification_service.dart`, ogni occorrenza usa `set(merge:true)` su
`users/{uid}`:

| Riga | Cosa scrive |
|---|---|
| ~39-43 | `fcmTokens: []`, `tokenStatus: 'migrating'` (dentro `_migrateTokenIfNeeded`) |
| ~377-380 | `tokenStatus: 'apns_unavailable'` |
| ~403-407 | blocco `diagnostics` con `tokenStatus: 'success'`, `tokenPlatform`, `apnsToken*` |
| ~411-414 | `tokenStatus: 'null_token'` |
| ~421-424 | `tokenStatus: 'error: ...'` |
| ~437-440 | `fcmTokens: arrayUnion([token])` (dentro `_saveTokenToDatabase`) |

Nota: `_migrateTokenIfNeeded` è una migrazione one-shot che gira all'avvio; è un forte
sospetto come innesco della regressione datata 14 luglio, ma la datazione non è dimostrata
(la cronologia git è a grana grossa: tutto è confluito nel commit `8d9e89e` del 29/08).

---

## 5. Fix richiesti

### Fix 1 — Rendere il parsing a prova di campo mancante (elimina il crash)
`lib/shared/models/user_model.dart:116-117`
Gestire `createdAt` e `updatedAt` null senza lanciare eccezioni. Attenzione: sono dichiarati
non-nullable nel modello, quindi serve un fallback coerente (es. `DateTime.now()` oppure
`doc.createTime`) OPPURE rendere nullable il campo — valutare l'impatto su tutti i chiamanti
(`user_model.dart:265-266` in `copyWith`, e la dashboard admin che legge
`data['createdAt'] as Timestamp?` in `users_table_widget.dart:852` e `:1036`, dove il cast è già
nullable e quindi non va rotto).

### Fix 2 — Trattare il documento fantasma come "profilo assente"
`lib/core/services/user_service.dart:28`
Il criterio `doc.exists` non basta. Un documento è un profilo valido solo se contiene i campi
del profilo. Condizione suggerita: documento esistente **e** `data['createdAt'] != null`.
Altrimenti restituire `null`, così `app.dart:82` instrada correttamente a `CreateProfileScreen`.

Questo è il fix che **sblocca i 59 utenti esistenti** senza toccare i loro dati.

### Fix 3 — Non far creare il documento utente al salvataggio del token (root cause)
`lib/core/services/notification_service.dart`, tutti i punti della tabella al §4.
I token push non devono mai dar vita al documento profilo. Opzioni, in ordine di preferenza:

- **(a)** Scrivere i token solo se il profilo esiste già (guard su lettura, oppure `update()`
  in try/catch invece di `set(merge:true)`: `update()` fallisce se il doc non esiste, che è
  esattamente il comportamento voluto).
- **(b)** Spostare token e diagnostica in una collection/sottocollection separata
  (es. `users/{uid}/devices/{deviceId}`), disaccoppiandoli dal profilo.

Se si sceglie (a), verificare che il token venga comunque salvato **dopo** che l'utente ha
completato il profilo (ri-tentare al termine di `CreateProfileScreen`), altrimenti si rompono
le notifiche push per i nuovi iscritti.

Attenzione a `UserService.createUser` (`user_service.dart:32-37`): usa `.set(user.toFirestore())`
**senza merge**, quindi sovrascrive l'intero documento alla creazione del profilo. Poiché
`toFirestore()` include `fcmTokens` (`user_model.dart:173`) il token sopravvive, ma i campi
diagnostici vengono cancellati. Non introdurre regressioni qui.

### Fix 4 — Rendere visibile il problema nella dashboard admin
`lib/features/admin/presentation/widgets/users_table_widget.dart:58` e `:74`
L'`orderBy('createdAt')` nasconde i documenti malformati. Serve un conteggio che includa
*tutti* i documenti della collection e segnali quelli senza profilo, altrimenti un'eventuale
regressione futura resterà di nuovo invisibile per mesi.

---

## 6. Criteri di verifica (obbligatori prima di dichiarare chiuso)

1. Simulare in test un `DocumentSnapshot` contenente **solo** i campi token del §2:
   `getUserStream` deve emettere `null` e **non** un errore.
2. Con quel documento in Firestore, l'app deve mostrare `CreateProfileScreen`, non
   `Scaffold(... Text('Error: ...'))`.
3. Registrazione end-to-end su **device iOS reale** (non simulatore: serve APNs):
   al termine il documento `users/{uid}` deve contenere `createdAt`, `email`, `firstName`.
4. Dopo il completamento del profilo, le notifiche push devono continuare ad arrivare
   (regressione da non introdurre con il Fix 3).
5. Riaprire l'app con un profilo già completo: nessun cambiamento di comportamento.

---

## 7. Piano di recupero dei 59 utenti — NON eseguirlo da qui

Questa parte è operativa su dati di produzione e va fatta **dopo** che la build corretta è
pubblicata sull'App Store. Non fa parte del lavoro di codice. Ordine corretto:

1. Deploy del fix + release iOS approvata.
2. Bonifica dei 59 documenti fantasma in Firestore.
3. Notifica push di richiamo ai 59 (i loro `fcmTokens` sono ancora validi: sono raggiungibili,
   ma solo se prima si cancellano i token si perde l'unico canale di contatto — quindi
   **mandare la push prima di qualsiasi cancellazione**).

Invertire questo ordine significa far riaprire l'app a utenti che sbatteranno di nuovo
sulla stessa schermata di errore.

---

## 8. Vincoli di progetto

- Infrastruttura **interamente Firebase**. Non proporre né introdurre Cloud Run esterni,
  Vercel, Cloudflare o simili.
- Progetto Firebase: `thewalkingpet-a1578`. Le credenziali sono sull'account `sviluppo@revan.it`.
- Le `firestore.rules` attuali sono permissive ("Authenticated users: allow everything"):
  il bug **non** è un problema di regole, e non serve modificarle per risolverlo.
- Non modificare la logica di business del profilo oltre a quanto elencato al §5.
