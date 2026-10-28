import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Organization, Profile } from "@/lib/types";

// Logged-in user with profile and organization. Redirects to /login if missing.
export async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, organization_id, role, email")
    .eq("id", user.id)
    .maybeSingle<Profile>();

  let organization: Organization | null = null;
  if (profile?.organization_id) {
    const { data } = await supabase
      .from("organizations")
      .select("id, name, package_id, max_screens, is_active")
      .eq("id", profile.organization_id)
      .maybeSingle<Organization>();
    organization = data;
  }

  return { supabase, user, profile, organization };
}

export const ROLE_LABEL: Record<Profile["role"], string> = {
  superadmin: "Superadmin",
  org_admin: "Administratör",
  editor: "Redaktör",
};
