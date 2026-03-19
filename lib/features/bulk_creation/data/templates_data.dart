import '../../items/model/item_model.dart';
import '../model/template_item_def.dart';
import '../model/travel_template.dart';
import '../model/user_gender.dart';

/// Template di viaggio predefiniti per la creazione massiva di item.
///
/// Ogni template contiene una lista di oggetti comunemente necessari
/// per quel tipo di viaggio, con filtri per genere dove appropriato.
const List<TravelTemplate> kTravelTemplates = [
  // ============================================================
  // 1. WEEKEND
  // ============================================================
  TravelTemplate(
    key: 'weekend',
    name: 'Weekend',
    icon: 'weekend',
    description: 'Viaggio breve di 2-3 giorni',
    items: [
      TemplateItemDef(
        name: 'Documenti d\'identità / Passaporto',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Portafoglio e contanti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Chiavi di casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'T-shirt',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Jeans',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Biancheria intima',
        category: ItemCategory.vestiti,
        defaultQuantity: 3,
      ),
      TemplateItemDef(
        name: 'Pigiama / Camicia da notte',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Spazzolino da denti',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Dentifricio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Deodorante',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Rasoio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Schiuma da barba',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Trucchi',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Caricabatterie smartphone',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cuffie / Auricolari',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Occhiali da sole',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Libro / E-reader',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
    ],
  ),

  // ============================================================
  // 2. VIAGGIO LUNGO
  // ============================================================
  TravelTemplate(
    key: 'long_trip',
    name: 'Viaggio lungo',
    icon: 'flight',
    description: 'Viaggio di una settimana o più',
    items: [
      TemplateItemDef(
        name: 'Documenti d\'identità / Passaporto',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Portafoglio e contanti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Chiavi di casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'T-shirt',
        category: ItemCategory.vestiti,
        defaultQuantity: 7,
      ),
      TemplateItemDef(
        name: 'Pantaloni',
        category: ItemCategory.vestiti,
        defaultQuantity: 3,
      ),
      TemplateItemDef(
        name: 'Biancheria intima',
        category: ItemCategory.vestiti,
        defaultQuantity: 8,
      ),
      TemplateItemDef(
        name: 'Calzini',
        category: ItemCategory.vestiti,
        defaultQuantity: 7,
      ),
      TemplateItemDef(
        name: 'Pigiama / Camicia da notte',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Giacca',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Spazzolino da denti',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Dentifricio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Shampoo',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Deodorante',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Rasoio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Schiuma da barba',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Trucchi',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Assorbenti',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Piastra per capelli',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Caricabatterie smartphone',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Adattatore universale',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cuffie / Auricolari',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Occhiali da sole',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Libro / E-reader',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
    ],
  ),

  // ============================================================
  // 3. BUSINESS TRIP
  // ============================================================
  TravelTemplate(
    key: 'business',
    name: 'Business trip',
    icon: 'business_center',
    description: 'Viaggio di lavoro professionale',
    items: [
      TemplateItemDef(
        name: 'Documenti d\'identità / Passaporto',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Portafoglio e contanti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Chiavi di casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Camicia elegante',
        category: ItemCategory.vestiti,
        defaultQuantity: 3,
      ),
      TemplateItemDef(
        name: 'Pantaloni eleganti',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Giacca',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Scarpe eleganti',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cintura',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cravatta',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Pigiama',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Caricabatterie laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Mouse wireless',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cuffie / Auricolari',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Blocco appunti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Penna',
        category: ItemCategory.varie,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Biglietti da visita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
    ],
  ),

  // ============================================================
  // 4. NOMADE DIGITALE
  // ============================================================
  TravelTemplate(
    key: 'digital_nomad',
    name: 'Nomade digitale',
    icon: 'laptop_mac',
    description: 'Viaggio prolungato con lavoro remoto',
    items: [
      TemplateItemDef(
        name: 'Documenti d\'identità / Passaporto',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Portafoglio e contanti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Chiavi di casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Caricabatterie laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Tablet',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cuffie noise-cancelling',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Hard Disk / SSD esterno',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Mouse e Mousepad',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Power bank',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Adattatore universale',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cavo HDMI',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'T-shirt',
        category: ItemCategory.vestiti,
        defaultQuantity: 5,
      ),
      TemplateItemDef(
        name: 'Pantaloni comodi',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Pigiama',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Kit toilette completo',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
    ],
  ),

  // ============================================================
  // 5. VACANZA AL MARE
  // ============================================================
  TravelTemplate(
    key: 'beach',
    name: 'Vacanza al mare',
    icon: 'beach_access',
    description: 'Viaggio al mare o in località balneare',
    items: [
      TemplateItemDef(
        name: 'Documenti d\'identità / Passaporto',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Portafoglio e contanti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Chiavi di casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Bikini / Costume intero',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Boxer da bagno',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Pigiama / Camicia da notte',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Asciugamano mare',
        category: ItemCategory.varie,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Crema solare',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Doposole',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Rasoio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        name: 'Trucchi waterproof',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Assorbenti',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        name: 'Occhiali da sole',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cappello',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Infradito',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Maschera e boccaglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cuffie / Auricolari',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Libro / E-reader',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
    ],
  ),

  // ============================================================
  // 6. MONTAGNA/TREKKING
  // ============================================================
  TravelTemplate(
    key: 'mountain',
    name: 'Montagna/Trekking',
    icon: 'terrain',
    description: 'Escursioni in montagna e trekking',
    items: [
      TemplateItemDef(
        name: 'Documenti d\'identità / Passaporto',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Portafoglio e contanti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Chiavi di casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Zaino da trekking',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Scarponi da trekking',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Giacca impermeabile',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Pile',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Pantaloni da trekking',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        name: 'Calzini tecnici',
        category: ItemCategory.vestiti,
        defaultQuantity: 4,
      ),
      TemplateItemDef(
        name: 'Pigiama',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Borraccia',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Crema solare alta protezione',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Antizanzare',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Kit primo soccorso',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Torcia',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Power bank',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Bussola / GPS',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Cuffie / Auricolari',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        name: 'Bastoncini da trekking',
        category: ItemCategory.varie,
        defaultQuantity: 2,
      ),
    ],
  ),
];
