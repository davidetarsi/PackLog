// Il blocco immagine per Claude dal base64 che manda l'app. Il tipo si legge
// dai primi byte: image_picker manda JPEG, ma l'API vuole il tipo giusto.
export function bloccoImmagine(base64: string) {
  const tipo: "image/png" | "image/gif" | "image/webp" | "image/jpeg" = base64.startsWith("iVBOR")
    ? "image/png"
    : base64.startsWith("R0lGOD")
    ? "image/gif"
    : base64.startsWith("UklGR")
    ? "image/webp"
    : "image/jpeg";
  return { type: "image" as const, source: { type: "base64" as const, media_type: tipo, data: base64 } };
}
