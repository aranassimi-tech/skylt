import { redirect } from "next/navigation";
import { TopBar } from "@/components/top-bar";
import { requireUser } from "@/lib/auth";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { profile } = await requireUser();
  if (profile?.role !== "superadmin") redirect("/app");

  return (
    <div className="mx-auto max-w-6xl px-4 pb-10">
      <TopBar subtitle="Adminpanel" badge="Superadmin" nav={[{ href: "/admin", label: "Kunder", current: true }]} />
      {children}
    </div>
  );
}
