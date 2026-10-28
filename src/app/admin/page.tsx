import { requireUser } from "@/lib/auth";
import type { Organization } from "@/lib/types";

// Step 1: list of customers. Editing, packages and invitations come in step 5.
export default async function AdminHome() {
  const { supabase } = await requireUser();
  const [{ data: orgs }, { data: screens }] = await Promise.all([
    supabase.from("organizations").select("*").order("name").returns<Organization[]>(),
    supabase.from("screens").select("organization_id"),
  ]);

  return (
    <div>
      <h1 className="mb-4 text-2xl font-semibold tracking-tight">Kunder</h1>
      <ul className="divide-y divide-line overflow-hidden rounded-xl border border-line bg-surface">
        {(orgs ?? []).map((o) => (
          <li key={o.id} className="flex items-center gap-3 px-4 py-3">
            <span className="flex-1 font-medium">{o.name}</span>
            <span className="text-sm text-muted">
              {(screens ?? []).filter((s) => s.organization_id === o.id).length} av {o.max_screens} skärmar
            </span>
            {!o.is_active && (
              <span className="rounded-full bg-bad-soft px-2 py-0.5 text-xs font-semibold text-bad">Pausad</span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
