import Link from "next/link";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SignOutButton } from "@/components/SignOutButton";

export async function TopBar() {
  const supabase = await getSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <header className="border-b border-[var(--color-border)] bg-white">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
        <div className="flex items-center gap-6">
          <Link href="/dashboard" className="text-sm font-semibold tracking-tight">
            EquipSeva Founder Console
          </Link>
          {user && (
            <nav className="flex flex-wrap items-center gap-4 text-sm text-[var(--color-muted)]">
              <Link href="/dashboard" className="hover:text-[var(--color-fg)]">
                Dashboard
              </Link>
              <Link href="/ops" className="hover:text-[var(--color-fg)]">
                Ops
              </Link>
              <Link href="/disputes" className="hover:text-[var(--color-fg)]">
                Disputes
              </Link>
              <Link href="/risk" className="hover:text-[var(--color-fg)]">
                Risk
              </Link>
              <Link href="/reconciliation" className="hover:text-[var(--color-fg)]">
                Recon
              </Link>
              <Link href="/finance" className="hover:text-[var(--color-fg)]">
                Finance
              </Link>
              <Link href="/kyc" className="hover:text-[var(--color-fg)]">
                KYC
              </Link>
              <Link href="/funnel" className="hover:text-[var(--color-fg)]">
                Funnel
              </Link>
            </nav>
          )}
        </div>
        {user && (
          <div className="flex items-center gap-3 text-sm text-[var(--color-muted)]">
            <span>{user.email}</span>
            <SignOutButton />
          </div>
        )}
      </div>
    </header>
  );
}
