/// Verifica il form viaggio e restituisce la **chiave di traduzione**
/// dell'errore, o `null` se il viaggio è salvabile.
///
/// Restituisce la chiave e non il messaggio per restare una funzione pura:
/// testabile senza easy_localization e senza widget.
///
/// Due obblighi:
///
/// 1. **Un'identità**: nome scritto a mano *oppure* destinazione. Almeno uno
///    dei due, non entrambi — un viaggio chiamato "Da mio fratello" non ha
///    bisogno di una destinazione, e uno diretto a Roma non ha bisogno di un
///    nome, perché lo prende dalla destinazione stessa.
/// 2. **La data di partenza**: senza, `TripModel.status` restituisce
///    `upcoming` per sempre e il viaggio non passa mai in "Past".
///
/// [name] e [hasDestination] sono richiesti entrambi anche se oggi il nome
/// derivato *è* la destinazione: legarli qui renderebbe la validazione
/// dipendente da quella coincidenza, e basterebbe cambiare il criterio del
/// nome derivato per farla franare in silenzio.
String? tripFormError({
  required String? name,
  required bool hasDestination,
  required DateTime? departureDateTime,
  required DateTime? returnDateTime,
}) {
  final hasName = name?.trim().isNotEmpty ?? false;
  if (!hasName && !hasDestination) return 'trips.name_or_destination_required';
  if (departureDateTime == null) return 'trips.departure_date_required';
  if (returnDateTime != null && returnDateTime.isBefore(departureDateTime)) {
    return 'common.return_before_departure_error';
  }
  return null;
}
