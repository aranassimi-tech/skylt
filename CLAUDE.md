# Projekt: Skyltstudio – skyltmjukvara för butiker (digital signage)

Du är en erfaren fullstack-utvecklare. Hjälp mig bygga en webbtjänst för digitala skyltar i butiker. Jag är designer, inte programmerare, så förklara kort vad du gör och varför, och be mig testa efter varje steg.

Filen `demo/skyltstudio-demo.html` i det här projektet är en klickbar demo av hur tjänsten ska kännas: översikten med alla skärmar, dra och släpp, skärmknapparna, editorn, teman och produktlistan. Använd den som referens för flöde och utseende. Mallarna "menu" och "single" i demon visar hur en mall ritas på en fast yta på 1920x1080 och skalas.

## Vad tjänsten gör

Butiker (kaféer, pizzerior, snabbmat) har tv-skärmar som visar menyer, priser och kampanjer. Jag designar färdiga mallar och säsongsteman. Kunden loggar in i en enkel editor och ändrar bara innehållet: vilka produkter som visas, priser och om en kampanj är på. Kunden kan aldrig ändra layout, färger eller typsnitt. Skylten ska alltid se professionell ut.

Jag (superadmin) styr vilka paket, mallar och teman varje kund har tillgång till.

## Teknik

- Next.js (App Router) med TypeScript och Tailwind CSS
- Supabase: Auth, Postgres, Storage och Realtime
- Driftplats: Vercel
- Kod, variabelnamn och kommentarer på engelska. All text i gränssnittet på svenska.
- Håll det enkelt: få beroenden, inga onödiga abstraktioner.

## Tre delar i samma app

1. Adminpanel för mig, under /admin
2. Kundeditor, under /app
3. Spelare för skärmarna, under /play

## Roller

- superadmin: allt
- org_admin: hanterar sin organisations skärmar, produkter och användare inom sitt pakets gränser
- editor: ändrar produkter, priser och kampanjer, inget annat

All behörighet ska upprätthållas med Row Level Security i databasen, inte bara i gränssnittet. En kund får aldrig kunna läsa eller ändra en annan kunds data.

## Datamodell (förslag, förbättra gärna)

- organizations: id, name, package_id, max_screens, is_active
- profiles: id (= auth user), organization_id, role, email
- locations: id, organization_id, name
- packages: id, name, colors (json), fonts (json), logo_url
- templates: id, key, name, orientation (landscape/portrait), field_schema (json)
- themes: id, key, name, default_start (MM-DD), default_end (MM-DD)
- entitlements: id, organization_id, template_id eller theme_id
- products: id, organization_id, name, price, campaign_price, image_url, category, is_active, sort_order
- screens: id, organization_id, location_id, name, orientation, template_id, theme_id, draft_content (json), published_content (json), layout (json: x, y), sort_order, pairing_code, device_token_hash, last_seen_at, published_at
- schedules: id, screen_id, template_id eller theme_id, starts_at, ends_at, weekdays

## Mallar

Varje mall är en React-komponent i koden, registrerad med en nyckel (t.ex. "menu-8", "single-offer"). Varje mall har ett field_schema som beskriver vilka fält kunden får ändra, med typer: text (med maxLength), productList (min/max), product, image, toggle, select.

- Editorn bygger formuläret automatiskt från schemat.
- Mallen ritas alltid på en fast yta 1920x1080 (eller 1080x1920 stående) och skalas med CSS transform för att fylla skärmen.
- Paketets färger, typsnitt och logga sätts som CSS-variabler, så samma mall får kundens stil.
- Spärrar: text krymper automatiskt om den är för lång (med en minsta storlek), bilder beskärs med object-fit: cover, priser formateras enhetligt (t.ex. "35:-").
- Har en produkt kampanjpris och kampanjen är på, visas kampanjpriset med det ordinarie överstruket.

Börja med två mallar: "menu-8" (rubrik + upp till 8 produkter med pris + valfri kampanjbanderoll) och "single-offer" (en stor produkt med bild, pris och kampanjtext).

## Teman

