# Misura dei posti: quanti ne escono con l'armadio vuoto e a metà

1 novembre 2026. Numeri per Davide; nessuna soglia, nessuna raccomandazione.

**Aggiornata dopo il Task 3b** (un posto solo per le giacche e per le scarpe del meteo): le tabelle sotto sono quelle di dopo. La riga "prima/dopo" qui sotto è l'unico posto dove restano i numeri di prima.

## Che cosa è stato misurato

Il generatore di `pack-trip` ora risponde con `posti` (cosa manca alla valigia, "importante" o "utile") anche quando l'armadio è vuoto. Per vedere quanti posti uscirebbero, ho rigiocato le **888 valigie registrate dal bench** (`esporta_oracolo.py celle`: i set pool44, holdout30, v2 e v3m) con due armadi diversi, poi ho contato i posti con `postiApp`. Script: `supabase/functions/_shared/valigia/test/misura_posti.ts`.

- **Armadio vuoto**: nessun capo. Tutto quello che il viaggio chiede diventa un posto.
- **Armadio a metà**: la metà dei capi dell'armadio del caso (le righe di indice pari).
- Il set **v4 sigillato non è stato toccato**: l'esportazione dell'oracolo non lo contiene, e lo script salta comunque qualsiasi insieme con "v4" nel nome.
- Le 888 valigie sono viaggi per armadi: ogni viaggio compare con più armadi (i viaggi distinti sono 30, 44, 24 e 24, nella tabella). Con l'armadio vuoto lo stesso viaggio dà lo stesso risultato per ogni armadio, quindi i conteggi "in quante valigie" vanno letti come "in quante di queste 888 prove", non come viaggi diversi.

### Approssimazioni

- Il viaggio per `postiApp` è ricavato dallo scenario del bench: giorni, attività, bagaglio, alloggio, lavatrice e destinazione (o tappe). Il bench ha una lavatrice sola per viaggio e nessun alloggio per tappa, quindi non passa dal calcolo che l'app fa dalle tappe.
- Il meteo è quello registrato dal bench per ogni viaggio, con il dettaglio per tappa nei viaggi a più tappe: ha la stessa forma di quello della funzione.
- La risposta del modello e i voti di Jev sono quelli registrati. A metà armadio i capi tolti non contano, gli altri tengono il loro voto; con l'armadio vuoto non c'è nessun voto per i capi.
- Le copie salvate di ogni capo sono la quantità della riga d'armadio.
- Nei conteggi dei nomi "Magliette" e "Maglietta" sono lo stesso posto (plurale e singolare riportati alla stessa voce). Un tipo di posto vale una volta per valigia.
- Nomi in italiano.

## Prima e dopo (un posto solo per giacca e scarpe del meteo)

Le 888 valigie, stessa esportazione, stesso script. "Prima" è il commit 801a555, "dopo" è il Task 3b.

| armadio | importanti: media | mediana | max | valigie con più di 6 importanti |
|---|---|---|---|---|
| vuoto, prima | 3,3 | 2 | 9 | 188 su 888 (21%) |
| vuoto, dopo | 2,2 | 2 | 6 | 0 su 888 (0%) |
| a metà, prima | 1,1 | 1 | 7 | 1 su 888 (0%) |
| a metà, dopo | 1,1 | 1 | 6 | 0 su 888 (0%) |

Con l'armadio vuoto, "Sneakers invernali" + "Scarpe invernali" + "Stivali invernali" sono diventate "Scarpe invernali", e "Piumino" + "Cappotto invernale" + "Giacca a vento invernale" sono diventati "Giacca invernale". Il posto che prima si chiamava "Blazer" con il freddo (46 prove, un gap di giacca per il freddo che il generatore chiamava Blazer, non un'occasione elegante) ora è dentro "Giacca invernale". I Blazer delle occasioni eleganti, gli scarponi da trekking, il costume, i doposci, le scarpe eleganti, il cappello, la sciarpa, i guanti e l'ombrello restano come prima.

## Armadio vuoto

| insieme | valigie | viaggi distinti | posti: media | posti: mediana | importanti: media | importanti: mediana | importanti: max | valigie con più di 6 importanti |
|---|---|---|---|---|---|---|---|---|
| holdout30 | 240 | 30 | 12,2 | 12,0 | 2,3 | 2,0 | 5 | 0% |
| pool44 | 264 | 44 | 12,0 | 12,0 | 2,0 | 1,0 | 6 | 0% |
| v2 | 192 | 24 | 11,9 | 12,0 | 2,4 | 3,0 | 5 | 0% |
| v3m | 192 | 24 | 12,1 | 12,0 | 2,3 | 3,0 | 4 | 0% |

#### holdout30: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 240)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Giacca invernale | 136 | Calzini | 240 |
| Scarpe invernali | 112 | Mutande | 240 |
| Cappello caldo | 96 | Necessaire | 240 |
| Sciarpa calda | 88 | Pigiama | 240 |
| Costume da bagno | 64 | Maglietta | 146 |
| Scarponi da trekking | 52 | Pantaloni | 129 |
|  |  | Sneakers | 123 |
|  |  | Cappello | 122 |
|  |  | Felpa | 111 |
|  |  | Maglione caldo | 96 |
|  |  | Pantaloni caldi | 96 |
|  |  | Camicia | 95 |
|  |  | Camicia calda | 69 |
|  |  | Giacca impermeabile | 62 |
|  |  | Sciarpa | 44 |

