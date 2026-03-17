import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../items/model/item_model.dart';
import '../../items/repositories/item_repository.dart';
import '../../items/providers/item_provider.dart';
import '../data/templates_data.dart';
import '../model/bulk_creation_state.dart';
import '../model/draft_item.dart';
import '../model/template_item_def.dart';
import '../model/user_gender.dart';

part 'bulk_creation_provider.g.dart';

/// Notifier per la gestione dello stato della creazione massiva di item.
/// 
/// Responsabilità:
/// - Gestire la selezione di template di viaggio
/// - Filtrare gli item per genere
/// - Merge intelligente di item duplicati (somma quantità)
/// - Preservare modifiche manuali dell'utente (rename, quantity changes, manual additions)
@riverpod
class BulkCreationNotifier extends _$BulkCreationNotifier {
  final Uuid _uuid = const Uuid();

  @override
  BulkCreationState build() {
    return BulkCreationState();
  }

  /// Imposta il genere dell'utente e rigenera gli item dai template.
  void setGender(UserGender gender) {
    state = state.copyWith(gender: gender);
    _rebuildItems();
  }

  /// Aggiunge o rimuove un template dalla selezione.
  void toggleTemplate(String templateKey) {
    final Set<String> updatedSelection = Set.from(state.selectedTemplateKeys);

    if (updatedSelection.contains(templateKey)) {
      updatedSelection.remove(templateKey);
    } else {
      updatedSelection.add(templateKey);
    }

    state = state.copyWith(selectedTemplateKeys: updatedSelection);
    _rebuildItems();
  }

  /// Rinomina un item esistente.
  /// 
  /// Se l'item è derivato da un template, lo sposta in manualItems
  /// con un nuovo UUID (non più l'ID deterministico del template).
  /// Se è già manuale, lo aggiorna in place.
  void renameItem(String itemId, String newName) {
    // Cerca l'item nei template-derived
    final templateItemIndex = state.templateDerivedItems
        .indexWhere((item) => item.id == itemId);

    if (templateItemIndex != -1) {
      // Item da template: spostalo in manualItems con nuovo UUID e nome
      final item = state.templateDerivedItems[templateItemIndex];
      final updatedItem = item.copyWith(
        id: _uuid.v4(), // Nuovo UUID per item manuale
        name: newName,
      );

      final updatedTemplateDerived = List<DraftItem>.from(state.templateDerivedItems)
        ..removeAt(templateItemIndex);

      final updatedManualItems = List<DraftItem>.from(state.manualItems)
        ..add(updatedItem);

      state = state.copyWith(
        templateDerivedItems: updatedTemplateDerived,
        manualItems: updatedManualItems,
      );
      return;
    }

    // Cerca l'item nei manual items
    final manualItemIndex = state.manualItems
        .indexWhere((item) => item.id == itemId);

    if (manualItemIndex != -1) {
      // Item manuale: aggiornalo direttamente (mantieni UUID originale)
      final item = state.manualItems[manualItemIndex];
      final updatedItem = item.copyWith(name: newName);

      final updatedManualItems = List<DraftItem>.from(state.manualItems)
        ..[manualItemIndex] = updatedItem;

      state = state.copyWith(manualItems: updatedManualItems);
    }
  }

  /// Modifica la quantità di un item esistente (delta può essere +1 o -1).
  /// 
  /// Garantisce che la quantità non scenda mai sotto 1.
  /// Se l'item è derivato da template, lo sposta in manualItems con nuovo UUID.
  void updateQuantity(String itemId, int delta) {
    // Cerca l'item nei template-derived
    final templateItemIndex = state.templateDerivedItems
        .indexWhere((item) => item.id == itemId);

    if (templateItemIndex != -1) {
      // Item da template: spostalo in manualItems con nuovo UUID e quantità aggiornata
      final item = state.templateDerivedItems[templateItemIndex];
      final newQuantity = (item.quantity + delta).clamp(1, 999);
      final updatedItem = item.copyWith(
        id: _uuid.v4(), // Nuovo UUID per item manuale
        quantity: newQuantity,
      );

      final updatedTemplateDerived = List<DraftItem>.from(state.templateDerivedItems)
        ..removeAt(templateItemIndex);

      final updatedManualItems = List<DraftItem>.from(state.manualItems)
        ..add(updatedItem);

      state = state.copyWith(
        templateDerivedItems: updatedTemplateDerived,
        manualItems: updatedManualItems,
      );
      return;
    }

    // Cerca l'item nei manual items
    final manualItemIndex = state.manualItems
        .indexWhere((item) => item.id == itemId);

    if (manualItemIndex != -1) {
      // Item manuale: aggiornalo direttamente (mantieni UUID originale)
      final item = state.manualItems[manualItemIndex];
      final newQuantity = (item.quantity + delta).clamp(1, 999);
      final updatedItem = item.copyWith(quantity: newQuantity);

      final updatedManualItems = List<DraftItem>.from(state.manualItems)
        ..[manualItemIndex] = updatedItem;

      state = state.copyWith(manualItems: updatedManualItems);
    }
  }

