/// Tipo di località geografica
enum LocationType {
  /// Città, paese o villaggio
  city('Città'),
  /// Stato, regione o provincia
  state('Regione'),
  /// Nazione/Paese
  country('Paese'),
  /// Altro tipo non classificato
  other('Altro');

  final String displayName;
  const LocationType(this.displayName);
}
