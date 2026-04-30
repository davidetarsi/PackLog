import '../model/item_model.dart';

// ==========================================
// 1. L'Interfaccia del Dizionario (Astrazione)
// ==========================================
abstract class CategoryDictionary {
  Set<String> get stopWords;
  Map<String, ItemCategory> get exactMatches;
  List<({String root, ItemCategory category})> get rootKeywords;

  /// Riduce la parola alla sua forma base/singolare
  String lemmatize(String word);
}