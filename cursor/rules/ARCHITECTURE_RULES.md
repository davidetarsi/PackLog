# Architecture Rules - Feature-First Flutter App with Riverpod

## 📋 Overview

Questo documento definisce le regole architetturali per progetti Flutter che utilizzano **Riverpod 4.x** con `riverpod_annotation` e **Freezed 3.x** in un'architettura **feature-first**.

## 🏗️ Architettura Feature-First

### Struttura delle Directory

L'applicazione deve essere organizzata in **feature-first**, non layer-first. Ogni feature deve contenere tutti i suoi layer internamente.

```
lib/
├── features/
│   ├── feature_name/
│   │   ├── data/              # Provider per dati locali/cache (opzionale)
│   │   ├── model/             # Modelli di dominio con Freezed
│   │   ├── providers/         # Provider Riverpod per i model
│   │   ├── repositories/      # Repository abstract e implementazioni
│   │   ├── viewmodel/         # ViewModel per logica presentazione (opzionale)
│   │   └── view/              # Widget e schermate Flutter
│   │       └── widgets/       # Widget specifici della feature (opzionale)
│   └── another_feature/
│       ├── data/
│       ├── model/
│       ├── providers/
│       ├── repositories/
│       ├── viewmodel/
│       └── view/
├── shared/                    # Componenti condivisi tra feature
│   ├── widgets/              # Widget riutilizzabili
│   ├── services/             # Servizi globali
│   └── constants/            # Costanti condivise
├── core/                      # Configurazione core dell'app
│   ├── theme/                 # Tema Material 3
│   └── routing/               # Configurazione routing
└── main.dart
```

### Layer per Feature

Ogni feature deve contenere i seguenti layer:

