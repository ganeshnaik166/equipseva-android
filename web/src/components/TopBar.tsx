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
              <Link href="/verticals" className="hover:text-[var(--color-fg)]">
                Verticals
              </Link>
              <Link href="/supply" className="hover:text-[var(--color-fg)]">
                Supply
              </Link>
              <Link href="/disputes" className="hover:text-[var(--color-fg)]">
                Disputes
              </Link>
              <Link href="/risk" className="hover:text-[var(--color-fg)]">
                Risk
              </Link>
              <Link href="/refunds" className="hover:text-[var(--color-fg)]">
                Refunds
              </Link>
              <Link href="/dpdp" className="hover:text-[var(--color-fg)]">
                DPDP
              </Link>
              <Link href="/reconciliation" className="hover:text-[var(--color-fg)]">
                Recon
              </Link>
              <Link href="/finance" className="hover:text-[var(--color-fg)]">
                Finance
              </Link>
              <Link href="/engineers" className="hover:text-[var(--color-fg)]">
                Engineers
              </Link>
              <Link href="/payouts" className="hover:text-[var(--color-fg)]">
                Payouts
              </Link>
              <Link href="/cohorts" className="hover:text-[var(--color-fg)]">
                Cohorts
              </Link>
              <Link href="/kyc" className="hover:text-[var(--color-fg)]">
                KYC
              </Link>
              <Link href="/funnel" className="hover:text-[var(--color-fg)]">
                Funnel
              </Link>
              <Link href="/audit" className="hover:text-[var(--color-fg)]">
                Audit
              </Link>
              <Link href="/investor" className="hover:text-[var(--color-fg)]">
                Investor
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
