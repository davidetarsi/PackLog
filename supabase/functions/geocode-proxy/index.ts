import "@supabase/functions-js/edge-runtime.d.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const apiKey = Deno.env.get("GEOAPIFY_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "GEOAPIFY_KEY not configured" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }

  const url = new URL(req.url);
  const text = url.searchParams.get("text");
  const lang = url.searchParams.get("lang") ?? "en";
  const limit = url.searchParams.get("limit") ?? "15";
  const bias = url.searchParams.get("bias") ?? "countrycode:none";

  if (!text) {
    return new Response(
      JSON.stringify({ error: "Missing 'text' parameter" }),
      { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }

  const geoapifyUrl = new URL("https://api.geoapify.com/v1/geocode/autocomplete");
  geoapifyUrl.searchParams.set("text", text);
  geoapifyUrl.searchParams.set("apiKey", apiKey);
  geoapifyUrl.searchParams.set("lang", lang);
  geoapifyUrl.searchParams.set("limit", limit);
  geoapifyUrl.searchParams.set("bias", bias);

  const response = await fetch(geoapifyUrl.toString());
  const data = await response.json();

  return new Response(
    JSON.stringify(data),
    {
      status: response.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    },
  );
});
