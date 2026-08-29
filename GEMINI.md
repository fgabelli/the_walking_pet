# Istruzioni Operative Progetto: The Walking Pet (DOGZN)

## Repository e Hosting
- **Codice sorgente**: GitHub (Privato) -> `https://github.com/fgabelli/the_walking_pet`
- **Ambiente di produzione**: Firebase Project `thewalkingpet-a1578` (DOGZN)
- **App Store / Google Play**: `com.thewalkingpet.app`
- **Web App / Landing**: `https://dogzn.com` / `https://thewalkingpet-a1578.web.app`

## Regole Operative Fondamentali
1. **Persistenza e Versionamento**:
   - Il Mac è esclusivamente una postazione di lavoro temporanea e sostituibile.
   - Al termine di OGNI sessione o task che modifica il codice sorgente, eseguire sempre `git add`, `git commit` e `git push origin dev/v1.3.0` (o branch di lavoro attivo).
   - Tutto ciò che non è su GitHub è considerato perso.
   - Non riscrivere la storia di `main` (fermo al rilascio release 1.2.5+179).
2. **Sicurezza e Segreti**:
   - Non committare MAI certificati iOS (`.p12`/`.pem`), keystore Android (`.jks`/`.keystore`), file `.env`, service account JSON, o chiavi di servizio in chiaro.
   - Verificare sempre lo stato di `.gitignore` e `git status` prima di eseguire il push.
