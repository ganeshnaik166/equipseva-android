import Link from "next/link";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SignOutButton } from "@/components/SignOutButton";

export async function TopBar() {
  const supabase = await getSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const navGroups: { label: string; links: { href: string; label: string; highlight?: boolean }[] }[] = [
    {
      label: "Pulse",
      links: [
        { href: "/founder-morning-cockpit", label: "Morning ★", highlight: true },
        { href: "/live-feed", label: "Live" },
        { href: "/platform-pulse", label: "Pulse" },
        { href: "/pulse-extended", label: "Pulse+" },
      ],
    },
    {
      label: "Ops",
      links: [
        { href: "/dashboard", label: "Dashboard" },
        { href: "/engineers", label: "Engineers" },
        { href: "/jobs", label: "Jobs" },
        { href: "/amc", label: "AMC" },
        { href: "/supply", label: "Parts" },
      ],
    },
    {
      label: "Money",
      links: [
        { href: "/payouts", label: "Cash" },
        { href: "/at-risk-revenue", label: "At-risk" },
        { href: "/disputes", label: "Disputes" },
      ],
    },
    {
      label: "Risk",
      links: [
        { href: "/onboarding", label: "KYC" },
        { href: "/audit", label: "Audit" },
        { href: "/security-overview", label: "Security" },
        { href: "/founder-runbook", label: "Runbook" },
      ],
    },
  ];

  return (
    <header role="banner" className="sticky top-0 z-50 border-b border-[var(--color-border)] bg-white/85 backdrop-blur-md print:hidden">
      <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-2.5">
        <div className="flex min-w-0 items-center gap-4">
          <Link href="/founder-morning-cockpit" className="group flex shrink-0 items-center gap-2 text-sm font-bold tracking-tight">
            <span className="grid h-7 w-7 place-items-center rounded-md bg-gradient-to-br from-emerald-600 to-emerald-700 text-[11px] font-bold text-white shadow-sm ring-1 ring-emerald-700/30">
              ES
            </span>
            <span className="hidden sm:inline">Founder Console</span>
          </Link>
          {user && (
            <nav className="flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 text-[13px] text-[var(--color-muted)]">
              {navGroups.map((group) => (
                <div key={group.label} className="flex items-center gap-2">
                  <span className="hidden text-[10px] font-semibold uppercase tracking-wider text-gray-400 md:inline">
                    {group.label}
                  </span>
                  {group.links.map((l) => (
                    <Link
                      key={l.href}
                      href={l.href}
                      className={
                        l.highlight
                          ? "rounded px-1.5 font-semibold text-[var(--color-fg)] hover:text-emerald-700"
                          : "rounded px-1 hover:text-[var(--color-fg)]"
                      }
                    >
                      {l.label}
                    </Link>
                  ))}
                  <span className="text-gray-300">·</span>
                </div>
              ))}
              <Link
                href="/ops-index"
                className="ml-1 rounded bg-emerald-600 px-2 py-0.5 text-[12px] font-semibold text-white shadow-sm hover:bg-emerald-700"
              >
                Ops index ⇢
              </Link>
            </nav>
          )}
        </div>
        {user && (
          <div className="flex shrink-0 items-center gap-3 text-[13px] text-[var(--color-muted)]">
            <span className="hidden truncate max-w-[180px] md:inline" title={user.email ?? ""}>
              {user.email}
            </span>
            <SignOutButton />
          </div>
        )}
      </div>
    </header>
  );
}
