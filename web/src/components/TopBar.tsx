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
          <Link href="/founder-morning-cockpit" className="text-sm font-semibold tracking-tight">
            EquipSeva Founder Console
          </Link>
          {user && (
            <nav className="flex flex-wrap items-center gap-4 text-sm text-[var(--color-muted)]">
              <Link href="/founder-morning-cockpit" className="font-semibold text-[var(--color-fg)] hover:underline">
                Morning ★
              </Link>
              <Link href="/live-feed" className="hover:text-[var(--color-fg)]">
                Live ★
              </Link>
              <Link href="/platform-pulse" className="hover:text-[var(--color-fg)]">
                Pulse
              </Link>
              <Link href="/pulse-extended" className="hover:text-[var(--color-fg)]">
                Pulse+
              </Link>
              <Link href="/at-risk-revenue" className="hover:text-[var(--color-fg)]">
                At-risk
              </Link>
              <Link href="/dashboard" className="hover:text-[var(--color-fg)]">
                Dashboard
              </Link>
              <Link href="/engineers" className="hover:text-[var(--color-fg)]">
                Engineers
              </Link>
              <Link href="/jobs" className="hover:text-[var(--color-fg)]">
                Jobs
              </Link>
              <Link href="/amc" className="hover:text-[var(--color-fg)]">
                AMC
              </Link>
              <Link href="/supply" className="hover:text-[var(--color-fg)]">
                Parts
              </Link>
              <Link href="/payouts" className="hover:text-[var(--color-fg)]">
                Cash
              </Link>
              <Link href="/disputes" className="hover:text-[var(--color-fg)]">
                Disputes
              </Link>
              <Link href="/onboarding" className="hover:text-[var(--color-fg)]">
                KYC
              </Link>
              <Link href="/audit" className="hover:text-[var(--color-fg)]">
                Audit
              </Link>
              <Link href="/security-overview" className="hover:text-[var(--color-fg)]">
                Security
              </Link>
              <Link href="/founder-runbook" className="hover:text-[var(--color-fg)]">
                Runbook
              </Link>
              <Link href="/ops-index" className="font-semibold hover:text-[var(--color-fg)]">
                Ops index
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
