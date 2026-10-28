// The player is built in step 2. Until then it shows a calm placeholder
// (a screen should never look broken).
export default function PlayPage() {
  return (
    <main className="fixed inset-0 grid cursor-none place-items-center overflow-hidden bg-black text-white/60">
      <p className="text-2xl">Skyltstudio</p>
    </main>
  );
}
