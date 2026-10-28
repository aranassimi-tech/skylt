import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // The player (/play) and its API have no user login, so they are skipped.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|play|api/player).*)"],
};
