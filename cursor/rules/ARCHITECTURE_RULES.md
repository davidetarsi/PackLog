# Architecture Rules - Flutter + Riverpod (Optimized)

## 🏗️ Feature-First Structure

lib/features/[feature]/{model, providers, repositories, view}
lib/shared/ - Shared components
lib/core/ - Theme, routing, database

## 📋 Core Rules

### Provider-Repository Pattern
- ONE provider per model
- Provider uses Repository → Repository uses DAO/DataSource
- @Riverpod(keepAlive: true) for data providers

### State Management
```dart
@riverpod
class FeatureNotifier extends _$FeatureNotifier {
  @override
  FutureOr<List<Model>> build() => repo.getAll();
  
  Future<void> add(Model item) async {
    state = AsyncLoading();
    state = await AsyncValue.guard(() => repo.add(item).then((_) => repo.getAll()));
  }
}
```

### Models (Freezed)
```dart
@freezed
class Model with _$Model {
  const Model._();
  factory Model({required String id}) = _Model;
  factory Model.fromJson(Map<String, dynamic> json) => _$ModelFromJson(json);
}
```

## 🎨 UI Patterns

- Use ConsumerWidget/ConsumerStatefulWidget
- ref.watch(provider) for rebuilds
- ref.read(provider.notifier).method() for actions
- AsyncValue.when(data:, loading:, error:)
- Theme: context.spacingMd, Theme.of(context).colorScheme

## 🔧 Commands

dart run build_runner build --delete-conflicting-outputs

## 🗄️ Database (Drift)

- Tables in lib/core/database/tables/
- DAOs in lib/core/database/daos/
- Repositories use DAOs
- Increment schemaVersion for migrations

## ⚠️ Avoid

- Multiple providers per model
- Direct DB access from UI
- Skipping build_runner
- Using String for enums (use ItemCategory enum)
- Using deprecated destinationLocationName

## 📱 Domain

- Items: belong to houses, can be in trips
- Trips: contain TripItem snapshots
- TripItem: immutable (category, isChecked, originHouseId)
- ItemModel: mutable (description, timestamps)

## 🚀 Production Build & Pilot Launch

### Build di Produzione (Android App Bundle)

```bash
flutter build appbundle \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --release
```

- `--obfuscate`: offusca il codice Dart compilato (protegge IP e riduce reverse engineering)
- `--split-debug-info=build/debug-info`: separa i simboli di debug per deobfuscazione stack trace in Sentry/Crashlytics
- Output: `build/app/outputs/bundle/release/app-release.aab`

### Upload su Google Play Console

**Raccomandazione: Internal Testing PRIMA della Produzione.**

1. **Google Play Console** → App → Release → Testing → Internal testing
2. Crea una nuova release, carica il `.aab`
3. Aggiungi i tester interni (email list, max 100 utenti)
4. Attendi feedback e monitora crash via Sentry + Play Console Vitals
5. Solo dopo validazione: promuovi la release a **Closed testing** → **Open testing** → **Production**

### Checklist Pre-Release

- [ ] Verificare che le variabili d'ambiente Supabase puntino a produzione
- [ ] Verificare che Sentry DSN sia configurato per l'environment `production`
- [ ] Eseguire `flutter test` con tutti i test green
- [ ] Testare manualmente il flusso offline → online (airplane mode)
- [ ] Caricare `build/debug-info/` su Sentry per deobfuscazione simboli
