// Uniform Swedish price format used everywhere: 35 -> "35:-", 34.5 -> "34,50:-"
export function formatPrice(value: number | string): string {
  const n = Number(value);
  if (Number.isInteger(n)) return `${n}:-`;
  return `${n.toFixed(2).replace(".", ",")}:-`;
}

export const ONLINE_WINDOW_MS = 10 * 60 * 1000;

export function isOnline(lastSeenAt: string | null, now = Date.now()): boolean {
  return !!lastSeenAt && now - new Date(lastSeenAt).getTime() < ONLINE_WINDOW_MS;
}
