# Skyltstudio

Webbtjänst för digitala skyltar i butiker. En app med tre delar:

| Del | Adress | För vem |
| --- | --- | --- |
| Kundeditor | `/app` | Kunden (org_admin, editor) |
| Adminpanel | `/admin` | Superadmin |
| Spelare | `/play` | Skärmarna i butiken (ingen inloggning) |

Teknik: Next.js (App Router) + TypeScript + Tailwind, Supabase (Auth, Postgres, Storage, Realtime), Vercel.
Kravspecen finns i `CLAUDE.md` och den klickbara demon i `demo/skyltstudio-demo.html`.

## Mappar

- `src/app` – sidorna (`login`, `app`, `admin`, `play`)
- `src/lib/supabase` – anslutning till Supabase (webbläsare, server, middleware)
- `supabase/migrations` – tabeller och behörighetsregler (RLS)
- `supabase/seed.sql` – exempeldata: Café Kanel (4 skärmar, 11 produkter) och Pizzeria Napoli
- `supabase/tests/rls.test.sql` – tester som visar att kunder inte ser varandras data
- `scripts/seed-users.mjs` – skapar exempelkonton

## Köra lokalt

Kräver Node 20+.

1. Installera beroenden:
   ```bash
   npm install
   ```
2. Skapa ett Supabase-projekt på [supabase.com](https://supabase.com) (gratisnivån räcker).
   Under **Authentication → Sign In / Providers**: stäng av **Allow new users to sign up**
   (kunder bjuds in, de registrerar sig inte själva).
3. Kopiera miljöfilen och fyll i värdena från **Project Settings → API**:
   ```bash
   cp .env.example .env.local
   ```
4. Lägg in tabeller, regler och exempeldata. Antingen med Supabase CLI:
   ```bash
   npx supabase link --project-ref <ditt-projekt-id>
   npx supabase db push --include-seed
   ```
   …eller genom att klistra in filerna i Supabase **SQL Editor** i den här ordningen:
   `supabase/migrations/*_schema.sql`, `supabase/migrations/*_rls.sql`, `supabase/seed.sql`.
5. Skapa exempelkontona (lösenord = `SEED_PASSWORD` i `.env.local`):
   ```bash
   npm run seed:users
   ```
   | Konto | Roll |
   | --- | --- |
   | `SUPERADMIN_EMAIL` | superadmin |
   | `admin@kanel.test` | org_admin, Café Kanel |
   | `redaktor@kanel.test` | editor, Café Kanel |
   | `admin@napoli.test` | org_admin, Pizzeria Napoli |
6. Starta:
   ```bash
   npm run dev
   ```
   Öppna http://localhost:3000.

### Med Supabase lokalt (valfritt, kräver Docker)

```bash
npx supabase start
```
`supabase start` skriver ut URL och nycklar som du lägger i `.env.local`. `npx supabase db reset`
lägger in migreringar och exempeldata på nytt.

## Behörighet

All behörighet ligger i databasen (Row Level Security), inte bara i gränssnittet:

- **superadmin** ser och ändrar allt.
- **org_admin** hanterar sin organisations skärmar, butiker, produkter och användare, inom paketets
  gränser (antal skärmar, tillgängliga mallar och teman).
- **editor** ändrar produkter, priser och skärmarnas innehåll (t.ex. kampanj på/av), inget annat.
- Utkast publiceras bara via funktionen `publish_screens` – ingen kan skriva direkt till det som visas.
- Skärmarnas hemliga nycklar ligger i en egen tabell som ingen inloggad användare kan läsa.
- Roll och organisation sätts bara av servern (app_metadata), aldrig av användaren själv.

### Testa reglerna

```bash
npm run test:rls
```
Kör mot en lokal PostgreSQL (skapar och tar bort en tillfällig databas). Mot Supabase lokalt:
```bash
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres npm run test:rls
```
Testerna körs i en transaktion som rullas tillbaka, så de lämnar inga spår.

## Publicera (Vercel)

1. Importera GitHub-repot i [Vercel](https://vercel.com/new).
2. Lägg in miljövariablerna `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` och
   `SUPABASE_SERVICE_ROLE_KEY` under **Settings → Environment Variables**.
3. I Supabase, **Authentication → URL Configuration**: sätt Site URL till din Vercel-adress.

Hemliga nycklar ligger aldrig i koden, bara i `.env.local` (lokalt) och i Vercel.
