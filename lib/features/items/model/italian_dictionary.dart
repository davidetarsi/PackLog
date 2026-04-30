import 'package:pack_log/features/items/model/category_dictionary.dart';

import 'item_model.dart';

class ItalianDictionary implements CategoryDictionary {

@override
  Map<String, ItemCategory> get exactMatches => {
  // ── Vestiti ──────────────────────────────────────────────────────────────
  'maglietta': ItemCategory.vestiti,
  't-shirt': ItemCategory.vestiti,
  'tshirt': ItemCategory.vestiti,
  'maglia': ItemCategory.vestiti,
  'camicia': ItemCategory.vestiti,
  'camicetta': ItemCategory.vestiti,
  'pantaloni': ItemCategory.vestiti,
  'jeans': ItemCategory.vestiti,
  'felpa': ItemCategory.vestiti,
  'maglione': ItemCategory.vestiti,
  'giacca': ItemCategory.vestiti,
  'giubbotto': ItemCategory.vestiti,
  'giubbino': ItemCategory.vestiti,
  'cappotto': ItemCategory.vestiti,
  'piumino': ItemCategory.vestiti,
  'gonna': ItemCategory.vestiti,
  'vestito': ItemCategory.vestiti,
  'abito': ItemCategory.vestiti,
  'shorts': ItemCategory.vestiti,
  'bermuda': ItemCategory.vestiti,
  'costume': ItemCategory.vestiti,
  'costume da bagno': ItemCategory.vestiti,
  'bikini': ItemCategory.vestiti,
  'reggiseno': ItemCategory.vestiti,
  'mutande': ItemCategory.vestiti,
  'boxer': ItemCategory.vestiti,
  'boxer da bagno': ItemCategory.vestiti,
  'calzini': ItemCategory.vestiti,
  'calze': ItemCategory.vestiti,
  'collant': ItemCategory.vestiti,
  'pigiama': ItemCategory.vestiti,
  'accappatoio': ItemCategory.vestiti,
  'cintura': ItemCategory.vestiti,
  'cravatta': ItemCategory.vestiti,
  'sciarpa': ItemCategory.vestiti,
  'guanti': ItemCategory.vestiti,
  'cappello': ItemCategory.vestiti,
  'berretto': ItemCategory.vestiti,
  'scarpe': ItemCategory.vestiti,
  'sneakers': ItemCategory.vestiti,
  'sandali': ItemCategory.vestiti,
  'ciabatte': ItemCategory.vestiti,
  'stivali': ItemCategory.vestiti,
  'infradito': ItemCategory.vestiti,
  'canottiera': ItemCategory.vestiti,
  'polo': ItemCategory.vestiti,
  'cardigan': ItemCategory.vestiti,
  'impermeabile': ItemCategory.vestiti,
  'tuta': ItemCategory.vestiti,
  'leggings': ItemCategory.vestiti,
  'top': ItemCategory.vestiti,
  'body': ItemCategory.vestiti,
  'pile': ItemCategory.vestiti,
  'scarponi': ItemCategory.vestiti,
  'mocassini': ItemCategory.vestiti,
  'pantofole': ItemCategory.vestiti,
  'biancheria intima': ItemCategory.vestiti,
  'calzoncini': ItemCategory.vestiti,
  'gilet': ItemCategory.vestiti,
  'poncho': ItemCategory.vestiti,
  'foulard': ItemCategory.vestiti,
  'papillon': ItemCategory.vestiti,
  'bretelle': ItemCategory.vestiti,
  'mantella': ItemCategory.vestiti,
  'salopette': ItemCategory.vestiti,
  'tutina': ItemCategory.vestiti,
  'underwear': ItemCategory.vestiti,
  'socks': ItemCategory.vestiti,
  'jacket': ItemCategory.vestiti,
  'shirt': ItemCategory.vestiti,
  'trousers': ItemCategory.vestiti,
  'pants': ItemCategory.vestiti,
  'dress': ItemCategory.vestiti,
  'skirt': ItemCategory.vestiti,
  'coat': ItemCategory.vestiti,
  'sweater': ItemCategory.vestiti,
  'hoodie': ItemCategory.vestiti,
  'sweatshirt': ItemCategory.vestiti,
  'shoes': ItemCategory.vestiti,
  'boots': ItemCategory.vestiti,
  'hat': ItemCategory.vestiti,
  'gloves': ItemCategory.vestiti,
  'scarf': ItemCategory.vestiti,
  'belt': ItemCategory.vestiti,
  'tie': ItemCategory.vestiti,
  'pajamas': ItemCategory.vestiti,
  'swimsuit': ItemCategory.vestiti,
  'flip flops': ItemCategory.vestiti,
  'sandals': ItemCategory.vestiti,
  'slippers': ItemCategory.vestiti,

  // ── Toiletries ───────────────────────────────────────────────────────────
  'spazzolino': ItemCategory.toiletries,
  'dentifricio': ItemCategory.toiletries,
  'shampoo': ItemCategory.toiletries,
  'balsamo': ItemCategory.toiletries,
  'bagnoschiuma': ItemCategory.toiletries,
  'sapone': ItemCategory.toiletries,
  'deodorante': ItemCategory.toiletries,
  'rasoio': ItemCategory.toiletries,
  'schiuma da barba': ItemCategory.toiletries,
  'crema': ItemCategory.toiletries,
  'crema solare': ItemCategory.toiletries,
  'protezione solare': ItemCategory.toiletries,
  'doposole': ItemCategory.toiletries,
  'pettine': ItemCategory.toiletries,
  'spazzola': ItemCategory.toiletries,
  'cotton fioc': ItemCategory.toiletries,
  'filo interdentale': ItemCategory.toiletries,
  'collutorio': ItemCategory.toiletries,
  'salviette': ItemCategory.toiletries,
  'assorbenti': ItemCategory.toiletries,
  'tamponi': ItemCategory.toiletries,
  'trucchi': ItemCategory.toiletries,
  'mascara': ItemCategory.toiletries,
  'fondotinta': ItemCategory.toiletries,
  'rossetto': ItemCategory.toiletries,
  'matita occhi': ItemCategory.toiletries,
  'struccante': ItemCategory.toiletries,
  'limetta': ItemCategory.toiletries,
  'tagliaunghie': ItemCategory.toiletries,
  'pinzette': ItemCategory.toiletries,
  'medicinali': ItemCategory.toiletries,
  'medicine': ItemCategory.toiletries,
  'cerotti': ItemCategory.toiletries,
  'termometro': ItemCategory.toiletries,
  'aspirina': ItemCategory.toiletries,
  'ibuprofene': ItemCategory.toiletries,
  'antistaminico': ItemCategory.toiletries,
  'collirio': ItemCategory.toiletries,
  'lenti a contatto': ItemCategory.toiletries,
  'occhiali': ItemCategory.toiletries,
  'occhiali da sole': ItemCategory.toiletries,
  'profumo': ItemCategory.toiletries,
  'burrocacao': ItemCategory.toiletries,
  'antizanzare': ItemCategory.toiletries,
  'gel': ItemCategory.toiletries,
  'lacca': ItemCategory.toiletries,
  'phon': ItemCategory.toiletries,
  'asciugacapelli': ItemCategory.toiletries,
  'spugna': ItemCategory.toiletries,
  'dischetti struccanti': ItemCategory.toiletries,
  'kit toilette': ItemCategory.toiletries,
  'kit primo soccorso': ItemCategory.toiletries,
  'fermacapelli': ItemCategory.toiletries,
  'elastici capelli': ItemCategory.toiletries,
  'sunscreen': ItemCategory.toiletries,
  'toothbrush': ItemCategory.toiletries,
  'toothpaste': ItemCategory.toiletries,
  'soap': ItemCategory.toiletries,
  'sunglasses': ItemCategory.toiletries,
  'moisturizer': ItemCategory.toiletries,
  'makeup': ItemCategory.toiletries,
  'lipstick': ItemCategory.toiletries,
  'perfume': ItemCategory.toiletries,
  'deodorant': ItemCategory.toiletries,
  'razor': ItemCategory.toiletries,
  'shaving cream': ItemCategory.toiletries,
  'conditioner': ItemCategory.toiletries,
  'contact lenses': ItemCategory.toiletries,
  'band-aids': ItemCategory.toiletries,
  'first aid kit': ItemCategory.toiletries,

  // ── Elettronica ──────────────────────────────────────────────────────────
  'caricatore': ItemCategory.elettronica,
  'caricabatterie': ItemCategory.elettronica,
  'cavo usb': ItemCategory.elettronica,
  'cavo lightning': ItemCategory.elettronica,
  'cavo usb-c': ItemCategory.elettronica,
  'cavo hdmi': ItemCategory.elettronica,
  'power bank': ItemCategory.elettronica,
  'cuffie': ItemCategory.elettronica,
  'auricolari': ItemCategory.elettronica,
  'airpods': ItemCategory.elettronica,
  'portatile': ItemCategory.elettronica,
  'laptop': ItemCategory.elettronica,
  'tablet': ItemCategory.elettronica,
  'ipad': ItemCategory.elettronica,
  'kindle': ItemCategory.elettronica,
  'ebook': ItemCategory.elettronica,
  'e-reader': ItemCategory.elettronica,
  'telefono': ItemCategory.elettronica,
  'cellulare': ItemCategory.elettronica,
  'smartphone': ItemCategory.elettronica,
  'fotocamera': ItemCategory.elettronica,
  'gopro': ItemCategory.elettronica,
  'cavetto': ItemCategory.elettronica,
  'adattatore': ItemCategory.elettronica,
  'adattatore universale': ItemCategory.elettronica,
  'presa universale': ItemCategory.elettronica,
  'ciabatta elettrica': ItemCategory.elettronica,
  'hard disk': ItemCategory.elettronica,
  'chiavetta usb': ItemCategory.elettronica,
  'mouse': ItemCategory.elettronica,
  'tastiera': ItemCategory.elettronica,
  'orologio': ItemCategory.elettronica,
  'smartwatch': ItemCategory.elettronica,
  'drone': ItemCategory.elettronica,
  'speaker': ItemCategory.elettronica,
  'cassa bluetooth': ItemCategory.elettronica,
  'action cam': ItemCategory.elettronica,
  'treppiede': ItemCategory.elettronica,
  'scheda sd': ItemCategory.elettronica,
  'batteria': ItemCategory.elettronica,
  'console': ItemCategory.elettronica,
  'piastra capelli': ItemCategory.elettronica,
  'torcia': ItemCategory.elettronica,
  'mouse wireless': ItemCategory.elettronica,
  'mousepad': ItemCategory.elettronica,
  'ssd': ItemCategory.elettronica,
  'pendrive': ItemCategory.elettronica,
  'webcam': ItemCategory.elettronica,
  'monitor': ItemCategory.elettronica,
  'proiettore': ItemCategory.elettronica,
  'hub usb': ItemCategory.elettronica,
  'cavo': ItemCategory.elettronica,
  'charger': ItemCategory.elettronica,
  'headphones': ItemCategory.elettronica,
  'earbuds': ItemCategory.elettronica,
  'cable': ItemCategory.elettronica,
  'adapter': ItemCategory.elettronica,
  'keyboard': ItemCategory.elettronica,
  'camera': ItemCategory.elettronica,
  'tripod': ItemCategory.elettronica,
  'sd card': ItemCategory.elettronica,
  'battery': ItemCategory.elettronica,
  'usb drive': ItemCategory.elettronica,
  'external hard drive': ItemCategory.elettronica,
  'portable charger': ItemCategory.elettronica,
};


@override
  List<({String root, ItemCategory category})> get rootKeywords => [
  // ── BLOCCO 5 LETTERE ──────────────────────────────────────────────
  // Usa 5 lettere quando 4 creerebbero ambiguità.
  
  (root: 'smart', category: ItemCategory.elettronica), // smartphone, smartwatch
  (root: 'adatt', category: ItemCategory.elettronica),  // adattatore, adattatore universale
  (root: 'power', category: ItemCategory.elettronica),  // power bank
  (root: 'batte', category: ItemCategory.elettronica), // batteria, batterie
  (root: 'collu', category: ItemCategory.toiletries),  // collutorio
  (root: 'colli', category: ItemCategory.toiletries),  // collirio
  (root: 'magli', category: ItemCategory.vestiti),     // maglia, maglietta, maglione
  (root: 'caric', category: ItemCategory.elettronica), // caricatore, caricabatterie
  (root: 'sciar', category: ItemCategory.vestiti),     // sciarpa, sciarpe
  (root: 'camic', category: ItemCategory.vestiti),     // camicia, camicetta
  
  // ── BLOCCO 4 LETTERE (Il cuore reattivo) ──────────────────────────
  
  // Elettronica
  (root: 'blue', category: ItemCategory.elettronica),  // bluetooth
  (root: 'adat', category: ItemCategory.elettronica),  // adattatore
  (root: 'auri', category: ItemCategory.elettronica),  // auricolari
  (root: 'trep', category: ItemCategory.elettronica),  // treppiede
  (root: 'tabl', category: ItemCategory.elettronica),  // tablet
  (root: 'batt', category: ItemCategory.elettronica),  // batteria, batterie
  (root: 'cavo', category: ItemCategory.elettronica),  // cavo, cavetto
  (root: 'comp', category: ItemCategory.elettronica),  // computer, laptop, tablet, ipad, kindle, ebook, e-reader
  
  // Toiletries
  (root: 'anti', category: ItemCategory.toiletries),   // antizanzare, antistaminico
  (root: 'truc', category: ItemCategory.toiletries),   // trucco, trucchi, struccante
  (root: 'dent', category: ItemCategory.toiletries),   // dente, dentifricio
  (root: 'fond', category: ItemCategory.toiletries),   // fondotinta
  (root: 'medi', category: ItemCategory.toiletries),   // medicina, medicinali
  (root: 'salv', category: ItemCategory.toiletries),   // salviette, salvietta
  (root: 'asso', category: ItemCategory.toiletries),   // assorbenti
  (root: 'spaz', category: ItemCategory.toiletries),   // spazzola, spazzolino
  (root: 'occh', category: ItemCategory.toiletries),   // occhiali (da sole/vista), matita occhi
  (root: 'deod', category: ItemCategory.toiletries),   // deodorante
  (root: 'cero', category: ItemCategory.toiletries),   // cerotto, cerotti
  (root: 'prof', category: ItemCategory.toiletries),   // profumo, profumi
  (root: 'sham', category: ItemCategory.toiletries),   // shampoo
  (root: 'prot', category: ItemCategory.toiletries),   // protezione solare
  
  // Vestiti
  (root: 'bian', category: ItemCategory.vestiti),      // biancheria
  (root: 'magl', category: ItemCategory.vestiti),      // calza, calzini, calzettoni
  (root: 'acca', category: ItemCategory.vestiti),      // accappatoio
  (root: 'capp', category: ItemCategory.vestiti),      // cappotto, cappello
  (root: 'crav', category: ItemCategory.vestiti),      // cravatta
  (root: 'pant', category: ItemCategory.vestiti),      // pantaloni, pantofole
  (root: 'legg', category: ItemCategory.vestiti),      // leggings
  (root: 'sand', category: ItemCategory.vestiti),      // sandali
  (root: 'stiv', category: ItemCategory.vestiti),      // stivali
  (root: 'cost', category: ItemCategory.vestiti),      // costume, costumi
  (root: 'giac', category: ItemCategory.vestiti),      // giacca, giaccone
  (root: 'giub', category: ItemCategory.vestiti),      // giubbotto, giubbino
  (root: 'scar', category: ItemCategory.vestiti),      // scarpa, scarpe, scarponi
  (root: 'felp', category: ItemCategory.vestiti),      // felpa, felpe, felpina
  (root: 'calz', category: ItemCategory.vestiti),      // calza, calzini, calzettoni
  (root: 'impe', category: ItemCategory.vestiti),      // impermeabile
  (root: 'tshi', category: ItemCategory.vestiti),      // tshirt, t-shirt
  
  // ── BLOCCO 3 LETTERE ──────────────────────────────────────────────
  // Usare con estrema cautela. Solo per sigle inequivocabili.
  (root: 'usb', category: ItemCategory.elettronica),   // cavo usb, chiavetta usb
  (root: 'mac', category: ItemCategory.elettronica),   // macbook, mac
];

final Map<String, String> _irregularPlurals = {
    'jeans': 'jeans',
    'shorts': 'shorts',
    'sneakers': 'sneakers',
    'collant': 'collant',
    'slip': 'slip',
  };

@override
  Set<String> get stopWords =>{
  'il', 'lo', 'la', 'le', 'li', 'gli', 'un', 'uno', 'una',
  'di', 'da', 'in', 'su', 'per', 'con', 'tra', 'fra',
  'del', 'dal', 'nel', 'sul', 'al', 'col',
  'mio', 'mia', 'miei', 'mie',
  'nuovo', 'nuova', 'nuovi', 'nuove',
  'vecchio', 'vecchia',
  'grande', 'piccolo', 'piccola',
};

@override
  String lemmatize(String word) {
    if (word.length <= 3) return word;
    
    if (_irregularPlurals.containsKey(word)) {
      return _irregularPlurals[word]!;
    }

    if (word.endsWith('i')) {
      return word.substring(0, word.length - 1); 
    }
    if (word.endsWith('e')) {
      return '${word.substring(0, word.length - 1)}a';
    }
    
    return word;
  }

}