  /// Elimina un item.
  void deleteItem(String itemId) {
    // Rimuovi da templateDerivedItems se presente
    final updatedTemplateDerived = state.templateDerivedItems
        .where((item) => item.id != itemId)
        .toList();

    // Rimuovi da manualItems se presente
    final updatedManualItems = state.manualItems
        .where((item) => item.id != itemId)
        .toList();

    state = state.copyWith(
      templateDerivedItems: updatedTemplateDerived,
      manualItems: updatedManualItems,
    );
  }

  /// Aggiunge un item manuale con categoria specificata.
  /// 
  /// L'item viene creato con un nome placeholder "Nuovo oggetto"
  /// e un UUID univoco. Viene aggiunto a manualItems.
  void addManualItem(ItemCategory category) {
    final newItem = DraftItem(
      id: _uuid.v4(),
      name: 'Nuovo oggetto',
      category: category,
      quantity: 1,
    );

    final updatedManualItems = List<DraftItem>.from(state.manualItems)
      ..add(newItem);

    state = state.copyWith(manualItems: updatedManualItems);
  }

  /// Imposta la casa di destinazione.
  void setTargetHouse(String? houseId) {
    state = state.copyWith(targetHouseId: houseId);
  }

  /// Imposta lo spazio di destinazione.
  void setTargetSpace(String? spaceId) {
    state = state.copyWith(targetSpaceId: spaceId);
  }

  /// Rigenera gli item derivati dai template selezionati.
  /// 
  /// LOGICA CRITICA:
  /// 1. Itera sui template selezionati e filtra per genere
  /// 2. Verifica se l'item esiste già in manualItems (stesso nome normalizzato + categoria)
  ///    - Se SÌ: incrementa la quantità dell'item manuale esistente
  ///    - Se NO: aggiungilo al merge map per templateDerivedItems
  /// 3. Merge item duplicati all'interno del merge map (somma quantità)
  /// 4. Assegna ID DETERMINISTICI agli item aggregati (per stabilità Flutter widget keys)
  /// 5. Ordina per categoria e nome
  /// 
  /// PRESERVAZIONE MODIFICHE MANUALI:
  /// - Gli item in `manualItems` NON vengono mai rimossi o rinominati
  /// - Se un template include un item già presente in manualItems (stesso nome + categoria),
  ///   la quantità viene SOMMATA nell'item manuale esistente
  /// - Gli ID deterministici prevengono remount dei widget Flutter
  void _rebuildItems() {
    // Step 1: Raccogli tutti gli item dai template selezionati, filtrati per genere
    final List<TemplateItemDef> allTemplateItems = [];

    for (final templateKey in state.selectedTemplateKeys) {
      final template = kTravelTemplates.firstWhere(
        (t) => t.key == templateKey,
        orElse: () => throw StateError('Template not found: $templateKey'),
      );

      final itemsForGender = template.getItemsByGender(state.gender);
      allTemplateItems.addAll(itemsForGender);
    }

    // Step 2: Merge item duplicati + Controlla collisioni con manualItems
    final Map<String, _MergeKey> mergeMap = {};
    final List<DraftItem> updatedManualItems = List<DraftItem>.from(state.manualItems);

    for (final templateItem in allTemplateItems) {
      final normalizedName = templateItem.name.toLowerCase().trim();
      final category = templateItem.category;

      // CRITICAL FIX #2: Verifica se questo item esiste già in manualItems
      final manualItemIndex = updatedManualItems.indexWhere(
        (manual) => manual.normalizedName == normalizedName && manual.category == category,
      );

      if (manualItemIndex != -1) {
        // Item trovato in manualItems: incrementa la sua quantità
        final existingManualItem = updatedManualItems[manualItemIndex];
        final updatedManualItem = existingManualItem.copyWith(
          quantity: existingManualItem.quantity + templateItem.defaultQuantity,
        );
        updatedManualItems[manualItemIndex] = updatedManualItem;
        
        // NON aggiungere questo item a mergeMap (evita duplicati)
        continue;
      }

      // Item NON presente in manualItems: procedi con il merge nel mergeMap
      final mergeKeyString = '$normalizedName|${category.name}';

      if (mergeMap.containsKey(mergeKeyString)) {
        // Item duplicato tra i template: somma la quantità
        mergeMap[mergeKeyString] = mergeMap[mergeKeyString]!.copyWith(
          quantity: mergeMap[mergeKeyString]!.quantity + templateItem.defaultQuantity,
        );
      } else {
        // Primo incontro di questo item
        mergeMap[mergeKeyString] = _MergeKey(
          normalizedName: normalizedName,
          category: category,
          displayName: templateItem.name, // Preserva la prima versione del nome
          quantity: templateItem.defaultQuantity,
        );
      }
    }

    // Step 3: Converti il merge map in lista di DraftItem con ID DETERMINISTICI
    // CRITICAL FIX #1: Usa ID basati su categoria + nome normalizzato per stabilità widget keys
    final List<DraftItem> rebuiltItems = mergeMap.values.map((mergedItem) {
      return DraftItem(
        id: 'tpl_${mergedItem.category.name}_${mergedItem.normalizedName}',
        name: mergedItem.displayName!,
        category: mergedItem.category,
        quantity: mergedItem.quantity,
      );
    }).toList();

    // Step 4: Ordina per categoria e poi per nome (per UX coerente)
    rebuiltItems.sort((a, b) {
      final categoryComparison = a.category.index.compareTo(b.category.index);
      if (categoryComparison != 0) return categoryComparison;
      return a.name.compareTo(b.name);
    });

    // Step 5: Aggiorna lo stato con ENTRAMBE le liste
    state = state.copyWith(
      templateDerivedItems: rebuiltItems,
      manualItems: updatedManualItems, // Aggiornata con le quantità incrementate
    );
  }