1. **data/** - Provider per dati locali/cache (se necessario)
2. **model/** - Modelli di dominio usando Freezed 3.x
3. **providers/** - Provider Riverpod per i model
4. **repositories/** - Repository abstract e implementazioni concrete
5. **viewmodel/** - ViewModel per la logica di presentazione (se necessario)
6. **view/** - Widget e schermate Flutter

### Comandi Build

Sempre eseguire `dart run build_runner build --delete-conflicting-outputs` dopo modifiche a:
- Model con Freezed
- Provider con `@Riverpod`
- Repository con `@Riverpod`

**Nota**: Con Riverpod 4.x e Freezed 3.x, usa `dart run` invece di `flutter pub run`.

## 📦 Dipendenze Richieste

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  # Altri pacchetti specifici del progetto

dev_dependencies:
  build_runner: ^2.4.12
  json_serializable: ^6.8.0
  freezed: ^2.5.7
  riverpod_generator: ^2.3.5
```

## 🎯 Pattern Provider-Repository

### Regola Fondamentale

**Per ogni model esiste UN SOLO provider**, e questo provider DEVE utilizzare internamente un repository provider istanziato nella classe repository corrispondente.

### Struttura Repository

#### 1. Repository Abstract (nella feature)

```dart
// features/feature_name/repositories/feature_repository.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/feature_model.dart';
import '../repositories/local_feature_repository.dart';

part 'feature_repository.g.dart';

@Riverpod(keepAlive: true)
Future<FeatureRepository> featureRepository(Ref ref) async {
  // IMPORTANTE: Riverpod 4.x usa Ref invece di FeatureRepositoryRef
  final sharedPreferences = await SharedPreferences.getInstance();
  final repository = LocalFeatureRepository(sharedPreferences);
  await repository.init();
  return repository;
}

abstract class FeatureRepository {
  Future<bool> init();
  Future<void> addFeature(FeatureModel model);
  Future<FeatureModel> getFeatureById(String id);
  Future<List<FeatureModel>> getAllFeatures();
  Future<bool> deleteFeature(String id);
  Future<void> updateFeature(FeatureModel model);
}
```

#### 2. Implementazione Repository (es. Local)

```dart
// features/feature_name/repositories/local_feature_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/feature_model.dart';
import '../repositories/feature_repository.dart';
import '../../../shared/constants/app_constants.dart';

class LocalFeatureRepository implements FeatureRepository {
  final SharedPreferences _sharedPreferences;
  
  LocalFeatureRepository(this._sharedPreferences);
  
  @override
  Future<bool> init() async {
    return true;
  }
  
  @override
  Future<void> addFeature(FeatureModel model) async {
    final features = await getAllFeatures();
    final updatedFeatures = [...features, model];
    await _saveFeatures(updatedFeatures);
  }

  @override
  Future<FeatureModel> getFeatureById(String id) async {
    final features = await getAllFeatures();
    return features.firstWhere((feature) => feature.id == id);
  }

  @override
  Future<List<FeatureModel>> getAllFeatures() async {
    final featuresJson = _sharedPreferences.getStringList(AppConstants.featuresKey) ?? [];
    return featuresJson
        .map((json) => FeatureModel.fromJson(jsonDecode(json)))
        .toList();
  }

  @override
  Future<bool> deleteFeature(String id) async {
    final features = await getAllFeatures();
    features.removeWhere((feature) => feature.id == id);
    await _saveFeatures(features);
    return true;
  }

  @override
  Future<void> updateFeature(FeatureModel model) async {
    final features = await getAllFeatures();
    final index = features.indexWhere((f) => f.id == model.id);
    if (index != -1) {
      final updatedFeature = model.copyWith(updatedAt: DateTime.now());
      features[index] = updatedFeature;
      await _saveFeatures(features);
    }
  }

  Future<void> _saveFeatures(List<FeatureModel> features) async {
    final featuresJson = features.map((f) => jsonEncode(f.toJson())).toList();
    await _sharedPreferences.setStringList(AppConstants.featuresKey, featuresJson);
  }
}
```

### Struttura Provider

#### Provider per Model (Lista)

```dart
// features/feature_name/providers/feature_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/feature_model.dart';
import '../repositories/feature_repository.dart';

part 'feature_provider.g.dart';

@Riverpod(keepAlive: true)
class FeatureNotifier extends _$FeatureNotifier {
  FeatureRepository? repository;

  @override
  Future<List<FeatureModel>> build() async {
    // IMPORTANTE: Il provider usa il repository provider
    repository = await ref.watch(featureRepositoryProvider.future);
    final features = await repository!.getAllFeatures();
    return features;
  }

  Future<void> addFeature(FeatureModel model) async {
    state = const AsyncLoading();
    try {
      await repository!.addFeature(model);
      final features = await repository!.getAllFeatures();
      state = AsyncData(features);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> updateFeature(FeatureModel model) async {
    state = const AsyncLoading();
    try {
      await repository!.updateFeature(model);
      final features = await repository!.getAllFeatures();
      state = AsyncData(features);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteFeature(String id) async {
    state = const AsyncLoading();
    try {
      await repository!.deleteFeature(id);
      final features = await repository!.getAllFeatures();
      state = AsyncData(features);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final features = await repository!.getAllFeatures();
      state = AsyncData(features);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
```

#### Provider con Parametri (Family)

```dart
// features/feature_name/providers/feature_provider.dart
@Riverpod(keepAlive: true)
class FeatureNotifier extends _$FeatureNotifier {
  FeatureRepository? repository;

  @override
  Future<List<FeatureModel>> build(String houseId) async {
    // Provider con parametro (family)
    repository = await ref.watch(featureRepositoryProvider.future);
    final features = await repository!.getFeaturesByHouseId(houseId);
    return features;
  }

  // Metodi che usano il parametro houseId
  Future<void> addFeature(FeatureModel model) async {
    state = const AsyncLoading();
    try {
      await repository!.addFeature(model);
      final features = await repository!.getFeaturesByHouseId(model.houseId);
      state = AsyncData(features);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

// Uso nella view:
// ref.watch(featureProvider(houseId))
// ref.read(featureProvider(houseId).notifier)
```

### Regole Chiave

1. ✅ **Un solo provider per model**: Ogni model ha un unico provider (es. `FeatureNotifier`)
2. ✅ **Provider usa repository provider**: Nel metodo `build()`, il provider DEVE fare `ref.watch(repositoryProvider.future)`
3. ✅ **Repository provider nel repository file**: Il provider del repository (`@Riverpod Future<Repository>`) DEVE essere definito nello stesso file del repository abstract
4. ✅ **keepAlive: true**: Sia il repository provider che il model provider devono avere `keepAlive: true` per mantenere lo stato
5. ✅ **Repository è abstract**: Il repository è una classe abstract con implementazioni concrete separate
6. ✅ **Riverpod 4.x usa `Ref`**: Non più `FeatureRepositoryRef`, usa semplicemente `Ref`

## 📐 Model Pattern

### Struttura Model con Freezed 

```dart
// features/feature_name/model/feature_model.dart
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';

part 'feature_model.freezed.dart';
part 'feature_model.g.dart';

@freezed
class FeatureModel with _$FeatureModel {
  const FeatureModel._();
  
  factory FeatureModel({
    required String id,
    required String name,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _FeatureModel;

  // Metodi di utilità
  factory FeatureModel.empty() {
    return FeatureModel(
      id: '',
      name: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Serializzazione JSON
  factory FeatureModel.fromJson(Map<String, dynamic> json) =>
      _$FeatureModelFromJson(json);
}
```

### Regole Model

1. ✅ Usare `@freezed` per immutabilità
2. ✅ Implementare `fromJson` e `toJson` con `json_serializable`
3. ✅ Fornire factory `empty()` o `initial()` per valori di default
4. ✅ Metodi di utilità nella classe privata `const FeatureModel._()`
5. ✅ **Freezed 3.x**: Aggiungere `// ignore_for_file: non_abstract_class_inherits_abstract_member` all'inizio del file per evitare warning dell'analizzatore

### Enum con Freezed

```dart
enum FeatureCategory {
  @JsonValue('category1')
  category1,
  @JsonValue('category2')
  category2,
}

extension FeatureCategoryExtension on FeatureCategory {
  String get displayName {
    switch (this) {
      case FeatureCategory.category1:
        return 'Categoria 1';
      case FeatureCategory.category2:
        return 'Categoria 2';
    }
  }
}
```

## 🗂️ Data Layer

### Provider per Dati Locali (Opzionale)

Il data layer è opzionale e va usato solo quando serve cache locale separata dal repository.

```dart
// features/feature_name/data/local_feature_data.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/feature_model.dart';

part 'local_feature_data.g.dart';

@Riverpod(keepAlive: true)
class FeatureData extends _$FeatureData {
  @override
  List<FeatureModel> build() {
    return [];
  }
  
  void addFeature(FeatureModel feature) {
    state = [...state, feature];
  }

  void removeFeature(String id) {
    state = state.where((f) => f.id != id).toList();
  }
}
```

## 🎨 ViewModel Pattern

### Quando Usare ViewModel

Il ViewModel è opzionale e va usato quando:
- Serve logica di presentazione complessa
- Serve aggregare dati da più provider
- Serve trasformare dati per la UI
- Serve gestire form complessi

### Struttura ViewModel

```dart
// features/feature_name/viewmodel/feature_view_model.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feature_provider.dart';

final featureViewModelProvider = Provider((ref) => FeatureViewModel(ref));

class FeatureViewModel {
  final Ref ref;
  
  FeatureViewModel(this.ref);
  
  Future<void> loadFeature(String id) async {
    final notifier = ref.read(featureProvider.notifier);
    // Logica complessa di presentazione
  }
  
  // Altri metodi di presentazione...
}
```

## 🖼️ View Pattern

### Struttura View

```dart
// features/feature_name/view/feature_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feature_provider.dart';

class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuresAsync = ref.watch(featureProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Features')),
      body: featuresAsync.when(
        data: (features) {
          if (features.isEmpty) {
            return const Center(child: Text('Nessun elemento'));
          }
          return ListView.builder(
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return ListTile(
                title: Text(feature.name),
                subtitle: feature.description != null 
                    ? Text(feature.description!) 
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Errore: $error'),
              ElevatedButton(
                onPressed: () {
                  ref.read(featureProvider.notifier).refresh();
                },
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigazione o azione
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### View con State (ConsumerStatefulWidget)

```dart
// features/feature_name/view/add_edit_feature_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/feature_model.dart';
import '../providers/feature_provider.dart';

class AddEditFeatureScreen extends ConsumerStatefulWidget {
  final FeatureModel? feature;

  const AddEditFeatureScreen({super.key, this.feature});

  @override
  ConsumerState<AddEditFeatureScreen> createState() => _AddEditFeatureScreenState();
}

class _AddEditFeatureScreenState extends ConsumerState<AddEditFeatureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.feature != null) {
      _nameController.text = widget.feature!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveFeature() {
    if (_formKey.currentState!.validate()) {
      final feature = widget.feature != null
          ? widget.feature!.copyWith(name: _nameController.text.trim())
          : FeatureModel(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      if (widget.feature != null) {
        ref.read(featureProvider.notifier).updateFeature(feature);
      } else {
        ref.read(featureProvider.notifier).addFeature(feature);
      }

      context.pop(); // GoRouter invece di Navigator.pop()
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.feature != null ? 'Modifica' : 'Nuovo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome *'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il nome è obbligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveFeature,
              child: Text(widget.feature != null ? 'Salva' : 'Crea'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🧭 Routing con GoRouter

### Perché GoRouter

GoRouter fornisce:
- **Deep linking**: Aprire schermate specifiche tramite URL
- **Navigazione dichiarativa**: Route definite centralmente
- **Gestione stato**: Back button e browser history
- **Parametri URL**: Passare dati tramite URL

### Configurazione Router

```dart
// core/routing/app_router.dart
import 'package:go_router/go_router.dart';
import '../../features/houses/view/houses_screen.dart';
import '../../features/houses/view/house_detail_screen.dart';
import '../../features/houses/view/add_edit_house_screen.dart';
import '../../features/items/view/add_edit_item_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'houses',
      builder: (context, state) => const HousesScreen(),
    ),
    GoRoute(
      path: '/houses/:id',
      name: 'house-detail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return HouseDetailScreen(houseId: id);
      },
    ),
    GoRoute(
      path: '/houses/new',
      name: 'house-new',
      builder: (context, state) => const AddEditHouseScreen(),
    ),
    GoRoute(
      path: '/houses/:id/edit',
      name: 'house-edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AddEditHouseScreen(houseId: id);
      },
    ),
  ],
);
```

### Navigazione nelle View

#### Navigazione Push (Stack)

```dart
// Navigare a una nuova schermata
context.push('/houses/${house.id}');

// Navigare con parametri
context.push('/houses/$houseId/items/new');
```

#### Navigazione Go (Sostitutiva)

```dart
// Sostituire la schermata corrente
context.go('/houses');

// Torna alla home
context.go('/');
```

#### Tornare Indietro

```dart
// Chiudere la schermata corrente
context.pop();

// Tornare indietro con risultato
context.pop(true);
```

### Passare Parametri

#### Path Parameters

```dart
// Route con parametro
GoRoute(
  path: '/houses/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return HouseDetailScreen(houseId: id);
  },
)

// Navigazione
context.push('/houses/$houseId');
```

#### Query Parameters

```dart
// Route con query parameter
GoRoute(
  path: '/houses',
  builder: (context, state) {
    final filter = state.uri.queryParameters['filter'];
    return HousesScreen(filter: filter);
  },
)

// Navigazione
context.push('/houses?filter=active');
```

#### Extra (Oggetti complessi)

```dart
// Passare oggetti complessi
context.push('/houses/${house.id}', extra: house);

// Ricevere
final house = state.extra as HouseModel;
```

### Best Practices

1. ✅ **Usa nomi per le route**: Facilita la navigazione e il refactoring
2. ✅ **Path parameters per ID**: Usa `:id` invece di query parameters per identificatori
3. ✅ **context.push() per stack**: Usa `push` per navigazione stack normale
4. ✅ **context.go() per sostituzione**: Usa `go` per navigazione sostitutiva (es. login)
5. ✅ **Carica dati dal provider**: Non passare oggetti complessi, carica dai provider usando gli ID
6. ✅ **Gestisci errori**: Verifica che i parametri esistano prima di usarli

### Esempio Completo

```dart
// View che usa GoRouter
class HousesScreen extends ConsumerWidget {
  const HousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(houseProvider);
    
    return Scaffold(
      body: housesAsync.when(
        data: (houses) => ListView.builder(
          itemCount: houses.length,
          itemBuilder: (context, index) {
            final house = houses[index];
            return ListTile(
              title: Text(house.name),
              onTap: () {
                // Navigazione con GoRouter
                context.push('/houses/${house.id}');
              },
            );
          },
        ),
        // ...
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/houses/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## ✅ Checklist per Nuove Feature

Quando crei una nuova feature, segui questo ordine:

1. ✅ Creare la struttura directory: `lib/features/feature_name/{data,model,providers,repositories,viewmodel,view}`
2. ✅ Definire il **model** con Freezed 3.x (con `ignore_for_file`)
3. ✅ Creare il **repository abstract** con il suo provider `@Riverpod` usando `Ref`
4. ✅ Implementare le **implementazioni concrete** del repository (Local, Firebase, API, ecc.)
5. ✅ Creare il **provider del model** che usa il repository provider nel `build()`
6. ✅ Creare il **data provider** (se necessario per cache locale)
7. ✅ Creare il **viewmodel** (se necessario per logica complessa)
8. ✅ Creare le **view** che usano `ConsumerWidget` o `ConsumerStatefulWidget`
9. ✅ Eseguire `dart run build_runner build --delete-conflicting-outputs` per generare i file

## 🔍 Esempio Completo: Feature "Houses"

```
lib/features/houses/
├── data/
│   └── .gitkeep                    # Cartella per cache locale (opzionale)
├── model/
│   ├── house_model.dart            # Model con Freezed
│   ├── house_model.freezed.dart    # Generato
│   └── house_model.g.dart          # Generato
├── providers/
│   ├── house_provider.dart         # Provider che usa houseRepositoryProvider
│   └── house_provider.g.dart       # Generato
├── repositories/
│   ├── house_repository.dart       # Abstract + provider @Riverpod
│   ├── house_repository.g.dart     # Generato
│   └── local_house_repository.dart # Implementazione Local
├── viewmodel/
│   └── .gitkeep                    # Cartella per ViewModel (opzionale)
└── view/
    ├── houses_screen.dart          # Lista case
    ├── add_edit_house_screen.dart  # Form aggiunta/modifica
    └── house_detail_screen.dart    # Dettaglio casa
```

## 🚫 Anti-Pattern da Evitare

1. ❌ **NON** creare provider multipli per lo stesso model
2. ❌ **NON** mettere il repository provider nel file del model provider
3. ❌ **NON** usare architettura layer-first (tutti i model insieme, tutti i provider insieme)
4. ❌ **NON** dimenticare di eseguire `build_runner` dopo modifiche
5. ❌ **NON** accedere direttamente al repository senza passare dal provider
6. ❌ **NON** mettere logica di business nella view
7. ❌ **NON** usare `FeatureRepositoryRef` in Riverpod 4.x (usa `Ref`)
8. ❌ **NON** modificare manualmente i file `.g.dart` e `.freezed.dart`
9. ❌ **NON** usare `Navigator.push/pop` quando si usa GoRouter (usa `context.push/pop`)
10. ❌ **NON** passare oggetti complessi tramite route (usa ID e carica dai provider)

## 📝 Note Aggiuntive

### Riverpod 4.x

- Usa `Ref` invece dei tipi specifici come `FeatureRepositoryRef`
- I provider generati hanno nomi diversi: `houseProvider` invece di `houseNotifierProvider`
- Usa `dart run build_runner` invece di `flutter pub run build_runner`

### Freezed 3.x

- Aggiungi `// ignore_for_file: non_abstract_class_inherits_abstract_member` all'inizio dei file model
- I file generati sono compatibili con Dart 3.x
- Supporta pattern matching nativo di Dart 3.x

### Best Practices

- I file `.g.dart` e `.freezed.dart` sono generati automaticamente e **NON** vanno modificati manualmente
- Usare `keepAlive: true` per provider che devono mantenere lo stato durante la navigazione
- I repository possono dipendere da altri provider (es. auth provider) tramite `ref.watch()`
- Preferire `AsyncValue` per gestire stati di loading/error nei provider
- Usare `ref.watch()` per ascoltare cambiamenti, `ref.read()` per azioni one-time
- Gestire sempre gli errori con try-catch nei metodi dei provider

## 🔧 Troubleshooting

### Errore: "Missing concrete implementations"

**Problema**: L'analizzatore segnala che mancano implementazioni concrete per i getter del mixin.

**Soluzione**: Aggiungi `// ignore_for_file: non_abstract_class_inherits_abstract_member` all'inizio del file model.

### Errore: "Undefined name 'FeatureRepositoryRef'"

**Problema**: Stai usando Riverpod 4.x ma il codice usa la sintassi vecchia.

**Soluzione**: Cambia `FeatureRepositoryRef ref` in `Ref ref` nel repository provider.

### Errore: "Target of URI hasn't been generated"

**Problema**: I file `.g.dart` o `.freezed.dart` non sono stati generati.

**Soluzione**: Esegui `dart run build_runner build --delete-conflicting-outputs`

### Provider non trovato

**Problema**: Il nome del provider generato è diverso da quello che usi.

**Soluzione**: Controlla il file `.g.dart` generato per vedere il nome esatto del provider. In Riverpod 4.x, `FeatureNotifier` genera `featureProvider`, non `featureNotifierProvider`.

## 🔄 Migrazione da Layer-First a Feature-First

Se stai migrando un progetto esistente:

1. Identifica le feature (es. "houses", "items", "auth")
2. Per ogni feature, sposta i file corrispondenti nelle directory della feature
3. Aggiorna gli import in tutti i file
4. Verifica che i provider seguano il pattern repository provider
5. Aggiorna la sintassi per Riverpod 4.x (`Ref` invece di `FeatureRepositoryRef`)
6. Aggiungi `ignore_for_file` ai model per Freezed 3.x
7. Esegui `dart run build_runner build --delete-conflicting-outputs` per rigenerare i file

## 📚 Risorse

- [Riverpod Documentation](https://riverpod.dev/)
- [Freezed Documentation](https://pub.dev/packages/freezed)
- [Riverpod Generator](https://pub.dev/packages/riverpod_generator)
- [Flutter Best Practices](https://docs.flutter.dev/development/data-and-backend/state-mgmt/options)

---

**Ultimo aggiornamento**: Aggiornato per Riverpod 4.x e Freezed 3.x - Dicembre 2024
