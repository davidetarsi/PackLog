/// Verifica il form viaggio e restituisce la **chiave di traduzione**
/// dell'errore, o `null` se il viaggio è salvabile.
///
/// Restituisce la chiave e non il messaggio per restare una funzione pura:
/// testabile senza easy_localization e senza widget.
///
/// L'unico campo obbligatorio è la data di partenza. Senza,
/// `TripModel.status` restituisce `upcoming` per sempre e il viaggio non
/// passa mai in "Past".
String? tripFormError({
  required DateTime? departureDateTime,
  required DateTime? returnDateTime,
}) {
  if (departureDateTime == null) return 'trips.departure_date_required';
  if (returnDateTime != null && returnDateTime.isBefore(departureDateTime)) {
    return 'common.return_before_departure_error';
  }
  return null;
}