#### pool44: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 264)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Giacca invernale | 126 | Calzini | 264 |
| Scarpe invernali | 120 | Mutande | 264 |
| Cappello caldo | 103 | Necessaire | 264 |
| Sciarpa calda | 89 | Pigiama | 264 |
| Costume da bagno | 54 | Maglietta | 168 |
| Scarponi da trekking | 24 | Pantaloni | 156 |
| Scarponi da trekking invernali | 6 | Sneakers | 138 |
| Guanti | 5 | Cappello | 131 |
| Scarponi da trekking caldi | 1 | Maglione caldo | 108 |
|  |  | Pantaloni caldi | 108 |
|  |  | Camicia | 104 |
|  |  | Camicia calda | 77 |
|  |  | Felpa | 77 |
|  |  | Giacca impermeabile | 63 |
|  |  | Giacca a vento | 56 |

#### v2: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 192)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Giacca invernale | 128 | Calzini | 192 |
| Scarpe invernali | 104 | Mutande | 192 |
| Cappello caldo | 96 | Necessaire | 192 |
| Sciarpa calda | 63 | Pigiama | 192 |
| Costume da bagno | 56 | Maglietta | 127 |
| Scarponi da trekking | 15 | Felpa | 96 |
|  |  | Maglione caldo | 96 |
|  |  | Cappello | 95 |
|  |  | Pantaloni caldi | 95 |
|  |  | Pantaloni | 85 |
|  |  | Sneakers | 74 |
|  |  | Camicia | 72 |
|  |  | Camicia calda | 56 |
|  |  | Giacca a vento | 46 |
|  |  | Infradito | 39 |

#### v3m: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 192)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Giacca invernale | 112 | Calzini | 192 |
| Scarpe invernali | 104 | Mutande | 192 |
| Cappello caldo | 78 | Necessaire | 192 |
| Sciarpa calda | 75 | Pigiama | 192 |
| Costume da bagno | 40 | Maglietta | 145 |
| Scarponi da trekking | 30 | Felpa | 111 |
|  |  | Cappello | 102 |
|  |  | Pantaloni | 102 |
|  |  | Sneakers | 88 |
|  |  | Pantaloni caldi | 87 |
|  |  | Maglione caldo | 80 |
|  |  | Camicia | 74 |
|  |  | Sciarpa | 43 |
|  |  | Camicia calda | 40 |
|  |  | Giacca impermeabile | 39 |

#### Valigie con più di 8 importanti

- holdout30: 0 su 240
- pool44: 0 su 264
- v2: 0 su 192
- v3m: 0 su 192

## Armadio a metà

| insieme | valigie | viaggi distinti | posti: media | posti: mediana | importanti: media | importanti: mediana | importanti: max | valigie con più di 6 importanti |
|---|---|---|---|---|---|---|---|---|
| holdout30 | 240 | 30 | 5,9 | 5,0 | 1,1 | 1,0 | 6 | 0% |
| pool44 | 264 | 44 | 5,8 | 5,0 | 1,1 | 1,0 | 5 | 0% |
| v2 | 192 | 24 | 5,8 | 5,0 | 1,1 | 1,0 | 5 | 0% |
| v3m | 192 | 24 | 5,5 | 5,0 | 1,0 | 1,0 | 4 | 0% |

#### holdout30: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 240)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Giacca impermeabile | 48 | Mutande | 240 |
| Costume da bagno | 38 | Necessaire | 240 |
| Sciarpa calda | 37 | Calzini | 215 |
| Cappello caldo | 29 | Pigiama | 120 |
| Giacca invernale | 28 | Pantaloni | 59 |
| Pantaloni eleganti | 25 | Maglietta | 49 |
| Camicia elegante | 16 | Felpa | 31 |
| Scarponi da trekking impermeabili | 13 | Pantaloni caldi | 31 |
| Scarpe invernali | 11 | Sciarpa | 23 |
| Blazer | 8 | Cappello | 19 |
| Scarpe impermeabili | 7 | Polo | 15 |
|  |  | Camicia | 11 |
|  |  | Pantaloncini | 11 |
|  |  | Pantaloni termici | 10 |
|  |  | Scarpe | 10 |

#### pool44: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 264)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Pantaloni eleganti | 41 | Mutande | 264 |
| Giacca invernale | 35 | Necessaire | 264 |
| Cappello caldo | 34 | Calzini | 251 |
| Sciarpa calda | 34 | Pigiama | 135 |
| Costume da bagno | 33 | Pantaloni | 63 |
| Giacca impermeabile | 28 | Maglietta | 44 |
| Camicia elegante | 21 | Pantaloni caldi | 31 |
| Blazer | 19 | Sciarpa | 27 |
| Scarpe impermeabili | 15 | Cappello | 24 |
| Scarpe invernali | 14 | Felpa | 16 |
| Scarponi da trekking impermeabili | 8 | Maglia | 16 |
| Cappotto impermeabile | 2 | Stivali | 16 |
| Scarpe eleganti | 2 | Maglione caldo | 12 |
| Guanti | 1 | Occhiali da sole | 10 |
|  |  | Infradito | 8 |

