import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Snapshots index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Snap = { href: string; title: string; desc: string; round: string; kpis: number; section: "Demand" | "Supply" | "Money" | "Trust" };

const SURFACES: Snap[] = [
  { href: "/hospitals-snapshot-summary",   title: "Hospitals snapshot",      desc: "AMC coverage + spend + loyalty + geographic reach",            round: "r1169", kpis: 15, section: "Demand" },
  { href: "/engineers-snapshot-summary",   title: "Engineers snapshot",      desc: "KYC funnel + tier distribution + activity",                    round: "r1168", kpis: 14, section: "Supply" },
  { href: "/jobs-snapshot-summary",        title: "Jobs snapshot",           desc: "Posted/open/in-progress/completed/cancelled marketplace mix",  round: "r1162", kpis: 12, section: "Demand" },
  { href: "/code-red-snapshot-summary",    title: "Code Red snapshot",       desc: "Emergency queue + SLA breach % + responders 30d",              round: "r1165", kpis: 13, section: "Supply" },
  { href: "/amc-snapshot-summary",         title: "AMC snapshot",            desc: "Active/paused/expired + MRR + pool health · 13-KPI",           round: "r1161", kpis: 13, section: "Money"  },
  { href: "/payouts-snapshot-summary",     title: "Payouts snapshot",        desc: "Queued/processed/failed/stuck pipeline + INR",                 round: "r1166", kpis: 14, section: "Money"  },
  { href: "/spare-parts-snapshot-summary", title: "Spare parts snapshot",    desc: "Paid/shipped/delivered/stuck commerce funnel + GMV",           round: "r1167", kpis: 15, section: "Money"  },
  { href: "/escrow-snapshot-summary",      title: "Escrow snapshot",         desc: "Money-in-flight: held/released/refunded/scheduled-release",    round: "r1171", kpis: 18, section: "Money"  },
  { href: "/disputes-snapshot-summary",    title: "Disputes snapshot",       desc: "Mediation queue + resolution % + money at stake",              round: "r1170", kpis: 14, section: "Trust"  },
];

const SEC_TONE: Record<Snap["section"], string> = {
  Demand: "text-[var(--color-info)]",
  Supply: "text-[var(--color-ok)]",
  Money:  "text-[var(--color-warn)]",
  Trust:  "text-[var(--color-danger)]",
};

export default async function SnapshotsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Snapshots index ★ r1172</h1>
        <span className="text-xs text-[var(--color-muted)]">24th meta-landing · {SURFACES.length} domain snapshot summaries · 12-18 KPIs each, today/30d/all-time mix</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {SURFACES.map((s) => (
          <Link key={s.href} href={s.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{s.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{s.round} · {s.kpis} KPIs</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{s.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${SEC_TONE[s.section]}`}>{s.section}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
