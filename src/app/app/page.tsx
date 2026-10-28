import { requireUser, ROLE_LABEL } from "@/lib/auth";
import { formatPrice, isOnline } from "@/lib/format";
import type { Product, Screen } from "@/lib/types";

// Step 1: a simple read-out of what the logged-in user is allowed to see.
// The real dashboard with drag and drop comes in step 3.
export default async function AppHome() {
  const { supabase, profile } = await requireUser();

  const [{ data: screens }, { data: products }, { data: locations }] = await Promise.all([
    supabase.from("screens").select("*").order("sort_order").returns<Screen[]>(),
    supabase.from("products").select("*").order("sort_order").returns<Product[]>(),
    supabase.from("locations").select("id, name").order("name"),
  ]);

  const now = Date.now();
  const online = (screens ?? []).filter((s) => isOnline(s.last_seen_at, now)).length;
  const groups = (locations ?? []).map((l) => ({
    ...l,
    screens: (screens ?? []).filter((s) => s.location_id === l.id),
  }));
  const unplaced = (screens ?? []).filter((s) => !s.location_id);
  if (unplaced.length) groups.push({ id: "none", name: "Utan butik", screens: unplaced });

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Alla skärmar</h1>
        <p className="mt-1 text-muted">
          {online} av {screens?.length ?? 0} online · Inloggad som {profile?.email} (
          {profile ? ROLE_LABEL[profile.role] : ""})
        </p>
      </div>

      {groups.map((g) => (
        <section key={g.id}>
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted">{g.name}</h2>
          <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {g.screens.map((s, i) => {
              const on = isOnline(s.last_seen_at, now);
              const dirty = JSON.stringify(s.draft_content) !== JSON.stringify(s.published_content);
              return (
                <li key={s.id} className="rounded-xl border border-line bg-surface p-4">
                  <div className="flex items-center gap-2 font-semibold">
                    <span className={`h-2 w-2 rounded-full ${on ? "bg-good" : "bg-off"}`} aria-hidden />
                    Skärm {i + 1}
                    {dirty && (
                      <span className="rounded-full bg-warn-soft px-2 py-0.5 text-[11px] font-semibold text-warn">
                        Utkast
                      </span>
                    )}
                  </div>
                  <div className="mt-1 text-sm text-muted">
                    {s.name} · {s.orientation === "portrait" ? "Stående" : "Liggande"} ·{" "}
                    {on ? "Online" : "Offline"}
                  </div>
                </li>
              );
            })}
          </ul>
        </section>
      ))}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted">
          Produkter ({products?.length ?? 0})
        </h2>
        <ul className="divide-y divide-line overflow-hidden rounded-xl border border-line bg-surface">
          {(products ?? []).map((p) => (
            <li key={p.id} className="flex items-center gap-3 px-4 py-2.5">
              <span className="flex-1">{p.name}</span>
              <span className="text-sm text-muted">{p.category}</span>
              <span className="w-24 text-right tabular-nums">
                {p.campaign_price != null && (
                  <span className="mr-2 text-sm text-muted line-through">{formatPrice(p.price)}</span>
                )}
                {formatPrice(p.campaign_price ?? p.price)}
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
