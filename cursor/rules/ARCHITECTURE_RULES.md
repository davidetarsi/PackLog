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
