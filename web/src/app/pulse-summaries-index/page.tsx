import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Pulse summaries index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Pulse = { href: string; title: string; desc: string; round: string; focus: "Money" | "Trust" | "Quality" | "Growth" | "Ops" };

const PULSES: Pulse[] = [
  // Money axis
  { href: "/money-in-flight-summary",        title: "Money in flight",         desc: "Cross-domain cash position · escrow + payouts + spare-parts + AMC pool + bounty",   round: "r1193", focus: "Money"   },
  { href: "/investor-pulse-summary",         title: "Investor pulse",          desc: "Monthly MRR + GMV + lifetime totals · paste into deck",                              round: "r1208", focus: "Money"   },
  { href: "/amc-pool-pulse-summary",         title: "AMC pool pulse",          desc: "Pool balance + 30d flow + zero-balance alerts",                                      round: "r1209", focus: "Money"   },
  { href: "/cumulative-rollup-summary",      title: "Cumulative rollup",       desc: "Lifetime autobiography · investor-deck row",                                         round: "r1200", focus: "Money"   },

  // Trust axis
  { href: "/trust-pulse-summary",            title: "Trust pulse",             desc: "Composite 30d trust score · disputes + audits + Code Red + refunds + payouts",      round: "r1195", focus: "Trust"   },

  // Quality axis
  { href: "/supply-quality-summary",         title: "Supply quality",          desc: "Composite engineer-trust score · KYC + tiers + audit + payouts + activity",         round: "r1211", focus: "Quality" },
  { href: "/demand-quality-summary",         title: "Demand quality",          desc: "Composite hospital-trust score · AMC coverage + activity + loyalty + churn",        round: "r1212", focus: "Quality" },

  // Growth axis
  { href: "/onboarding-velocity-summary",    title: "Onboarding velocity",     desc: "Time-to-first-action across engineer/hospital roles · median + p90",                round: "r1214", focus: "Growth"  },
  { href: "/regional-state-summary",         title: "Regional state",          desc: "Top-3 states by composite activity · capital-allocation signal",                    round: "r1201", focus: "Growth"  },

  // Ops axis
  { href: "/founder-action-followups-summary", title: "Founder action followups", desc: "Untouched items >7d · meta-operational TODO age pulse",                          round: "r1217", focus: "Ops"     },
  { href: "/system-throughput-hourly-summary", title: "System throughput hourly", desc: "Jobs-per-hour + 24h-load curve · capacity planning",                              round: "r1218", focus: "Ops"     },
];

const FOCUS_TONE: Record<Pulse["focus"], string> = {
  Money:   "text-[var(--color-warn)]",
  Trust:   "text-[var(--color-danger)]",
  Quality: "text-[var(--color-info)]",
  Growth:  "text-[var(--color-accent)]",
  Ops:     "text-[var(--color-muted)]",
};

export default async function PulseSummariesIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Pulse summaries index ★ r1228</h1>
        <span className="text-xs text-[var(--color-muted)]">27th meta-landing · {PULSES.length} cross-domain pulse dashboards (Money/Trust/Quality/Growth/Ops)</span>
      </header>
      <p className="text-sm text-[var(--color-muted)]">Pulses differ from snapshots: they cut ACROSS domains and produce a composite score, not a per-table single-row dashboard. Use these to answer broad founder questions ("is trust deteriorating", "where is the cash") in one glance.</p>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {PULSES.map((p) => (
          <Link key={p.href} href={p.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{p.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{p.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{p.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${FOCUS_TONE[p.focus]}`}>{p.focus}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
