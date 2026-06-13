"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

export function SignOutButton() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  return (
    <button
      type="button"
      disabled={pending}
      onClick={async () => {
        setPending(true);
        await getSupabaseBrowserClient().auth.signOut();
        router.replace("/login");
        router.refresh();
      }}
      className="rounded border border-[var(--color-border)] bg-white px-2 py-1 text-xs hover:bg-gray-50 disabled:opacity-50"
    >
      {pending ? "Signing out…" : "Sign out"}
    </button>
  );
}
