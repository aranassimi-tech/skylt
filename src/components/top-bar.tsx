import Link from "next/link";
import { signOut } from "@/app/login/actions";
import { Brand } from "./brand";

type NavItem = { href: string; label: string; current?: boolean };

export function TopBar({ subtitle, nav, badge }: { subtitle?: string; nav: NavItem[]; badge?: string }) {
  return (
    <header className="mb-5 flex flex-wrap items-center gap-4 border-b border-line py-4">
      <Brand />
      {subtitle && <span className="text-sm text-muted">{subtitle}</span>}
      {badge && (
        <span className="rounded-full bg-warn-soft px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider text-warn">
          {badge}
        </span>
      )}
      <nav className="ml-auto flex flex-wrap items-center gap-1">
        {nav.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            aria-current={item.current ? "page" : undefined}
            className="rounded-lg px-3 py-2 font-medium text-muted aria-[current=page]:bg-accent-soft aria-[current=page]:text-accent"
          >
            {item.label}
          </Link>
        ))}
        <form action={signOut}>
          <button type="submit" className="rounded-lg px-3 py-2 font-medium text-muted hover:text-fg">
            Logga ut
          </button>
        </form>
      </nav>
    </header>
  );
}
