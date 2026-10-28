import { Brand } from "@/components/brand";
import { LoginForm } from "./login-form";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const { next = "/app" } = await searchParams;
  return (
    <main className="grid min-h-dvh place-items-center px-4">
      <div className="w-full max-w-sm rounded-2xl border border-line bg-surface p-6 shadow-sm">
        <Brand />
        <h1 className="mt-6 text-2xl font-semibold tracking-tight">Logga in</h1>
        <p className="mb-6 mt-1 text-muted">Ändra menyer, priser och kampanjer på dina skärmar.</p>
        <LoginForm next={next} />
      </div>
    </main>
  );
}
