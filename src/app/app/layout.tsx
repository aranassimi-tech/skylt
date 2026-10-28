import { TopBar } from "@/components/top-bar";
import { Notice } from "@/components/notice";
import { requireUser } from "@/lib/auth";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const { profile, organization } = await requireUser();

  return (
    <div className="mx-auto max-w-6xl px-4 pb-10">
      <TopBar
        subtitle={organization?.name}
        nav={[
          { href: "/app", label: "Skärmar", current: true },
          ...(profile?.role === "superadmin" ? [{ href: "/admin", label: "Admin" }] : []),
        ]}
      />
      {!profile ? (
        <Notice title="Ditt konto är inte kopplat till någon kund">
          Kontakta Skyltstudio så hjälper vi dig.
        </Notice>
      ) : profile.role !== "superadmin" && !organization ? (
        <Notice title="Kontot är pausat">Kontakta Skyltstudio för att aktivera det igen.</Notice>
      ) : (
        children
      )}
    </div>
  );
}
