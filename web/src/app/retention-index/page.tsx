import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Retention index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type R = { href: string; title: string; desc: string; round: string; side: "Supply" | "Demand" };

const RETS: R[] = [
  { href: "/engineer-cohort-retention",  title: "Engineer cohort retention",  desc: "12mo signup cohorts × 30/60/90/180d active %",         round: "r1051", side: "Supply" },
  { href: "/hospital-cohort-retention",  title: "Hospital cohort retention",  desc: "12mo signup cohorts × 30/60/90/180d posted-job %",     round: "r1052", side: "Demand" },
  { href: "/engineers-no-jobs-30d",      title: "Engineer activation leak",   desc: "Engineers w/ 0 completed jobs in 30/60/90d + never",   round: "r992",  side: "Supply" },
  { href: "/hospitals-no-jobs-30d",      title: "Hospital activation leak",   desc: "Hospitals w/ 0 posted jobs in 30/60/90d + never",      round: "r993",  side: "Demand" },
];

const TONE: Record<R["side"], string> = {
  Supply: "text-[var(--color-ok)]",
  Demand: "text-[var(--color-info)]",
};

export default async function RetentionIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Retention index ★ r1053</h1>
        <span className="text-xs text-[var(--color-muted)]">9th meta-landing · cohort retention + activation leak</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {RETS.map((r) => (
          <Link key={r.href} href={r.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{r.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{r.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{r.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${TONE[r.side]}`}>{r.side}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
