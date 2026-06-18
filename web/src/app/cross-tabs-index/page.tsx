import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Cross-tabs index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Card = { href: string; title: string; desc: string; round: string };

const CARDS: Card[] = [
  { href: "/amc-revenue-by-month-by-tier",     title: "AMC revenue × tier",   desc: "6mo paid orders + ₹ per AMC tier",      round: "r962" },
  { href: "/amc-contracts-by-month-by-tier",   title: "New AMCs × tier",      desc: "6mo acquisition by tier + new MRR",     round: "r971" },
  { href: "/amc-renewal-by-month-by-status",   title: "Renewals × status",    desc: "12mo succeeded/failed/abandoned",       round: "r963" },
  { href: "/escrow-by-month-by-status",        title: "Escrow × status",      desc: "12mo paid/released/refunded/disputed",  round: "r964" },
  { href: "/payouts-by-month-by-status",       title: "Payouts × status",     desc: "12mo queued/processing/processed/failed", round: "r965" },
  { href: "/jobs-by-month-by-status",          title: "Jobs × status",        desc: "12mo posted/completed/cancelled/in-flight", round: "r967" },
  { href: "/signups-by-month-by-role",         title: "Signups × role",       desc: "12mo engineer vs hospital",             round: "r968" },
  { href: "/code-red-by-month-by-status",      title: "Code Red × status",    desc: "12mo opened/accepted/resolved/timed-out", round: "r969" },
  { href: "/referrals-by-month-by-status",     title: "Referrals × status",   desc: "12mo cohort signup→first→eligible→paid", round: "r972" },
  { href: "/supervised-by-month-by-status",    title: "Supervised × status",  desc: "12mo requested/successful/failed/declined", round: "r973" },
  { href: "/disputes-by-month-by-status",      title: "Disputes × status",    desc: "12mo submitted/accepted/rejected/pending", round: "r974" },
];

export default async function CrossTabsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cross-tabs index ★</h1>
        <span className="text-xs text-[var(--color-muted)]">r976 / PR #1600 milestone · all monthly × status surfaces in one place</span>
      </header>

      <section className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        {CARDS.map((c) => (
          <Link key={c.href} href={c.href} className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="flex items-baseline justify-between">
              <span className="text-sm font-semibold">{c.title}</span>
              <span className="text-[10px] text-[var(--color-muted)]">{c.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{c.desc}</p>
          </Link>
        ))}
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this page.</strong> r962-r974 shipped 11 month × status cross-tab pages. They follow the same shape — a 12-month (or 6mo for AMC tier ones) generator left-joined against a counts CTE per category, returning one row per month with multiple columns per status. Use them when the 1D monthly trend pages (r694, r695, r696, r697, r699, r702, r710, r711) don't surface the funnel breakdown you need.
      </section>
    </div>
  );
}