Ett tema är ett lager ovanpå mallen (t.ex. snöfall, pumpor i hörnen) och kan även byta några CSS-variabler. Animationer med CSS eller Canvas, lätta nog för billiga Android-boxar, och avstängda vid prefers-reduced-motion. Teman kan slås på manuellt per skärm eller automatiskt via schedules. Börja med "christmas" (snö) och "halloween" (pumpor).

## Editorn (/app)

- Sidomeny eller toppmeny: Skärmar, Produkter, Inställningar.
- Översikt (startsida): en dashboard med alla skärmar, grupperade per butik. Varje skärm visas som en skalad live-förhandsvisning i rätt format (liggande/stående) med statusprick (online/offline). Kunden kan dra och släppa skärmarna för att placera dem som de sitter i butiken (t.ex. tre bredvid varandra); de fästs mot ett rutnät och placeringen sparas i screens.layout. Klick på en skärm öppnar dess flik. Använd ett etablerat bibliotek för dra och släpp, t.ex. dnd-kit.
- Snabbknappar överst: "Skärm 1", "Skärm 2" osv. (med skärmens namn) som hoppar direkt till respektive skärm.
- På mobil: visa skärmarna som en lista i stället för dra-och-släpp-ytan.
- Knapp "Publicera alla" som publicerar utkast på flera skärmar samtidigt.
- Skärmflik: en per skärm. Varje flik visar en live-förhandsvisning av utkastet, vald mall (bara mallar kunden har tillgång till), tema och formuläret från fältschemat.
- Ändringar sparas som utkast (draft_content) och syns på skärmen först när man klickar på "Publicera" (kopieras till published_content).
- Produkter: en gemensam lista per organisation (namn, pris, kampanjpris, bild, kategori). Ändras ett pris här syns det på alla skärmar som visar produkten. Visa vilka skärmar varje produkt syns på.
- Status per skärm: online (livssignal senaste 10 min) eller offline.
- Gränssnittet ska vara mycket enkelt, stora knappar, fungera på mobil.

## Spelaren (/play)

- Ny skärm: visar en kod på 6 tecken. Kunden anger koden i editorn under "Lägg till skärm". Därefter får skärmen en hemlig device token som sparas i webbläsaren (spara bara en hash i databasen).
- Skärmen har ingen användarinloggning. Den hämtar sitt innehåll via en serverfunktion som kontrollerar token och bara returnerar den skärmens publicerade innehåll.
- Uppdateringar: lyssna på Supabase Realtime för sin skärm, och fråga dessutom servern var 60:e sekund som reserv.
- Livssignal var 5:e minut (uppdaterar last_seen_at).
- Offline: cacha senaste innehåll och bilder med en service worker. Utan internet visas det senast publicerade. Skärmen får aldrig bli svart eller visa ett felmeddelande.
- Ingen muspekare, inga scrollbars, helskärm.

## Adminpanelen (/admin)

- Skapa och redigera organisationer, bjud in deras första användare via e-post.
- Skapa paket (färger, typsnitt, logga).
- Tilldela mallar och teman till organisationer.
- Se alla skärmar och deras status.
- "Logga in som kund" för support (tydligt markerat).

## Arbetssätt

Bygg i den här ordningen. Stanna efter varje steg, förklara hur jag testar, och vänta på mitt OK:

1. Projektupplägg, Supabase-anslutning, inloggning, tabeller och RLS-regler (som migreringsfiler). Lägg in exempeldata: en kund "Café Kanel" med fyra skärmar och produkter som i demon.
2. Spelaren med mallen "menu-8" och innehåll från databasen, skalad till skärmen.
3. Editorn: produkter, översikt (dashboard) med dra och släpp, skärmknappar, skärmflikar, formulär från schema, förhandsvisning, Publicera och Publicera alla.
4. Parkoppling med kod, Realtime-uppdatering, offline-läge.
5. Adminpanelen.
6. Teman och schemaläggning.
7. Statusvakt och e-post när en skärm varit offline över 30 minuter.

## Krav på kvalitet

- Använd Git och gör en commit efter varje fungerande steg.
- Lagra aldrig hemliga nycklar i koden; använd miljövariabler och en .env.example.
- Skriv en kort README om hur man kör projektet lokalt och publicerar.
- Testa RLS-reglerna: visa att en användare i en organisation inte kan läsa en annans data.
- Om något är oklart, fråga mig hellre än att gissa.
