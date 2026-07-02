import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Summary = {
  filings_total: number;
  gst_filings_filed_ytd: number;
  gst_pending_count: number;
  tds_filings_filed_ytd: number;
  tds_payments_total: number;
  tds_amount_deducted_lifetime: number;
  tds_amount_deducted_ytd: number;
  tds_amount_deposited_ytd: number;
  tds_deposit_pending_count: number;
  ca_review_pending_count: number;
  ca_reviewed_count: number;
  overdue_filings_count: number;
  rejected_filings_count: number;
  revised_filings_count: number;
  accepted_filings_count: number;
  average_filing_lag_days: number;
  tds_unique_payees: number;
  tds_average_rate_pct: number;
};

type FilingRun = {
  id: string;
  filing_kind: string;
  filing_period_label: string;
  filing_period_start: string;
  filing_period_end: string;
  run_status: string;
  arn: string | null;
  amount_rupees: number | null;
  ca_reviewed: boolean;
  ca_reviewer_name: string | null;
  submitted_at: string | null;
  accepted_at: string | null;
  notes: string | null;
  created_at: string;
};

type TdsRow = {
  id: string;
  payment_kind: string;
  payee_name: string;
  payee_pan: string | null;
  gross_amount_rupees: number;
  tds_rate_pct: number;
  tds_amount_rupees: number;
  deducted_at: string;
  deposited_at: string | null;
  challan_no: string | null;
  challan_url: string | null;
  form_16_url: string | null;
  assessment_year: string;
  created_at: string;
};

type Overdue = {
  id: string;
  filing_kind: string;
  filing_period_label: string;
  filing_period_end: string;
  days_overdue: number;
  run_status: string;
  amount_rupees: number | null;
};

const STATUS_TONE: Record<string, string> = {
  draft: 'bg-slate-100 text-slate-700',
  submitted: 'bg-blue-100 text-blue-800',
  accepted: 'bg-emerald-100 text-emerald-800',
  rejected: 'bg-rose-100 text-rose-800',
  revised: 'bg-amber-100 text-amber-800',
  overdue: 'bg-red-100 text-red-800',
};

function Card({ label, value, hint, tone = 'slate' }: { label: string; value: string | number; hint?: string; tone?: string }) {
  const toneClass =
    tone === 'red' ? 'border-red-200 bg-red-50' :
    tone === 'amber' ? 'border-amber-200 bg-amber-50' :
    tone === 'emerald' ? 'border-emerald-200 bg-emerald-50' :
    tone === 'blue' ? 'border-blue-200 bg-blue-50' :
    'border-slate-200 bg-white';
  return (
    <div className={`rounded-lg border p-4 ${toneClass}`}>
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-900">{value}</div>
      {hint ? <div className="mt-1 text-xs text-slate-500">{hint}</div> : null}
    </div>
  );
}

function StatusPill({ status }: { status: string }) {
  const cls = STATUS_TONE[status] || 'bg-slate-100 text-slate-700';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{status}</span>;
}

export default async function FounderTaxGstAutomationHubPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summary }, { data: runs }, { data: tds }, { data: overdue }] = await Promise.all([
    supabase.rpc('founder_tax_gst_hub_summary'),
    supabase.rpc('founder_tax_filing_runs_recent', { p_kind: null, p_status: null, p_limit: 40 }),
    supabase.rpc('founder_tds_payment_ledger_recent', { p_kind: null, p_limit: 40 }),
    supabase.rpc('founder_tax_filing_runs_overdue'),
  ]);

  const s: Summary = (summary as Summary) || ({} as Summary);
  const filings: FilingRun[] = (runs as FilingRun[]) || [];
  const tdsRows: TdsRow[] = (tds as TdsRow[]) || [];
  const overdueRows: Overdue[] = (overdue as Overdue[]) || [];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <div className="text-xs uppercase tracking-widest text-slate-500">r1403 — 600 SHIPS MILESTONE</div>
        <h1 className="mt-1 text-2xl font-semibold text-slate-900">Tax & GST Automation Hub</h1>
        <p className="mt-1 text-sm text-slate-600">
          One pane for GSTR-1/3B/9/9C filings, TDS quarterly returns (24Q/26Q/27Q/27EQ), TDS payment ledger, and CA-review workflow. Extends r1316 quarterly prep.
        </p>
      </header>

      {overdueRows.length > 0 ? (
        <section className="mb-6 rounded-lg border border-red-300 bg-red-50 p-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-red-900">Overdue filings ({overdueRows.length})</h2>
            <span className="text-xs text-red-700">due-date + 20 day grace exhausted</span>
          </div>
          <div className="mt-3 overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="text-left text-xs text-red-800">
                <tr><th className="py-1 pr-4">Kind</th><th className="py-1 pr-4">Period</th><th className="py-1 pr-4">Period end</th><th className="py-1 pr-4">Days overdue</th><th className="py-1 pr-4">Amount (₹)</th><th className="py-1 pr-4">Status</th></tr>
              </thead>
              <tbody>
                {overdueRows.map((o) => (
                  <tr key={o.id} className="border-t border-red-200">
                    <td className="py-1 pr-4 font-mono text-xs">{o.filing_kind}</td>
                    <td className="py-1 pr-4">{o.filing_period_label}</td>
                    <td className="py-1 pr-4">{o.filing_period_end}</td>
                    <td className="py-1 pr-4 font-semibold text-red-900">{o.days_overdue}</td>
                    <td className="py-1 pr-4">{o.amount_rupees != null ? formatNumber(Number(o.amount_rupees)) : '—'}</td>
                    <td className="py-1 pr-4"><StatusPill status={o.run_status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      <section className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-6">
        <Card label="Filings total" value={formatNumber(s.filings_total || 0)} />
        <Card label="GST filed YTD" value={formatNumber(s.gst_filings_filed_ytd || 0)} tone="emerald" />
        <Card label="GST pending" value={formatNumber(s.gst_pending_count || 0)} tone={s.gst_pending_count ? 'amber' : 'slate'} />
        <Card label="TDS filed YTD" value={formatNumber(s.tds_filings_filed_ytd || 0)} tone="emerald" />
        <Card label="TDS payments total" value={formatNumber(s.tds_payments_total || 0)} />
        <Card label="TDS deducted lifetime" value={`₹${formatNumber(Number(s.tds_amount_deducted_lifetime || 0))}`} />
        <Card label="TDS deducted YTD" value={`₹${formatNumber(Number(s.tds_amount_deducted_ytd || 0))}`} tone="blue" />
        <Card label="TDS deposited YTD" value={`₹${formatNumber(Number(s.tds_amount_deposited_ytd || 0))}`} tone="emerald" />
        <Card label="TDS deposit pending" value={formatNumber(s.tds_deposit_pending_count || 0)} tone={s.tds_deposit_pending_count ? 'amber' : 'slate'} />
        <Card label="CA review pending" value={formatNumber(s.ca_review_pending_count || 0)} tone={s.ca_review_pending_count ? 'amber' : 'slate'} />
        <Card label="CA reviewed" value={formatNumber(s.ca_reviewed_count || 0)} />
        <Card label="Overdue" value={formatNumber(s.overdue_filings_count || 0)} tone={s.overdue_filings_count ? 'red' : 'slate'} />
        <Card label="Rejected" value={formatNumber(s.rejected_filings_count || 0)} tone={s.rejected_filings_count ? 'red' : 'slate'} />
        <Card label="Revised" value={formatNumber(s.revised_filings_count || 0)} />
        <Card label="Accepted" value={formatNumber(s.accepted_filings_count || 0)} tone="emerald" />
        <Card label="Avg filing lag" value={`${s.average_filing_lag_days || 0} d`} hint="submit minus period-end" />
        <Card label="TDS unique payees" value={formatNumber(s.tds_unique_payees || 0)} />
        <Card label="TDS average rate" value={`${s.tds_average_rate_pct || 0}%`} />
      </section>

      <section className="mb-6 rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">Recent filings ledger</h2>
          <span className="text-xs text-slate-500">{filings.length} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-600">
              <tr>
                <th className="px-4 py-2">Kind</th>
                <th className="px-4 py-2">Period</th>
                <th className="px-4 py-2">Period end</th>
                <th className="px-4 py-2">Status</th>
                <th className="px-4 py-2">ARN</th>
                <th className="px-4 py-2">Amount (₹)</th>
                <th className="px-4 py-2">CA</th>
                <th className="px-4 py-2">Submitted</th>
              </tr>
            </thead>
            <tbody>
              {filings.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-6 text-center text-slate-500">No filings registered yet.</td></tr>
              ) : filings.map((f) => (
                <tr key={f.id} className="border-t border-slate-100">
                  <td className="px-4 py-2 font-mono text-xs">{f.filing_kind}</td>
                  <td className="px-4 py-2">{f.filing_period_label}</td>
                  <td className="px-4 py-2">{f.filing_period_end}</td>
                  <td className="px-4 py-2"><StatusPill status={f.run_status} /></td>
                  <td className="px-4 py-2 font-mono text-xs">{f.arn || '—'}</td>
                  <td className="px-4 py-2">{f.amount_rupees != null ? formatNumber(Number(f.amount_rupees)) : '—'}</td>
                  <td className="px-4 py-2">{f.ca_reviewed ? <span className="text-emerald-700">✓ {f.ca_reviewer_name || ''}</span> : <span className="text-slate-400">pending</span>}</td>
                  <td className="px-4 py-2 text-xs text-slate-600">{f.submitted_at ? new Date(f.submitted_at).toISOString().slice(0, 10) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">TDS payment ledger</h2>
          <span className="text-xs text-slate-500">{tdsRows.length} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-600">
              <tr>
                <th className="px-4 py-2">Kind</th>
                <th className="px-4 py-2">Payee</th>
                <th className="px-4 py-2">PAN</th>
                <th className="px-4 py-2">Gross (₹)</th>
                <th className="px-4 py-2">Rate %</th>
                <th className="px-4 py-2">TDS (₹)</th>
                <th className="px-4 py-2">Deducted</th>
                <th className="px-4 py-2">Deposited</th>
                <th className="px-4 py-2">Challan</th>
                <th className="px-4 py-2">AY</th>
              </tr>
            </thead>
            <tbody>
              {tdsRows.length === 0 ? (
                <tr><td colSpan={10} className="px-4 py-6 text-center text-slate-500">No TDS payments recorded yet.</td></tr>
              ) : tdsRows.map((t) => (
                <tr key={t.id} className="border-t border-slate-100">
                  <td className="px-4 py-2 font-mono text-xs">{t.payment_kind}</td>
                  <td className="px-4 py-2">{t.payee_name}</td>
                  <td className="px-4 py-2 font-mono text-xs">{t.payee_pan || '—'}</td>
                  <td className="px-4 py-2">{formatNumber(Number(t.gross_amount_rupees))}</td>
                  <td className="px-4 py-2">{t.tds_rate_pct}%</td>
                  <td className="px-4 py-2 font-semibold">{formatNumber(Number(t.tds_amount_rupees))}</td>
                  <td className="px-4 py-2 text-xs">{t.deducted_at}</td>
                  <td className="px-4 py-2 text-xs">{t.deposited_at || <span className="text-amber-700">pending</span>}</td>
                  <td className="px-4 py-2 font-mono text-xs">{t.challan_no || '—'}</td>
                  <td className="px-4 py-2 font-mono text-xs">{t.assessment_year}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="mt-8 text-xs text-slate-500">
        Founder-only · RLS + SECURITY DEFINER · 8 RPCs · 2 tables · r1403 600 SHIPS MILESTONE
      </footer>
    </main>
  );
}
