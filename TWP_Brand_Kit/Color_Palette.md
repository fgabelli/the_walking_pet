# The Walking Pet - Palette Colori

## Colori Primari

### Verde Smeraldo (Primary Green)
- **HEX**: `#00A878`
- **RGB**: `0, 168, 120`
- **CMYK**: `100, 0, 29, 34`
- **Uso**: Pin di localizzazione, elementi primari, header
- **Significato**: Natura, passeggiate outdoor, fiducia, crescita

---

### Coral Arancione (Primary Coral)
- **HEX**: `#FF6B6B`
- **RGB**: `255, 107, 107`
- **CMYK**: `0, 58, 58, 0`
- **Uso**: Zampa, lettere TWP, CTA buttons, accenti energici
- **Significato**: Energia, warmth, friendliness, passione

---

## Colori Secondari

### Teal (Secondary Teal)
- **HEX**: `#06AED5`
- **RGB**: `6, 174, 213`
- **CMYK**: `97, 18, 0, 16`
- **Uso**: Accenti, varianti gradient, elementi interattivi
- **Significato**: Modernità, tech, innovazione

---

### Verde Forest (Secondary Forest)
- **HEX**: `#2D6A4F`
- **RGB**: `45, 106, 79`
- **CMYK**: `58, 0, 25, 58`
- **Uso**: Testi, sottotitoli, elementi secondari
- **Significato**: Stabilità, natura, professionalità

---

### Arancione Warm (Accent Orange)
- **HEX**: `#F77F00`
- **RGB**: `247, 127, 0`
- **CMYK**: `0, 49, 100, 3`
- **Uso**: CTA secondari, accenti energici, highlights
- **Significato**: Entusiasmo, azione, dinamismo

---

## Colori Neutri

### Bianco (White)
- **HEX**: `#FFFFFF`
- **RGB**: `255, 255, 255`
- **CMYK**: `0, 0, 0, 0`
- **Uso**: Sfondi, spazi negativi, testi su sfondi scuri

---

### Off-White (Light Background)
- **HEX**: `#F8F9FA`
- **RGB**: `248, 249, 250`
- **CMYK**: `1, 0, 0, 2`
- **Uso**: Sfondi alternativi, sezioni, cards

---

### Charcoal (Dark Text)
- **HEX**: `#264653`
- **RGB**: `38, 70, 83`
- **CMYK**: `54, 16, 0, 67`
- **Uso**: Testi principali, titoli, elementi scuri

---

### Grigio Medio (Medium Gray)
- **HEX**: `#6C757D`
- **RGB**: `108, 117, 125`
- **CMYK**: `14, 6, 0, 51`
- **Uso**: Testi secondari, placeholder, bordi

---

## Combinazioni Consigliate

### Combinazione 1: Principale (Primary)
- **Background**: Bianco `#FFFFFF`
- **Primario**: Verde Smeraldo `#00A878`
- **Accento**: Coral `#FF6B6B`
- **Testo**: Charcoal `#264653`

**Uso**: Sito web, app, materiali principali

---

### Combinazione 2: Energica (Energetic)
- **Background**: Off-White `#F8F9FA`
- **Primario**: Coral `#FF6B6B`
- **Accento**: Arancione Warm `#F77F00`
- **Testo**: Charcoal `#264653`

**Uso**: CTA, promozioni, eventi speciali

---

### Combinazione 3: Naturale (Natural)
- **Background**: Bianco `#FFFFFF`
- **Primario**: Verde Forest `#2D6A4F`
- **Accento**: Verde Smeraldo `#00A878`
- **Testo**: Charcoal `#264653`

**Uso**: Contenuti informativi, blog, guide

---

### Combinazione 4: Tech (Modern Tech)
- **Background**: Charcoal `#264653`
- **Primario**: Teal `#06AED5`
- **Accento**: Verde Smeraldo `#00A878`
- **Testo**: Bianco `#FFFFFF`

**Uso**: Landing pages, features premium, dashboard

---

## Accessibilità

### Contrasto Testo su Sfondo

#### Testo Scuro su Chiaro ✅
- Charcoal `#264653` su Bianco `#FFFFFF` - **Ratio 9.7:1** (AAA)
- Verde Forest `#2D6A4F` su Bianco `#FFFFFF` - **Ratio 6.2:1** (AA)

#### Testo Chiaro su Scuro ✅
- Bianco `#FFFFFF` su Verde Smeraldo `#00A878` - **Ratio 2.8:1** (AA Large)
- Bianco `#FFFFFF` su Charcoal `#264653` - **Ratio 9.7:1** (AAA)

#### Combinazioni da Evitare ❌
- Coral `#FF6B6B` su Bianco `#FFFFFF` - **Ratio 3.3:1** (Non sufficiente per testo piccolo)
- Verde Smeraldo `#00A878` su Verde Forest `#2D6A4F` - Basso contrasto

---

## Gradients

### Gradient 1: Verde Fresco
- **Start**: Verde Smeraldo `#00A878`
- **End**: Teal `#06AED5`
- **Direzione**: 135deg (diagonale)
- **Uso**: Sfondi hero, cards premium, elementi decorativi

---

### Gradient 2: Sunset Warm
- **Start**: Coral `#FF6B6B`
- **End**: Arancione Warm `#F77F00`
- **Direzione**: 90deg (orizzontale)
- **Uso**: CTA buttons, highlights, promozioni

---

### Gradient 3: Forest Deep
- **Start**: Verde Forest `#2D6A4F`
- **End**: Verde Smeraldo `#00A878`
- **Direzione**: 180deg (verticale)
- **Uso**: Footer, sezioni informative, backgrounds

---

## File di Riferimento

### CSS Variables
```css
:root {
  /* Primary Colors */
  --color-primary-green: #00A878;
  --color-primary-coral: #FF6B6B;
  
  /* Secondary Colors */
  --color-secondary-teal: #06AED5;
  --color-secondary-forest: #2D6A4F;
  --color-accent-orange: #F77F00;
  
  /* Neutral Colors */
  --color-white: #FFFFFF;
  --color-off-white: #F8F9FA;
  --color-charcoal: #264653;
  --color-gray: #6C757D;
}
```

### Tailwind Config
```javascript
colors: {
  'primary-green': '#00A878',
  'primary-coral': '#FF6B6B',
  'secondary-teal': '#06AED5',
  'secondary-forest': '#2D6A4F',
  'accent-orange': '#F77F00',
  'charcoal': '#264653',
  'off-white': '#F8F9FA',
}
```

---

**Nota**: Questi colori sono stati selezionati per garantire coerenza visiva, accessibilità e riconoscibilità del brand The Walking Pet in tutti i contesti di utilizzo.
