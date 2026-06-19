import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Investor pulse summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  active_mrr_inr: number;
  active_amc_contracts: number;
  gmv_30d_inr: number;
  jobs_completed_30d: number;
  spare_parts_paid_30d_inr: number;
  payouts_paid_30d_inr: number;
  new_engineers_30d: number;
  new_hospitals_30d: number;
  active_engineers_30d: number;
  active_hospitals_30d: number;
  referral_bounty_paid_30d_inr: number;
  amc_renewals_30d: number;
  total_users_all_time: number;
  ttv_lifetime_gmv_inr: number;
  lifetime_payouts_inr: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function InvestorPulseSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_investor_pulse_summary");
  if (error) throw new Error(`founder_investor_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Investor pulse summary</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI monthly update · MRR + GMV + active users + lifetime totals · paste into deck</span>
      </header>
      {r ? (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="rounded-lg border-2 border-[var(--color-ok)] bg-[var(--color-surface)] p-6">
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Active MRR (committed monthly recurring)</div>
              <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.active_mrr_inr)}</div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">{formatNumber(r.active_amc_contracts)} active AMC contracts</div>
            </div>
            <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-6">
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">GMV 30d (jobs + spare parts)</div>
              <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.gmv_30d_inr)}</div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">{formatNumber(r.jobs_completed_30d)} jobs completed + {inr(r.spare_parts_paid_30d_inr)} spare parts</div>
            </div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Payouts paid 30d" val={inr(r.payouts_paid_30d_inr)} ok />
            <Card title="Referral bounty paid 30d" val={inr(r.referral_bounty_paid_30d_inr)} sub="growth-loop spend" />
            <Card title="New engineers 30d" val={formatNumber(r.new_engineers_30d)} />
            <Card title="New hospitals 30d" val={formatNumber(r.new_hospitals_30d)} />
            <Card title="Active engineers 30d" val={formatNumber(r.active_engineers_30d)} ok sub="completed ≥1 job" />
            <Card title="Active hospitals 30d" val={formatNumber(r.active_hospitals_30d)} ok sub="posted ≥1 job" />
            <Card title="AMC renewals 30d" val={formatNumber(r.amc_renewals_30d)} sub="new + extension" />
            <Card title="Total users all-time" val={formatNumber(r.total_users_all_time)} />
          </div>
          <div className="mt-6">
            <h2 className="text-sm font-semibold mb-3">Lifetime totals (autobiography)</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <Card title="Lifetime GMV" val={inr(r.ttv_lifetime_gmv_inr)} ok sub="jobs + spare parts all-time" />
              <Card title="Lifetime payouts paid" val={inr(r.lifetime_payouts_inr)} ok sub="to engineers all-time" />
            </div>
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
