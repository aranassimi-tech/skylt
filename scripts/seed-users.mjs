// Creates the example accounts in Supabase Auth. Run after the migrations and
// seed.sql have been applied:  npm run seed:users
// Reads NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SEED_PASSWORD and
// SUPERADMIN_EMAIL from .env.local. Safe to run again (existing users are skipped).
import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const password = process.env.SEED_PASSWORD;
const superadminEmail = process.env.SUPERADMIN_EMAIL;

if (!url || !serviceKey || !password || !superadminEmail) {
  console.error("Saknas i .env.local: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SEED_PASSWORD, SUPERADMIN_EMAIL");
  process.exit(1);
}
if (password.length < 8) {
  console.error("SEED_PASSWORD måste vara minst 8 tecken.");
  process.exit(1);
}

const KANEL = "b0000000-0000-4000-8000-000000000001";
const NAPOLI = "b0000000-0000-4000-8000-000000000002";

const users = [
  { email: superadminEmail, app_metadata: { role: "superadmin" } },
  { email: "admin@kanel.test", app_metadata: { role: "org_admin", organization_id: KANEL } },
  { email: "redaktor@kanel.test", app_metadata: { role: "editor", organization_id: KANEL } },
  { email: "admin@napoli.test", app_metadata: { role: "org_admin", organization_id: NAPOLI } },
];

const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });

for (const u of users) {
  const { error } = await supabase.auth.admin.createUser({
    email: u.email,
    password,
    email_confirm: true,
    app_metadata: u.app_metadata,
  });
  if (error && !/already/i.test(error.message)) {
    console.error(`Kunde inte skapa ${u.email}: ${error.message}`);
    process.exitCode = 1;
  } else {
    console.log(`${error ? "Finns redan" : "Skapad"}: ${u.email} (${u.app_metadata.role})`);
  }
}
