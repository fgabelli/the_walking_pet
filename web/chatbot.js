(function() {
  'use strict';

  // ── DOGZN Assistant — AI Chat Widget ──
  const CONFIG = {
    project: 'dogzn',
    accent: '#4CAF50',
    position: 'right',
    welcome: 'Ciao! 🐕 Come posso aiutarti?',
    title: 'DOGZN Assistant',
    apiUrl: 'https://api-ivufbp6etq-uc.a.run.app/api/v1/chatbot',
    icon: '🐕',
    powered: 'Powered by DOGZN',
    systemContext: `Sei l'assistente ufficiale DOGZN, l'app italiana per proprietari di animali domestici. Rispondi SOLO sulla base di queste informazioni. Non inventare funzionalità.

## FUNZIONALITÀ PRINCIPALI
- **Mappa interattiva**: mostra utenti nelle vicinanze, veterinari, negozi, toelettatori, dog park, educatori cinofili. Filtri per categoria.
- **Radar Mode**: vedi quanti utenti sono in zona senza mostrare la tua posizione esatta. Puoi inviare un "ping" per far sapere che ci sei.
- **Passeggiate GPS**: traccia percorso, distanza, durata, passi e calorie. Si sincronizza con Apple Health / Health Connect.
- **Walk Card**: al termine di ogni passeggiata, viene generata una card condivisibile (Instagram, WhatsApp) con le statistiche.
- **Chat 1:1**: messaggi diretti con altri utenti. Supporta foto, posizione, inviti a passeggiata e profili pet.
- **Bacheca locale (Nextdoor)**: annunci geolocalizzati — cerchi dog sitter, hai trovato un oggetto, vendi accessori.
- **SOS Smarrimento**: lancia un allarme che notifica tutti gli utenti nel raggio di 5 km. Include foto, nome e contatto.
- **Segnalazione pericoli**: bocconi avvelenati, zone pericolose — segnala con un tap dalla mappa.
- **Profilo Pet**: foto, razza, data di nascita, microchip e scheda sanitaria (vaccini, farmaci, visite, allergie).
- **Social Feed**: post con foto, like, commenti — visibili agli amici e alla community locale.
- **Eventi**: raduni al parco, passeggiate di gruppo, fiere pet-friendly.

## RISCATTO ATTIVITÀ (Business Claim)
Per riscattare un'attività (veterinario, negozio, toelettatore, ecc.):
1. Vai sulla **Mappa** e trova il marker dell'attività
2. Tocca il marker per aprire la scheda
3. Scorri in basso e premi **"Riscatta questa attività"**
4. Compila il modulo con: nome, cognome, ruolo nell'attività, email aziendale, P.IVA
5. Il team DOGZN verifica la richiesta e la approva (riceverai una notifica)
6. Una volta approvato, puoi gestire il profilo business, rispondere alle recensioni e pubblicare offerte

## PIANI E PREZZI
- **Free** (€0): Radar, passeggiate (ultime 7), chat, bacheca, SOS. Con pubblicità.
- **Premium** (€2.99/mese): tutto del Free + zero pubblicità, cronologia illimitata, badge Premium, statistiche avanzate.
- **Business** (€9.99/mese): tutto del Premium + profilo business in evidenza, promozioni localizzate, statistiche business, risposte alle recensioni.

## PUBBLICITÀ IN-APP
Se vuoi pubblicizzare la tua attività su DOGZN:
1. Vai su **dogzn.com**, sezione "Business"
2. Compila il modulo di richiesta
3. Il team ti contatta entro 24 ore
Oppure scrivi a **business@dogzn.com**

## SUPPORTO
- Email: support@dogzn.com
- Business: business@dogzn.com
- L'app è disponibile su App Store e Google Play

## REGOLE
- Rispondi sempre in italiano
- Sii conciso e amichevole
- Se non sai qualcosa, dì di contattare support@dogzn.com
- Non inventare funzionalità che non esistono`,
  };

  // ── State ──
  let isOpen = false;
  let isLoading = false;
  let messages = [];
  let sessionId = sessionStorage.getItem('_cb_sid') || crypto.randomUUID();
  sessionStorage.setItem('_cb_sid', sessionId);

  // ── Inject CSS ──
  const style = document.createElement('style');
  style.textContent = `
    #cb-widget * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }

    #cb-fab {
      position: fixed;
      bottom: 24px;
      right: 24px;
      width: 60px;
      height: 60px;
      border-radius: 50%;
      background: ${CONFIG.accent};
      color: white;
      border: none;
      cursor: pointer;
      box-shadow: 0 4px 16px rgba(0,0,0,0.2);
      z-index: 99999;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.2s, box-shadow 0.2s;
      animation: cb-pulse 2s infinite;
    }
    #cb-fab:hover { transform: scale(1.08); box-shadow: 0 6px 24px rgba(0,0,0,0.3); }
    #cb-fab.cb-open { animation: none; }
    #cb-fab svg { width: 28px; height: 28px; transition: transform 0.3s; }
    #cb-fab.cb-open svg { transform: rotate(90deg); }
    @keyframes cb-pulse {
      0%, 100% { box-shadow: 0 4px 16px rgba(0,0,0,0.2); }
      50% { box-shadow: 0 4px 16px ${CONFIG.accent}66; }
    }

    #cb-window {
      position: fixed;
      bottom: 100px;
      right: 24px;
      width: 380px;
      max-width: calc(100vw - 32px);
      height: 520px;
      max-height: calc(100vh - 140px);
      background: #ffffff;
      border-radius: 20px;
      box-shadow: 0 12px 48px rgba(0,0,0,0.15);
      z-index: 99998;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      opacity: 0;
      transform: translateY(20px) scale(0.95);
      pointer-events: none;
      transition: opacity 0.3s, transform 0.3s;
    }
    #cb-window.cb-visible {
      opacity: 1;
      transform: translateY(0) scale(1);
      pointer-events: all;
    }

    #cb-header {
      background: ${CONFIG.accent};
      color: white;
      padding: 16px 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }
    #cb-header-icon {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: rgba(255,255,255,0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
    }
    #cb-header-text h3 { font-size: 15px; font-weight: 600; }
    #cb-header-text p { font-size: 11px; opacity: 0.85; margin-top: 2px; }

    #cb-messages {
      flex: 1;
      overflow-y: auto;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      scroll-behavior: smooth;
    }
    #cb-messages::-webkit-scrollbar { width: 4px; }
    #cb-messages::-webkit-scrollbar-thumb { background: #ddd; border-radius: 2px; }

    .cb-msg {
      max-width: 85%;
      padding: 10px 14px;
      border-radius: 16px;
      font-size: 14px;
      line-height: 1.5;
      word-break: break-word;
      animation: cb-fadein 0.3s;
    }
    .cb-msg a { color: ${CONFIG.accent}; text-decoration: underline; }
    .cb-msg ul, .cb-msg ol { padding-left: 18px; margin: 4px 0; }
    .cb-msg-user {
      align-self: flex-end;
      background: ${CONFIG.accent};
      color: white;
      border-bottom-right-radius: 4px;
    }
    .cb-msg-bot {
      align-self: flex-start;
      background: #f0f2f5;
      color: #1a1a2e;
      border-bottom-left-radius: 4px;
    }
    @keyframes cb-fadein {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .cb-typing {
      align-self: flex-start;
      padding: 12px 18px;
      background: #f0f2f5;
      border-radius: 16px;
      display: flex;
      gap: 4px;
      align-items: center;
    }
    .cb-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #999;
      animation: cb-bounce 1.4s infinite;
    }
    .cb-dot:nth-child(2) { animation-delay: 0.2s; }
    .cb-dot:nth-child(3) { animation-delay: 0.4s; }
    @keyframes cb-bounce {
      0%, 60%, 100% { transform: translateY(0); }
      30% { transform: translateY(-6px); }
    }

    #cb-input-area {
      padding: 12px 16px;
      border-top: 1px solid #eee;
      display: flex;
      gap: 8px;
      align-items: center;
      flex-shrink: 0;
      background: #fafafa;
    }
    #cb-input {
      flex: 1;
      border: 1px solid #e0e0e0;
      border-radius: 24px;
      padding: 10px 16px;
      font-size: 14px;
      outline: none;
      background: white;
      transition: border-color 0.2s;
    }
    #cb-input:focus { border-color: ${CONFIG.accent}; }
    #cb-input::placeholder { color: #aaa; }
    #cb-send {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      border: none;
      background: ${CONFIG.accent};
      color: white;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: opacity 0.2s, transform 0.1s;
      flex-shrink: 0;
    }
    #cb-send:hover { opacity: 0.9; }
    #cb-send:active { transform: scale(0.92); }
    #cb-send:disabled { opacity: 0.5; cursor: not-allowed; }
    #cb-send svg { width: 18px; height: 18px; }

    #cb-powered {
      text-align: center;
      padding: 6px;
      font-size: 10px;
      color: #bbb;
      background: #fafafa;
    }

    @media (max-width: 480px) {
      #cb-window {
        width: calc(100vw - 16px);
        height: calc(100vh - 100px);
        bottom: 88px;
        right: 8px;
        border-radius: 16px;
      }
      #cb-fab { bottom: 16px; right: 16px; width: 54px; height: 54px; }
    }
  `;
  document.head.appendChild(style);

  // ── Build DOM ──
  const widget = document.createElement('div');
  widget.id = 'cb-widget';
  widget.innerHTML = `
    <button id="cb-fab" aria-label="Apri assistente">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
    </button>
    <div id="cb-window">
      <div id="cb-header">
        <div id="cb-header-icon">${CONFIG.icon}</div>
        <div id="cb-header-text">
          <h3>${CONFIG.title}</h3>
          <p>Risposte in tempo reale con AI</p>
        </div>
      </div>
      <div id="cb-messages"></div>
      <div id="cb-input-area">
        <input id="cb-input" type="text" placeholder="Scrivi un messaggio..." maxlength="500" autocomplete="off" />
        <button id="cb-send" aria-label="Invia">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
        </button>
      </div>
      <div id="cb-powered">${CONFIG.powered}</div>
    </div>
  `;
  document.body.appendChild(widget);

  const fab = document.getElementById('cb-fab');
  const win = document.getElementById('cb-window');
  const msgContainer = document.getElementById('cb-messages');
  const input = document.getElementById('cb-input');
  const sendBtn = document.getElementById('cb-send');

  function renderMarkdown(text) {
    return text
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/g, '<em>$1</em>')
      .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
      .replace(/^- (.+)$/gm, '<li>$1</li>')
      .replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>')
      .replace(/\n/g, '<br>');
  }

  function addMessage(text, isUser) {
    const div = document.createElement('div');
    div.className = `cb-msg ${isUser ? 'cb-msg-user' : 'cb-msg-bot'}`;
    div.innerHTML = isUser ? text.replace(/</g, '&lt;') : renderMarkdown(text);
    msgContainer.appendChild(div);
    msgContainer.scrollTop = msgContainer.scrollHeight;
    messages.push({ role: isUser ? 'user' : 'assistant', text });
  }

  function showTyping() {
    const div = document.createElement('div');
    div.className = 'cb-typing';
    div.id = 'cb-typing';
    div.innerHTML = '<div class="cb-dot"></div><div class="cb-dot"></div><div class="cb-dot"></div>';
    msgContainer.appendChild(div);
    msgContainer.scrollTop = msgContainer.scrollHeight;
  }

  function hideTyping() {
    document.getElementById('cb-typing')?.remove();
  }

  fab.addEventListener('click', () => {
    isOpen = !isOpen;
    fab.classList.toggle('cb-open', isOpen);
    win.classList.toggle('cb-visible', isOpen);
    if (isOpen && messages.length === 0) addMessage(CONFIG.welcome, false);
    if (isOpen) setTimeout(() => input.focus(), 300);
  });

  async function sendMessage() {
    const text = input.value.trim();
    if (!text || isLoading) return;
    input.value = '';
    addMessage(text, true);
    isLoading = true;
    sendBtn.disabled = true;
    showTyping();
    try {
      const res = await fetch(CONFIG.apiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          project: CONFIG.project,
          message: text,
          sessionId,
          history: [
            { role: 'system', text: CONFIG.systemContext },
            ...messages.slice(-10)
          ]
        }),
      });
      const data = await res.json();
      hideTyping();
      if (data.status === 'ok') addMessage(data.response, false);
      else addMessage(data.message || 'Si è verificato un errore. Riprova.', false);
    } catch (err) {
      hideTyping();
      addMessage('Connessione non riuscita. Verifica la tua connessione e riprova.', false);
    }
    isLoading = false;
    sendBtn.disabled = false;
    input.focus();
  }

  sendBtn.addEventListener('click', sendMessage);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  });
})();
