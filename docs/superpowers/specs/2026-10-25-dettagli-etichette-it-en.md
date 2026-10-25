# Etichette dei dettagli: italiano e inglese

Da rivedere prima dell'implementazione. La colonna "Valore salvato" è quello che il server scrive in `aiMetadata` e non cambia: si traduce solo quello che vede l'utente.

## Tipi (tassonomia del 19/10)

### Sopra (Upper Body)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| T-Shirt | T-shirt | T-shirt |
| Shirt | Camicia | Shirt |
| Polo | Polo | Polo |
| Hoodie | Felpa con cappuccio | Hoodie |
| Sweatshirt | Felpa | Sweatshirt |
| Sweater | Maglione | Sweater |
| Tank Top | Canottiera | Tank top |
| Crop Top | Top corto | Crop top |
| Thermal Top | Maglia termica | Thermal top |
| Fleece | Pile | Fleece |
| Other | Altro | Other |

### Sotto (Lower Body)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Jeans | Jeans | Jeans |
| Shorts | Pantaloncini | Shorts |
| Trousers | Pantaloni | Trousers |
| Leggings | Leggings | Leggings |
| Skirt | Gonna | Skirt |
| Sweatpants | Pantaloni della tuta | Sweatpants |
| Swimwear | Costume | Swimwear |
| Thermal Bottoms | Calzamaglia termica | Thermal bottoms |
| Ski Pants | Pantaloni da sci | Ski pants |
| Wetsuit | Muta | Wetsuit |
| Other | Altro | Other |

### Abito intero (Full Body)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Dress | Vestito | Dress |
| Other | Altro | Other |

### Scarpe (Shoes)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Sneakers | Sneakers | Sneakers |
| Sandals | Sandali | Sandals |
| Boots | Stivali | Boots |
| Flip-Flops | Infradito | Flip-flops |
| Loafers | Mocassini | Loafers |
| Dress Shoes | Scarpe eleganti | Dress shoes |
| Hiking Boots | Scarponi da trekking | Hiking boots |
| Water Shoes | Scarpe da scoglio | Water shoes |
| Snow Boots | Doposci | Snow boots |
| Other | Altro | Other |

### Giacche (Outerwear)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Coat | Cappotto | Coat |
| Rain Jacket | Giacca impermeabile | Rain jacket |
| Down Jacket | Piumino | Down jacket |
| Windbreaker | Giacca a vento | Windbreaker |
| Blazer | Blazer | Blazer |
| Ski Jacket | Giacca da sci | Ski jacket |
| Ski Suit | Tuta da sci | Ski suit |
| Casual Jacket | Giubbotto | Casual jacket |
| Vest | Gilet | Vest |
| Other | Altro | Other |

### Accessori (Accessory)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Cap/Hat | Cappello | Hat |
| Belt | Cintura | Belt |
| Bag | Borsa | Bag |
| Scarf | Sciarpa | Scarf |
| Sunglasses | Occhiali da sole | Sunglasses |
| Jewelry | Gioielli | Jewelry |
| Watch | Orologio | Watch |
| Gloves | Guanti | Gloves |
| Tie | Cravatta | Tie |
| Umbrella | Ombrello | Umbrella |
| Other | Altro | Other |

### Essenziali (Essentials)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Underwear | Intimo | Underwear |
| Socks | Calzini | Socks |
| Pajamas | Pigiama | Pajamas |
| Other | Altro | Other |

### Nomi dei gruppi nel foglio di scelta del tipo

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Upper Body | Sopra | Tops |
| Lower Body | Sotto | Bottoms |
| Full Body | Abito intero | Full body |
| Shoes | Scarpe | Shoes |
| Outerwear | Giacche | Outerwear |
| Accessory | Accessori | Accessories |
| Essentials | Essenziali | Essentials |

## Colori di base

Il colore si salva come testo, in italiano (lo scrive il modello). I colori di base sono suggerimenti: in inglese si mostra la traduzione, ma si salva la parola italiana, così si confronta con quelli già presenti negli oggetti.

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Bianco | Bianco | White |
| Nero | Nero | Black |
| Grigio | Grigio | Grey |
| Blu | Blu | Blue |
| Marrone | Marrone | Brown |
| Beige | Beige | Beige |

I colori aggiunti dall'utente o letti dal modello ("Rosa chiaro", "Verde scuro") si mostrano come sono scritti, in tutte e due le lingue.

## Calore (`warmth`)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| 1 | Molto leggero | Very light |
| 2 | Leggero | Light |
| 3 | Medio | Medium |
| 4 | Caldo | Warm |
| 5 | Molto caldo | Very warm |

## Pioggia (`waterResistance`)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| 0 | Si bagna | Not waterproof |
| 1 | Pioggia leggera | Light rain |
| 2 | Impermeabile | Waterproof |

## Stile (`formality`)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Loungewear | Da casa | Loungewear |
| Casual | Casual | Casual |
| Smart Casual | Curato | Smart casual |
| Business | Lavoro | Business |
| Formal | Elegante | Formal |

## Usi (`activityTags`)

| Valore salvato | Italiano | Inglese |
|---|---|---|
| Everyday | Tutti i giorni | Everyday |
| Office | Ufficio | Office |
| Beach | Mare | Beach |
| Swimming | Nuoto | Swimming |
| Hiking | Montagna | Hiking |
| Sport | Sport | Sport |
| Formal | Elegante | Formal |
| Lounge | Casa | Lounge |

## Testi della pagina e della scheda

| Dove | Italiano | Inglese |
|---|---|---|
| Titolo della sezione | Dettagli | Details |
| Titolo gruppo | Tipo | Type |
| Titolo gruppo | Colore | Colour |
| Titolo gruppo | Calore | Warmth |
| Titolo gruppo | Pioggia | Rain |
| Titolo gruppo | Stile | Style |
| Titolo gruppo | Usi | Uses |
| Accanto a "Usi" | anche più di uno | pick more than one |
| Accanto a un titolo in dubbio | da controllare | to check |
| Pillola per aggiungere un colore | + Altro colore | + Other colour |
| Campo del nuovo colore (suggerimento) | Scrivi un colore | Type a colour |
| Titolo del foglio di scelta del tipo | Scegli il tipo | Choose the type |
| Riga del capo, dubbi (1) | 1 da controllare | 1 to check |
| Riga del capo, dubbi (più di 1) | {} da controllare | {} to check |
