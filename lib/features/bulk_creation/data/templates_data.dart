import '../../items/model/item_model.dart';
import '../model/template_item_def.dart';
import '../model/travel_template.dart';
import '../model/user_gender.dart';

/// Template di viaggio predefiniti per la creazione massiva di item.
///
/// I campi [TravelTemplate.nameKey], [TravelTemplate.descriptionKey] e
/// [TemplateItemDef.nameKey] sono chiavi i18n: richiedono `.tr()` nella UI
/// o nel provider. Non sono stringhe visualizzabili direttamente.
const List<TravelTemplate> kTravelTemplates = [
  // ============================================================
  // 1. WEEKEND
  // ============================================================
  TravelTemplate(
    key: 'weekend',
    nameKey: 'bulk_creation.templates.weekend.name',
    icon: 'weekend',
    descriptionKey: 'bulk_creation.templates.weekend.description',
    items: [
      TemplateItemDef(
        nameKey: 'bulk_creation.items.documenti_identita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.portafoglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.chiavi_casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.tshirt',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.jeans',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.biancheria_intima',
        category: ItemCategory.vestiti,
        defaultQuantity: 3,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pigiama_camicia',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.spazzolino',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.dentifricio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.deodorante',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.rasoio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.schiuma_barba',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.trucchi',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.caricabatterie_smartphone',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cuffie',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.occhiali_sole',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.libro_ereader',
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
    nameKey: 'bulk_creation.templates.long_trip.name',
    icon: 'flight',
    descriptionKey: 'bulk_creation.templates.long_trip.description',
    items: [
      TemplateItemDef(
        nameKey: 'bulk_creation.items.documenti_identita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.portafoglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.chiavi_casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.tshirt',
        category: ItemCategory.vestiti,
        defaultQuantity: 7,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pantaloni',
        category: ItemCategory.vestiti,
        defaultQuantity: 3,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.biancheria_intima',
        category: ItemCategory.vestiti,
        defaultQuantity: 8,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.calzini',
        category: ItemCategory.vestiti,
        defaultQuantity: 7,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pigiama_camicia',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.giacca',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.spazzolino',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.dentifricio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.shampoo',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.deodorante',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.rasoio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.schiuma_barba',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.trucchi',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.assorbenti',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.piastra_capelli',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.caricabatterie_smartphone',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.adattatore_universale',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cuffie',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.occhiali_sole',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.libro_ereader',
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
    nameKey: 'bulk_creation.templates.business.name',
    icon: 'business_center',
    descriptionKey: 'bulk_creation.templates.business.description',
    items: [
      TemplateItemDef(
        nameKey: 'bulk_creation.items.documenti_identita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.portafoglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.chiavi_casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.camicia_elegante',
        category: ItemCategory.vestiti,
        defaultQuantity: 3,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pantaloni_eleganti',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.giacca',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.scarpe_eleganti',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cintura',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cravatta',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pigiama',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.caricabatterie_laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.mouse_wireless',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cuffie',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.blocco_appunti',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.penna',
        category: ItemCategory.varie,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.biglietti_visita',
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
    nameKey: 'bulk_creation.templates.digital_nomad.name',
    icon: 'laptop_mac',
    descriptionKey: 'bulk_creation.templates.digital_nomad.description',
    items: [
      TemplateItemDef(
        nameKey: 'bulk_creation.items.documenti_identita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.portafoglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.chiavi_casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.caricabatterie_laptop',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.tablet',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cuffie_noise_cancelling',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.hard_disk',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.mouse_mousepad',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.power_bank',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.adattatore_universale',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cavo_hdmi',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.tshirt',
        category: ItemCategory.vestiti,
        defaultQuantity: 5,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pantaloni_comodi',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pigiama',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.kit_toilette',
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
    nameKey: 'bulk_creation.templates.beach.name',
    icon: 'beach_access',
    descriptionKey: 'bulk_creation.templates.beach.description',
    items: [
      TemplateItemDef(
        nameKey: 'bulk_creation.items.documenti_identita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.portafoglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.chiavi_casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.bikini',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.boxer_bagno',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pigiama_camicia',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.asciugamano_mare',
        category: ItemCategory.varie,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.crema_solare',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.doposole',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.rasoio',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.male],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.trucchi_waterproof',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.assorbenti',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
        targetGenders: [UserGender.female],
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.occhiali_sole',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cappello',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.infradito',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.maschera_boccaglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cuffie',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.libro_ereader',
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
    nameKey: 'bulk_creation.templates.mountain.name',
    icon: 'terrain',
    descriptionKey: 'bulk_creation.templates.mountain.description',
    items: [
      TemplateItemDef(
        nameKey: 'bulk_creation.items.documenti_identita',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.portafoglio',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.chiavi_casa',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.zaino_trekking',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.scarponi_trekking',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.giacca_impermeabile',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pile',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pantaloni_trekking',
        category: ItemCategory.vestiti,
        defaultQuantity: 2,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.calzini_tecnici',
        category: ItemCategory.vestiti,
        defaultQuantity: 4,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.pigiama',
        category: ItemCategory.vestiti,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.borraccia',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.crema_solare_alta',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.antizanzare',
        category: ItemCategory.toiletries,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.kit_primo_soccorso',
        category: ItemCategory.varie,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.torcia',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.power_bank',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.bussola_gps',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.cuffie',
        category: ItemCategory.elettronica,
        defaultQuantity: 1,
      ),
      TemplateItemDef(
        nameKey: 'bulk_creation.items.bastoncini_trekking',
        category: ItemCategory.varie,
        defaultQuantity: 2,
      ),
    ],
  ),
];
