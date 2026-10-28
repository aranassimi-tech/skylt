export function Notice({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-line bg-surface p-6">
      <h1 className="text-xl font-semibold">{title}</h1>
      {children && <div className="mt-2 text-muted">{children}</div>}
    </div>
  );
}
