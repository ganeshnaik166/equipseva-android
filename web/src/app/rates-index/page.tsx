import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Rates index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Rate = { href: string; title: string; desc: string; round: string; domain: "Revenue" | "Trust" | "Marketplace" | "Governance" };

const RATES: Rate[] = [
  { href: "/amc-renewal-rate-by-month",            title: "AMC renewal rate by month",         desc: "6mo · renewed/due %",                        round: "r1054", domain: "Revenue"     },
  { href: "/amc-renewal-rate-by-week",             title: "AMC renewal rate by week",          desc: "13wk · renewed/due %",                        round: "r1118", domain: "Revenue"     },
  { href: "/payouts-success-rate-by-week",         title: "Payouts success rate by week",      desc: "13wk · processed/queued %",                   round: "r1117", domain: "Revenue"     },
  { href: "/code-red-resolution-rate-by-week",     title: "Code Red resolution rate by week",  desc: "13wk · resolved/total %",                     round: "r1119", domain: "Trust"       },
  { href: "/jobs-completion-rate-by-week",         title: "Jobs completion rate by week",      desc: "13wk · completed/posted %",                   round: "r1116", domain: "Marketplace" },
  { href: "/audit-success-rate-by-week",           title: "Audit success rate by week",        desc: "13wk · success/total %",                       round: "r1074", domain: "Governance"  },
  { href: "/escrow-release-rate",                  title: "Escrow release rate",                desc: "% completed jobs whose escrow released",       round: "r796",  domain: "Trust"       },
  { href: "/jobs-fill-rate",                       title: "Jobs fill rate",                     desc: "% jobs got bid within 7d",                    round: "r794",  domain: "Marketplace" },
];

const TONE: Record<Rate["domain"], string> = {
  Revenue:     "text-[var(--color-ok)]",
  Trust:       "text-[var(--color-danger)]",
  Marketplace: "text-[var(--color-info)]",
  Governance:  "text-[var(--color-warn)]",
};

export default async function RatesIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Rates index ★ r1120</h1>
        <span className="text-xs text-[var(--color-muted)]">14th meta-landing · 8 conversion/success-rate surfaces grouped by domain</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {RATES.map((r) => (
          <Link key={r.href} href={r.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{r.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{r.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{r.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${TONE[r.domain]}`}>{r.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
