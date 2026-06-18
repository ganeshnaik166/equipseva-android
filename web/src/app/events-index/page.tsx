import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Events index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Ev = { href: string; title: string; desc: string; round: string; domain: "Money" | "Governance" | "Marketplace" | "Trust" };

const EVENTS: Ev[] = [
  { href: "/amc-pool-credit-events-recent", title: "AMC pool credit events",        desc: "Top 100 credit/refund ledger entries",                round: "r1060", domain: "Money"       },
  { href: "/amc-pool-debit-events-recent",  title: "AMC pool debit events",         desc: "Top 100 debit ledger entries (visit/service)",          round: "r1061", domain: "Money"       },
  { href: "/admin-actions-recent",          title: "Admin actions recent",          desc: "Top 100 founder/admin actions live feed",               round: "r1042", domain: "Governance"  },
  { href: "/audit-failed-events-30d",       title: "Audit failed events 30d",        desc: "Top 100 recent failed actions",                          round: "r1021", domain: "Governance"  },
  { href: "/failed-payouts-recent",         title: "Failed payouts recent",         desc: "Top 100 recent failed payouts + reason",                round: "r1032", domain: "Money"       },
  { href: "/spare-part-orders-recent",      title: "Spare part orders recent",       desc: "Recent spare part order feed",                          round: "r911",  domain: "Marketplace" },
  { href: "/critical-actions",              title: "Critical actions queue",         desc: "Top items needing founder action (4 domains)",          round: "r1002", domain: "Trust"       },
];

const TONE: Record<Ev["domain"], string> = {
  Money:       "text-[var(--color-ok)]",
  Governance:  "text-[var(--color-warn)]",
  Marketplace: "text-[var(--color-info)]",
  Trust:       "text-[var(--color-danger)]",
};

export default async function EventsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Events index ★ r1062</h1>
        <span className="text-xs text-[var(--color-muted)]">11th meta-landing · live event feed surfaces (Money/Governance/Marketplace/Trust)</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {EVENTS.map((e) => (
          <Link key={e.href} href={e.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{e.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{e.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{e.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${TONE[e.domain]}`}>{e.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
