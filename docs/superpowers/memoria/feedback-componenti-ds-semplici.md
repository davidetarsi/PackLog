---
name: feedback-componenti-ds-semplici
description: "Davide vuole UI costruita solo con design system, tema e stringhe esistenti, in componenti piccoli e semplici (niente spaghetti code)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: a389a2f8-d273-43c6-b669-b6e7c79291e2
  modified: 2026-11-02T08:00:46.881Z
---

Ogni lavoro di UI usa i componenti già definiti nel codice (design system `lib/shared/widgets/ds_*`, tema, token di `design_system.dart`, `AppMotion`, `AppOpacity`, stringhe in `assets/translations`). I componenti nuovi devono essere piccoli, con una responsabilità sola, così che cambiare un'animazione o un dettaglio dopo sia una modifica piccola e in un punto.

**Why:** Davide l'ha ripetuto più volte (2 novembre 2026: "questo penso di avertelo già detto altre volte"); vuole che i cambi futuri, per esempio alle animazioni, restino piccoli perché il codice è ben strutturato.

**How to apply:** scriverlo nei vincoli di ogni spec e piano di UI, nei brief degli agenti e come criterio per i revisori (un widget che fa troppe cose, o colori, durate e testi scritti a mano, sono finding). Vedi anche [[design-valigia-ai]].
