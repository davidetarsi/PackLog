-- Catalogo dei tag (fase 5, spec del 31 ottobre 2026): tipi, usi, stile,
-- colori, livelli di calore e pioggia, attivita' e alloggi del viaggio. Lo
-- leggono l'app e le Edge Functions; lo scrive solo Davide (dashboard o SQL),
-- quindi nessuna policy di scrittura.
--
-- REGOLE DEL CATALOGO (valgono per chi modifica le righe dalla dashboard o da SQL):
--   1. Mai DELETE: una voce che non si propone piu' si disattiva (active = false).
--      I viaggi e i capi salvati la tengono: le funzioni traducono l'id di una
--      voce disattivata nei suoi testi di sempre; se la riga sparisse, l'id
--      arriverebbe al generatore come testo e il suo significato andrebbe perso
--      senza errori.
--   2. L'id non si cambia mai: e' il valore salvato nei viaggi e nei capi. Un id
--      nuovo e' una voce nuova (e la vecchia si disattiva).
--   3. Una voce non cambia mai significato: un significato nuovo e' una voce
--      nuova e la vecchia si disattiva. Ai testi del generatore di una voce si
--      aggiunge solo cio' che lascia identica la valigia.
--   4. Dopo questa migrazione i cambi si fanno nella TABELLA, mai con migrazioni
--      nuove; il file del repo (catalogo.json) si riallinea con lo script
--      esporta_catalogo.mjs. Il seed qui sotto e' solo INIZIALE: nasce da
--      supabase/functions/_shared/catalogo/catalogo_seed_iniziale.json
--      (seed_sql.mjs) e non segue piu' catalogo.json.
--
-- A ogni modifica il trigger alza app_config.catalog_version: l'app e le
-- funzioni scaricano di nuovo il catalogo solo quando cambia.
--
-- Rilanciare questa migrazione (db push non lo fa per una gia' applicata) non e'
-- neutro: le righe del seed cancellate a mano tornano, e il trigger FOR EACH
-- STATEMENT scatta anche se l'INSERT ... ON CONFLICT DO NOTHING non inserisce
-- nulla, quindi la versione sale di uno e le app riscaricano il catalogo.

CREATE TABLE IF NOT EXISTS public.catalog_entries (
  domain     text        NOT NULL,
  id         text        NOT NULL,
  sort       integer     NOT NULL,
  active     boolean     NOT NULL DEFAULT true,
  label_it   text        NOT NULL,
  label_en   text        NOT NULL,
  data       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (domain, id)
);

ALTER TABLE public.catalog_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read catalog_entries" ON public.catalog_entries;
CREATE POLICY "Authenticated users can read catalog_entries"
  ON public.catalog_entries
  FOR SELECT
  TO authenticated
  USING (true);

INSERT INTO public.app_config (key, value) VALUES ('catalog_version', '1')
ON CONFLICT (key) DO NOTHING;

-- Una modifica (anche di piu' righe insieme) alza la versione di uno.
CREATE OR REPLACE FUNCTION public.catalog_entries_bump_version()
RETURNS trigger AS $$
BEGIN
  UPDATE public.app_config
     SET value = (COALESCE(NULLIF(value, '')::int, 0) + 1)::text
   WHERE key = 'catalog_version';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- La data dell'ultima modifica della riga.
CREATE OR REPLACE FUNCTION public.catalog_entries_touch()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Il seed qui sotto non conta come modifica solo al primo giro: i trigger si creano
-- dopo (al secondo giro esistono gia', vedi sopra).
INSERT INTO public.catalog_entries (domain, id, sort, active, label_it, label_en, data) VALUES
  ('clothing_group', 'Upper Body', 10, true, 'Sopra', 'Tops', '{}'::jsonb),
  ('clothing_group', 'Lower Body', 20, true, 'Sotto', 'Bottoms', '{}'::jsonb),
  ('clothing_group', 'Full Body', 30, true, 'Abito intero', 'Full body', '{}'::jsonb),
  ('clothing_group', 'Shoes', 40, true, 'Scarpe', 'Shoes', '{}'::jsonb),
  ('clothing_group', 'Outerwear', 50, true, 'Giacche', 'Outerwear', '{}'::jsonb),
  ('clothing_group', 'Accessory', 60, true, 'Accessori', 'Accessories', '{}'::jsonb),
  ('clothing_group', 'Essentials', 70, true, 'Essenziali', 'Essentials', '{}'::jsonb),
  ('clothing_type', 'T-Shirt', 10, true, 'T-shirt', 'T-shirt', '{"group":"Upper Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Shirt', 20, true, 'Camicia', 'Shirt', '{"group":"Upper Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Polo', 30, true, 'Polo', 'Polo', '{"group":"Upper Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Hoodie', 40, true, 'Felpa con cappuccio', 'Hoodie', '{"group":"Upper Body","parent":null,"isNew":false,"hint":"felpa con cappuccio"}'::jsonb),
  ('clothing_type', 'Sweatshirt', 50, true, 'Felpa', 'Sweatshirt', '{"group":"Upper Body","parent":null,"isNew":false,"hint":"felpa senza cappuccio"}'::jsonb),
  ('clothing_type', 'Sweater', 60, true, 'Maglione', 'Sweater', '{"group":"Upper Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Tank Top', 70, true, 'Canottiera', 'Tank top', '{"group":"Upper Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Crop Top', 80, true, 'Top corto', 'Crop top', '{"group":"Upper Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Thermal Top', 90, true, 'Maglia termica', 'Thermal top', '{"group":"Upper Body","parent":"T-Shirt","isNew":true,"hint":"maglia termica, strato base"}'::jsonb),
  ('clothing_type', 'Fleece', 100, true, 'Pile', 'Fleece', '{"group":"Upper Body","parent":"Sweater","isNew":true,"hint":"pile"}'::jsonb),
  ('clothing_type', 'Jeans', 110, true, 'Jeans', 'Jeans', '{"group":"Lower Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Shorts', 120, true, 'Pantaloncini', 'Shorts', '{"group":"Lower Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Trousers', 130, true, 'Pantaloni', 'Trousers', '{"group":"Lower Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Leggings', 140, true, 'Leggings', 'Leggings', '{"group":"Lower Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Skirt', 150, true, 'Gonna', 'Skirt', '{"group":"Lower Body","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Sweatpants', 160, true, 'Pantaloni della tuta', 'Sweatpants', '{"group":"Lower Body","parent":null,"isNew":false,"hint":"pantaloni della tuta; in italiano ''tuta'' e'' sempre questo"}'::jsonb),
  ('clothing_type', 'Swimwear', 170, true, 'Costume', 'Swimwear', '{"group":"Lower Body","parent":null,"isNew":false,"hint":"costume da bagno, bikini"}'::jsonb),
  ('clothing_type', 'Thermal Bottoms', 180, true, 'Calzamaglia termica', 'Thermal bottoms', '{"group":"Lower Body","parent":null,"isNew":true,"hint":"calzamaglia o pantaloni termici"}'::jsonb),
  ('clothing_type', 'Ski Pants', 190, true, 'Pantaloni da sci', 'Ski pants', '{"group":"Lower Body","parent":null,"isNew":true,"hint":"pantaloni da sci o salopette"}'::jsonb),
  ('clothing_type', 'Wetsuit', 200, true, 'Muta', 'Wetsuit', '{"group":"Lower Body","parent":null,"isNew":true,"hint":"muta da sub o da surf"}'::jsonb),
  ('clothing_type', 'Dress', 210, true, 'Vestito', 'Dress', '{"group":"Full Body","parent":null,"isNew":true,"hint":"vestito o abito da donna, copre sopra e sotto"}'::jsonb),
  ('clothing_type', 'Sneakers', 220, true, 'Sneakers', 'Sneakers', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Sandals', 230, true, 'Sandali', 'Sandals', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Boots', 240, true, 'Stivali', 'Boots', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Flip-Flops', 250, true, 'Infradito', 'Flip-flops', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Loafers', 260, true, 'Mocassini', 'Loafers', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Dress Shoes', 270, true, 'Scarpe eleganti', 'Dress shoes', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Hiking Boots', 280, true, 'Scarponi da trekking', 'Hiking boots', '{"group":"Shoes","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Water Shoes', 290, true, 'Scarpe da scoglio', 'Water shoes', '{"group":"Shoes","parent":"Sandals","isNew":true,"hint":"scarpe da acqua o da scoglio"}'::jsonb),
  ('clothing_type', 'Snow Boots', 300, true, 'Doposci', 'Snow boots', '{"group":"Shoes","parent":"Boots","isNew":true,"hint":"doposci o scarponi da neve"}'::jsonb),
  ('clothing_type', 'Coat', 310, true, 'Cappotto', 'Coat', '{"group":"Outerwear","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Rain Jacket', 320, true, 'Giacca impermeabile', 'Rain jacket', '{"group":"Outerwear","parent":null,"isNew":false,"hint":"giacca antipioggia, guscio impermeabile"}'::jsonb),
  ('clothing_type', 'Down Jacket', 330, true, 'Piumino', 'Down jacket', '{"group":"Outerwear","parent":null,"isNew":false,"hint":"piumino"}'::jsonb),
  ('clothing_type', 'Windbreaker', 340, true, 'Giacca a vento', 'Windbreaker', '{"group":"Outerwear","parent":null,"isNew":false,"hint":"giacca a vento, k-way, softshell"}'::jsonb),
  ('clothing_type', 'Blazer', 350, true, 'Blazer', 'Blazer', '{"group":"Outerwear","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Ski Jacket', 360, true, 'Giacca da sci', 'Ski jacket', '{"group":"Outerwear","parent":"Down Jacket","isNew":true,"hint":"giacca da sci"}'::jsonb),
  ('clothing_type', 'Ski Suit', 370, true, 'Tuta da sci', 'Ski suit', '{"group":"Outerwear","parent":"Down Jacket","isNew":true,"hint":"tuta da sci intera, copre anche le gambe"}'::jsonb),
  ('clothing_type', 'Casual Jacket', 380, true, 'Giubbotto', 'Casual jacket', '{"group":"Outerwear","parent":null,"isNew":true,"hint":"giacca casual: di jeans, bomber, giacca camicia"}'::jsonb),
  ('clothing_type', 'Vest', 390, true, 'Gilet', 'Vest', '{"group":"Outerwear","parent":null,"isNew":true,"hint":"gilet o smanicato"}'::jsonb),
  ('clothing_type', 'Cap/Hat', 400, true, 'Cappello', 'Hat', '{"group":"Accessory","parent":null,"isNew":false,"hint":"cappello, berretto, cuffia di lana"}'::jsonb),
  ('clothing_type', 'Belt', 410, true, 'Cintura', 'Belt', '{"group":"Accessory","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Bag', 420, true, 'Borsa', 'Bag', '{"group":"Accessory","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Scarf', 430, true, 'Sciarpa', 'Scarf', '{"group":"Accessory","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Sunglasses', 440, true, 'Occhiali da sole', 'Sunglasses', '{"group":"Accessory","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Jewelry', 450, true, 'Gioielli', 'Jewelry', '{"group":"Accessory","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Watch', 460, true, 'Orologio', 'Watch', '{"group":"Accessory","parent":null,"isNew":false,"hint":null}'::jsonb),
  ('clothing_type', 'Gloves', 470, true, 'Guanti', 'Gloves', '{"group":"Accessory","parent":null,"isNew":true,"hint":"guanti"}'::jsonb),
  ('clothing_type', 'Tie', 480, true, 'Cravatta', 'Tie', '{"group":"Accessory","parent":null,"isNew":true,"hint":"cravatta o papillon"}'::jsonb),
  ('clothing_type', 'Umbrella', 490, true, 'Ombrello', 'Umbrella', '{"group":"Accessory","parent":null,"isNew":true,"hint":"ombrello"}'::jsonb),
  ('clothing_type', 'Underwear', 500, true, 'Intimo', 'Underwear', '{"group":"Essentials","parent":null,"isNew":true,"hint":"mutande, boxer, reggiseno, canottiera intima"}'::jsonb),
  ('clothing_type', 'Socks', 510, true, 'Calzini', 'Socks', '{"group":"Essentials","parent":null,"isNew":true,"hint":"calze e calzini"}'::jsonb),
  ('clothing_type', 'Pajamas', 520, true, 'Pigiama', 'Pajamas', '{"group":"Essentials","parent":null,"isNew":true,"hint":"pigiama"}'::jsonb),
  ('clothing_type', 'Other', 530, true, 'Altro', 'Other', '{"group":null,"parent":null,"isNew":false,"hint":null,"everyGroup":true}'::jsonb),
  ('use', 'Everyday', 10, true, 'Tutti i giorni', 'Everyday', '{"prompt":"worn in town on normal days (NOT for items meant only for the office, elegant evenings, sport, the beach or home)","promptOrder":0}'::jsonb),
  ('use', 'Office', 20, true, 'Ufficio', 'Office', '{"prompt":"fit for an office: polos, chinos, wool sweaters, cotton dress shirts, blazers, tailored trousers, coats and trench coats, loafers, ankle boots, dress shoes, leather belts, watches","promptOrder":1}'::jsonb),
  ('use', 'Beach', 30, true, 'Mare', 'Beach', '{"prompt":"seaside and hot holidays: anything in linen, light cotton summer trousers, bermuda, tank tops, short-sleeve summer shirts, summer dresses, sandals, flip-flops, swimwear","promptOrder":3}'::jsonb),
  ('use', 'Swimming', 40, true, 'Nuoto', 'Swimming', '{"prompt":"worn in the water or at the pool: swimwear, water shoes, pool slides, wetsuits","promptOrder":4}'::jsonb),
  ('use', 'Hiking', 50, true, 'Montagna', 'Hiking', '{"prompt":"trekking and mountains: trekking trousers, hiking boots, trail shoes, technical fleece, base layers, windbreakers, rain jackets, light down jackets, wool or trekking socks","promptOrder":5}'::jsonb),
  ('use', 'Sport', 60, true, 'Sport', 'Sport', '{"prompt":"sport and running: technical t-shirts, running shorts and shoes, sport leggings, base layers, ski clothes","promptOrder":6}'::jsonb),
  ('use', 'Formal', 70, true, 'Elegante', 'Formal', '{"prompt":"elegant evenings and ceremonies: cotton or elegant dress shirts, suits, tailored trousers, wool coats, dress shoes, heels, fine jewelry, evening bags","promptOrder":2}'::jsonb),
  ('use', 'Lounge', 80, true, 'Casa', 'Lounge', '{"prompt":"at home: pajamas, sweatpants, hoodies, robes","promptOrder":7}'::jsonb),
  ('formality', 'Loungewear', 10, true, 'Da casa', 'Loungewear', '{"prompt":"for home and sport, not for going out: pajamas, sweatpants, underwear, pool slides, flip-flops, technical or running t-shirts, sport shorts, sport leggings, base layers, sport swimsuits, running shoes, sport accessories"}'::jsonb),
  ('formality', 'Casual', 20, true, 'Casual', 'Casual', '{"prompt":"everyday: t-shirts, cotton shorts and bermuda, jeans, cargo and trekking trousers, hoodies, sweatshirts, fleece, parkas, sneakers, sandals, swimwear, caps"}'::jsonb),
  ('formality', 'Smart Casual', 30, true, 'Curato', 'Smart casual', '{"prompt":"neat but not office: polos, linen shirts, chinos, knit sweaters, cardigans, trench coats, loafers, ankle boots, leather belts, simple watches and jewelry"}'::jsonb),
  ('formality', 'Business', 40, true, 'Lavoro', 'Business', '{"prompt":"office: cotton dress shirts, tailored trousers, blazers, wool coats, brown dress shoes, work bags"}'::jsonb),
  ('formality', 'Formal', 50, true, 'Elegante', 'Formal', '{"prompt":"ceremonies and elegant evenings: shirts sold as elegant, suit jackets and trousers, long black coats, black dress shoes, heels, evening bags, fine jewelry"}'::jsonb),
  ('color', 'Bianco', 10, true, 'Bianco', 'White', '{"synonyms":["panna","avorio","white"]}'::jsonb),
  ('color', 'Nero', 20, true, 'Nero', 'Black', '{"synonyms":["black"]}'::jsonb),
  ('color', 'Grigio', 30, true, 'Grigio', 'Grey', '{"synonyms":["antracite","grey","gray"]}'::jsonb),
  ('color', 'Blu', 40, true, 'Blu', 'Blue', '{"synonyms":["denim","blue"]}'::jsonb),
  ('color', 'Marrone', 50, true, 'Marrone', 'Brown', '{"synonyms":["brown"]}'::jsonb),
  ('color', 'Beige', 60, true, 'Beige', 'Beige', '{"synonyms":["crema","cammello","kaki","cachi","tortora"]}'::jsonb),
  ('color', 'Blu navy', 70, true, 'Blu navy', 'Navy', '{"synonyms":["blu scuro","blu notte","navy","navy blue"]}'::jsonb),
  ('color', 'Azzurro', 80, true, 'Azzurro', 'Light blue', '{"synonyms":["celeste","light blue"]}'::jsonb),
  ('color', 'Verde', 90, true, 'Verde', 'Green', '{"synonyms":["green"]}'::jsonb),
  ('color', 'Rosso', 100, true, 'Rosso', 'Red', '{"synonyms":["red"]}'::jsonb),
  ('color', 'Bordeaux', 110, true, 'Bordeaux', 'Burgundy', '{"synonyms":["bordò","burgundy"]}'::jsonb),
  ('color', 'Rosa', 120, true, 'Rosa', 'Pink', '{"synonyms":["fucsia","pink"]}'::jsonb),
  ('color', 'Giallo', 130, true, 'Giallo', 'Yellow', '{"synonyms":["yellow"]}'::jsonb),
  ('color', 'Arancione', 140, true, 'Arancione', 'Orange', '{"synonyms":["orange"]}'::jsonb),
  ('color', 'Viola', 150, true, 'Viola', 'Purple', '{"synonyms":["lilla","porpora","purple"]}'::jsonb),
  ('color', 'Multicolore', 160, true, 'Multicolore', 'Multicolour', '{"synonyms":["multicolor","fantasia","multicolour","multicolored","multicoloured"]}'::jsonb),
  ('warmth', '1', 10, true, 'Molto leggero', 'Very light', '{}'::jsonb),
  ('warmth', '2', 20, true, 'Leggero', 'Light', '{}'::jsonb),
  ('warmth', '3', 30, true, 'Medio', 'Medium', '{}'::jsonb),
  ('warmth', '4', 40, true, 'Caldo', 'Warm', '{}'::jsonb),
  ('warmth', '5', 50, true, 'Molto caldo', 'Very warm', '{}'::jsonb),
  ('water', '0', 10, true, 'Si bagna', 'Not waterproof', '{}'::jsonb),
  ('water', '1', 20, true, 'Pioggia leggera', 'Light rain', '{}'::jsonb),
  ('water', '2', 30, true, 'Impermeabile', 'Waterproof', '{}'::jsonb),
  ('activity', 'city', 10, true, 'Città e musei', 'Cities and museums', '{"generator":["visite in citta"]}'::jsonb),
  ('activity', 'walks', 20, true, 'Passeggiate nella natura', 'Nature walks', '{"generator":["escursioni leggere"]}'::jsonb),
  ('activity', 'trekking', 30, true, 'Trekking', 'Trekking', '{"generator":["trekking"]}'::jsonb),
  ('activity', 'cammino', 40, true, 'Cammino di più giorni', 'Multi-day walk', '{"generator":["cammino"]}'::jsonb),
  ('activity', 'sea', 50, true, 'Mare', 'Sea', '{"generator":["mare"]}'::jsonb),
  ('activity', 'diving', 60, true, 'Immersioni e snorkeling', 'Diving and snorkeling', '{"generator":["immersioni","mare"]}'::jsonb),
  ('activity', 'ski', 70, true, 'Sci e neve', 'Skiing and snow', '{"generator":["sci"]}'::jsonb),
  ('activity', 'camping', 80, true, 'Campeggio', 'Camping', '{"generator":["campeggio"]}'::jsonb),
  ('activity', 'work', 90, true, 'Lavoro', 'Work', '{"generator":["riunioni di lavoro"]}'::jsonb),
  ('activity', 'evenings', 100, true, 'Cene e serate', 'Dinners and evenings out', '{"generator":["cene al ristorante","vita notturna"]}'::jsonb),
  ('activity', 'wedding', 110, true, 'Matrimoni e cerimonie', 'Weddings and ceremonies', '{"generator":["matrimonio"]}'::jsonb),
  ('activity', 'worship', 120, true, 'Luoghi di culto', 'Places of worship', '{"generator":["visite a siti religiosi"]}'::jsonb),
  ('activity', 'spa', 130, true, 'Terme', 'Spa', '{"generator":["terme"]}'::jsonb),
  ('activity', 'high_mountain', 140, false, 'Alta montagna', 'High mountains', '{"generator":["escursioni in quota"]}'::jsonb),
  ('activity', 'formal_dinner', 150, false, 'Cena elegante', 'Elegant dinner', '{"generator":["cena formale"]}'::jsonb),
  ('activity', 'nightlife', 160, false, 'Serate e locali', 'Nightlife', '{"generator":["vita notturna"]}'::jsonb),
  ('activity', 'cycling', 170, false, 'Bicicletta', 'Cycling', '{"generator":["bicicletta"]}'::jsonb),
  ('stay', 'hotel', 10, true, 'Hotel', 'Hotel', '{"generator":"hotel"}'::jsonb),
  ('stay', 'apartment', 20, true, 'Appartamento', 'Apartment', '{"generator":"appartamento"}'::jsonb),
  ('stay', 'hostel', 30, true, 'Ostello', 'Hostel', '{"generator":"ostello"}'::jsonb),
  ('stay', 'camping', 40, true, 'Campeggio', 'Campsite', '{"generator":"campeggio"}'::jsonb),
  ('stay', 'friends', 50, true, 'Da amici o parenti', 'Friends or family', '{"generator":"da amici o parenti"}'::jsonb)
ON CONFLICT (domain, id) DO NOTHING;

DROP TRIGGER IF EXISTS catalog_entries_touch ON public.catalog_entries;
CREATE TRIGGER catalog_entries_touch
  BEFORE UPDATE ON public.catalog_entries
  FOR EACH ROW EXECUTE FUNCTION public.catalog_entries_touch();

DROP TRIGGER IF EXISTS catalog_entries_bump_version ON public.catalog_entries;
CREATE TRIGGER catalog_entries_bump_version
  AFTER INSERT OR UPDATE OR DELETE ON public.catalog_entries
  FOR EACH STATEMENT EXECUTE FUNCTION public.catalog_entries_bump_version();