  /// Salva tutti gli item nel database in una singola transazione atomica.
  /// 
  /// Validazione:
  /// - Verifica che targetHouseId sia impostato
  /// - Verifica che ci siano item da salvare
  /// 
  /// Processo:
  /// 1. Genera UUID reali per ogni DraftItem (gli ID deterministici sono solo per UI)
  /// 2. Mappa DraftItem -> ItemModel con houseId e spaceId corretti
  /// 3. Chiama repository.insertMultipleItems() (batch insert atomico)
  /// 4. Invalida i provider degli item per aggiornare la UI
  /// 5. Resetta lo stato del wizard
  /// 
  /// Throws: Exception se targetHouseId è null o se l'inserimento fallisce
  Future<void> saveToDatabase() async {
    // Validazione
    if (state.targetHouseId == null) {
      throw StateError('targetHouseId non impostato. Impossibile salvare gli item.');
    }

    if (state.allItems.isEmpty) {
      throw StateError('Nessun item da salvare.');
    }

    // Mapping: DraftItem -> ItemModel
    // CRITICAL: Generiamo UUID REALI per il database.
    // Gli ID deterministici (tpl_*) sono SOLO per la stabilità dei widget Flutter.
    final now = DateTime.now();
    final itemModels = state.allItems.map((draftItem) {
      return ItemModel(
        id: _uuid.v4(), // UUID reale per il database
        houseId: state.targetHouseId!,
        name: draftItem.name,
        category: draftItem.category,
        quantity: draftItem.quantity,
        spaceId: state.targetSpaceId,
        description: null,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();

    // Inserimento batch atomico
    final repository = ref.read(itemRepositoryProvider);
    await repository.insertMultipleItems(itemModels);

    // Invalidazione provider per refresh UI
    ref.invalidate(itemNotifierProvider(state.targetHouseId!));

    // Reset dello stato del wizard
    reset();
  }

  /// Resetta lo stato alla configurazione iniziale.
  void reset() {
    state = BulkCreationState();
  }
}

/// Chiave per il merge di item duplicati.
/// 
/// Due item sono considerati duplicati se hanno:
/// - Stesso nome normalizzato (lowercase + trim)
/// - Stessa categoria
class _MergeKey {
  final String normalizedName;
  final ItemCategory category;
  final String? displayName; // Nome originale da mostrare
  final int quantity;

  _MergeKey({
    required this.normalizedName,
    required this.category,
    this.displayName,
    this.quantity = 1,
  });

  @override
  String toString() => '$normalizedName|${category.name}';

  _MergeKey copyWith({
    String? normalizedName,
    ItemCategory? category,
    String? displayName,
    int? quantity,
  }) {
    return _MergeKey(
      normalizedName: normalizedName ?? this.normalizedName,
      category: category ?? this.category,
      displayName: displayName ?? this.displayName,
      quantity: quantity ?? this.quantity,
    );
  }
}