#### v2: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 192)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Costume da bagno | 42 | Mutande | 192 |
| Giacca invernale | 35 | Necessaire | 192 |
| Giacca impermeabile | 34 | Calzini | 172 |
| Cappello caldo | 23 | Pigiama | 96 |
| Sciarpa calda | 23 | Maglietta | 45 |
| Pantaloni eleganti | 12 | Pantaloni | 35 |
| Scarpe impermeabili | 12 | Pantaloni caldi | 31 |
| Camicia elegante | 11 | Felpa | 20 |
| Scarpe invernali | 6 | Sciarpa | 18 |
| Scarponi da trekking impermeabili | 4 | Cappello | 13 |
| Blazer | 2 | Pantaloncini | 13 |
|  |  | Infradito | 11 |
|  |  | Maglione caldo | 8 |
|  |  | Scarpe | 7 |
|  |  | Pantaloni termici | 6 |

#### v3m: i 15 posti importanti e i 15 utili più frequenti (in quante valigie su 192)

| importanti | valigie | utili | valigie |
|---|---|---|---|
| Giacca impermeabile | 29 | Mutande | 192 |
| Giacca invernale | 29 | Necessaire | 192 |
| Sciarpa calda | 27 | Calzini | 166 |
| Costume da bagno | 26 | Pigiama | 96 |
| Pantaloni eleganti | 20 | Maglietta | 38 |
| Cappello caldo | 18 | Pantaloni | 35 |
| Scarponi da trekking impermeabili | 10 | Sciarpa | 22 |
| Camicia elegante | 9 | Cappello | 17 |
| Scarpe impermeabili | 8 | Pantaloni caldi | 13 |
| Scarpe invernali | 7 | Felpa | 10 |
| Blazer | 3 | Occhiali da sole | 9 |
| Scarpe eleganti | 1 | Stivali | 9 |
|  |  | Infradito | 8 |
|  |  | Pantaloncini | 7 |
|  |  | Polo | 7 |

#### Valigie con più di 8 importanti

- holdout30: 0 su 240
- pool44: 0 su 264
- v2: 0 su 192
- v3m: 0 su 192

## Quanti importanti per valigia (tutte le 888)

| importanti | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| armadio vuoto | 194 | 202 | 66 | 103 | 283 | 38 | 2 | 0 | 0 | 0 |
| armadio meta | 383 | 229 | 160 | 82 | 28 | 5 | 1 | 0 | 0 | 0 |

## Osservazioni

1. **Armadio vuoto: circa 12 posti per valigia, 2 importanti in media.** La mediana dei posti è 12 in tutti e quattro gli insiemi. Gli importanti hanno ancora due gruppi: 396 valigie su 888 ne hanno 0 o 1 (i viaggi caldi), 386 ne hanno 3 o 4 (i viaggi freddi, di solito Giacca invernale, Scarpe invernali, Cappello caldo e Sciarpa calda). Il massimo è 6, in 2 prove; nessuna valigia supera 6.
2. **Quattro posti utili sono sempre lì.** Calzini, Mutande, Necessaire e Pigiama compaiono in tutte le valigie con l'armadio vuoto: sono 4 dei circa 12 posti. A metà armadio Mutande e Necessaire restano in tutte le prove, Calzini in quasi tutte e Pigiama in circa metà.
3. **I nomi importanti dipendono dal freddo.** Con l'armadio vuoto dominano Giacca invernale, Scarpe invernali, Cappello caldo e Sciarpa calda; seguono Costume da bagno e Scarponi da trekking. Ogni valigia ha al massimo una "Giacca" e un paio di "Scarpe" del meteo: non compaiono più insieme "Scarpe invernali" e "Sneakers invernali".
4. **A metà armadio i posti scendono a circa 6 e gli importanti a 1.** La mediana degli importanti è 1, il massimo 6. I nomi importanti cambiano: restano Giacca impermeabile, Costume da bagno, Sciarpa calda e Cappello caldo, ma salgono i capi delle occasioni eleganti (Pantaloni eleganti, Camicia elegante, Blazer) e delle attività (Scarponi da trekking impermeabili).
5. **Tra gli utili, il resto dipende dall'armadio.** Con l'armadio vuoto vengono dopo Maglietta, Pantaloni, Sneakers, Cappello e Felpa (più una voce "caldo" per i viaggi freddi: Pantaloni caldi, Maglione caldo, Camicia calda); a metà armadio, dove si vedono quasi solo i pezzi mancanti o in meno, per esempio in holdout30 Calzini compare in 215 prove su 240 e Pigiama in 120. "Sneakers" e "Giacca impermeabile" restano utili quando il viaggio non chiede scarpe o giacche per il freddo o la pioggia.
