---
name: servizi-esterni-licenze
description: "Licenze e limiti di Open-Meteo e Geoapify per PackLog (verificati il 5 ottobre 2026): Open-Meteo gratis solo non commerciale, clima storico solo dal piano Professional"
metadata:
  type: reference
---

- **Open-Meteo**: piano gratuito SOLO uso non commerciale (600/min, 5000/ora, 10.000/giorno, 300.000/mese). Commerciale: Standard 1M chiamate/mese, Professional 5M, Enterprise >50M; prezzi non pubblicati sulla pagina (chiedere a info@open-meteo.com). **Dati storici e climatici (che il bench usa per le normali a 5 anni) richiedono Professional o superiore.** Una richiesta con >10 variabili o >2 settimane conta come piu' chiamate. Fonte: open-meteo.com/en/pricing.
- **Geoapify** (geocoder dell'app, gestisce citta'/county/state/country con result_type e bbox): free 3000 crediti/giorno, 1 richiesta = 1 credito; piani da $59/mese (10k/giorno) a $609 (250k/giorno). Termini muti sul salvataggio/cache dei risultati: da chiedere a Geoapify. Attribuzione OpenStreetMap sempre obbligatoria, attribuzione Geoapify obbligatoria sul piano gratuito.
- **Mapbox**: geocoding temporaneo 100k/mese gratis poi $0,75/1000; per SALVARE i risultati serve il permanente a $5/1000.
- **Self-hosting** (Photon 95 GB + 64 GB RAM; Nominatim 1 TB + 64-128 GB RAM) non sta sul VPS (4 vCPU, 7,8 GB RAM, 122 GB liberi).

Decisione di Davide: restare su Geoapify; l'app passa a Open-Meteo le coordinate scelte dall'utente (niente seconda ricerca per nome); per state/country clima su alcune citta' rappresentative (dal bbox).

Related: [[bench-quantita-e-casi-guida]]
