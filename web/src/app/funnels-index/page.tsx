import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Funnels index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Funnel = {
  href: string;
  title: string;
  desc: string;
  round: string;
  domain: "Revenue" | "Trust" | "Onboarding" | "Marketplace";
};

const FUNNELS: Funnel[] = [
  { href: "/amc-renewal-funnel-90d",    title: "AMC renewal funnel 90d",        desc: "Notify 1→2→3 → renewed/expired · % of due",                  round: "r1003", domain: "Revenue"     },
  { href: "/amc-renewal-window-30d",    title: "AMC renewal window 30d",         desc: "Renewing next 30d × tier × MRR at risk",                      round: "r991",  domain: "Revenue"     },
  { href: "/amc-renewal-attempts-by-tier", title: "AMC renewal attempts by tier", desc: "Per-tier 90d attempts/succeeded/failed/abandoned",            round: "r977",  domain: "Revenue"     },
  { href: "/payout-success-funnel-90d", title: "Payout success funnel 90d",      desc: "Queued → processing → processed/failed/still-queued",          round: "r1004", domain: "Trust"       },
  { href: "/engineer-onboarding-funnel", title: "Engineer onboarding funnel",    desc: "Signup → profile → verified → 1st bid → 1st job → 1st payout", round: "r1005", domain: "Onboarding"  },
  { href: "/hospital-onboarding-funnel", title: "Hospital onboarding funnel",    desc: "Signup → profile → 1st job → 1st bid → 1st done → 1st AMC",    round: "r1007", domain: "Onboarding"  },
  { href: "/code-red-sla",              title: "Code Red SLA",                  desc: "7d/30d/90d resolved vs timed_out",                            round: "r622",  domain: "Trust"       },
  { href: "/supervision-funnel",        title: "Supervision funnel",             desc: "Trainee → first supervised → graduate",                        round: "r623",  domain: "Onboarding"  },
];

const DOMAIN_TONE: Record<Funnel["domain"], string> = {
  Revenue:     "text-[var(--color-ok)]",
  Trust:       "text-[var(--color-warn)]",
  Onboarding:  "text-[var(--color-info)]",
  Marketplace: "text-[var(--color-muted)]",
};

export default async function FunnelsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Funnels index ★ r1010</h1>
        <span className="text-xs text-[var(--color-muted)]">All multi-stage funnels in one place · pairs with /cross-tabs-index (r976) + /critical-cockpit (r1000)</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {FUNNELS.map((f) => (
          <Link key={f.href} href={f.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{f.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{f.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{f.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${DOMAIN_TONE[f.domain]}`}>{f.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
