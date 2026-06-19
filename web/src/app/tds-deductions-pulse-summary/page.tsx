import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "TDS deductions pulse summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  current_fy: string;
  current_fy_quarter: string;
  tds_accrued_mtd_inr: number;
  tds_accrued_current_fy_inr: number;
  tds_accrued_current_quarter_inr: number;
  undeposited_tds_inr: number;
  undeposited_deduction_count: number;
  oldest_undeposited_age_days: number;
  deductee_count_current_fy: number;
  below_threshold_engineers_fy: number;
  certificates_pending_count: number;
  previous_quarter_undeposited_inr: number;
};

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : warn ? "text-[var(--color-warn)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function TdsDeductionsPulseSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tds_deductions_pulse_summary");
  if (error) throw new Error(`founder_tds_deductions_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">TDS deductions pulse summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI §194-O withholding ledger · govt-deposit liability + 26Q filing prep · pair with /reconciliation-tax-snapshot-summary</span>
      </header>
      {r ? (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="rounded-lg border-2 border-[var(--color-warn)] bg-[var(--color-surface)] p-6">
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">FY {r.current_fy} · {r.current_fy_quarter} TDS accrued</div>
              <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.tds_accrued_current_fy_inr)}</div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">this quarter {inr(r.tds_accrued_current_quarter_inr)} · MTD {inr(r.tds_accrued_mtd_inr)}</div>
            </div>
            <div className={`rounded-lg border-2 p-6 bg-[var(--color-surface)] ${r.undeposited_tds_inr > 0 ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]"}`}>
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Undeposited TDS (govt liability)</div>
              <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.undeposited_tds_inr)}</div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">{formatNumber(r.undeposited_deduction_count)} rows · oldest {formatNumber(r.oldest_undeposited_age_days)}d · deposit by 7th of next month</div>
            </div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Prev-quarter undeposited" val={inr(r.previous_quarter_undeposited_inr)} danger={r.previous_quarter_undeposited_inr > 0} sub="26Q filing deadline trigger" />
            <Card title="Certificates pending" val={formatNumber(r.certificates_pending_count)} warn={r.certificates_pending_count > 0} sub="Form 16A issuance backlog" />
            <Card title="Deductees this FY" val={formatNumber(r.deductee_count_current_fy)} sub="engineers above ₹5L threshold" />
            <Card title="Below-threshold engineers" val={formatNumber(r.below_threshold_engineers_fy)} sub="tracked, sub-5L FY gross" />
            <Card title="Oldest undeposited age" val={`${formatNumber(r.oldest_undeposited_age_days)}d`} danger={r.oldest_undeposited_age_days > 30} sub="govt-deposit aging" />
            <Card title="MTD accrual" val={inr(r.tds_accrued_mtd_inr)} sub="current calendar month" />
            <Card title="Current FY total" val={inr(r.tds_accrued_current_fy_inr)} sub={r.current_fy} />
            <Card title="Current quarter total" val={inr(r.tds_accrued_current_quarter_inr)} sub={r.current_fy_quarter} />
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)]">
            §194-O = 1% TDS on engineer payouts once cumulative FY gross &gt; ₹5,00,000. Govt deposit due 7th of next month; Form 26Q filed quarterly (Jul 31 / Oct 31 / Jan 31 / May 31). Missing deposit triggers interest + 30% expense disallowance under §40(a)(ia).
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
