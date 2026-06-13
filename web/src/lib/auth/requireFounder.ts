import { redirect } from "next/navigation";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export type FounderSession = {
  userId: string;
  email: string;
};

/**
 * Server-side gate for every protected page + server action.
 *
 * 1. If there is no Supabase session, redirect to /login.
 * 2. If the session email doesn't match NEXT_PUBLIC_FOUNDER_EMAIL,
 *    render-throw — the server RPCs will reject too (ERRCODE 42501)
 *    but this saves a roundtrip and gives a clear UX message.
 *
 * Treat the env-var as the SOFT gate. The HARD gate is is_founder()
 * inside each RPC.
 */
export async function requireFounder(): Promise<FounderSession> {
  const supabase = await getSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const founderEmail = (process.env.NEXT_PUBLIC_FOUNDER_EMAIL ?? "").toLowerCase();
  if (!founderEmail) {
    // Misconfiguration — fail closed.
    throw new Error("NEXT_PUBLIC_FOUNDER_EMAIL not configured");
  }
  if ((user.email ?? "").toLowerCase() !== founderEmail) {
    throw new NotFounderError();
  }

  return { userId: user.id, email: user.email! };
}

export class NotFounderError extends Error {
  constructor() {
    super("Not authorized — founder access only.");
    this.name = "NotFounderError";
  }
}
