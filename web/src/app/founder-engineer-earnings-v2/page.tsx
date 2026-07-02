import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_earnings_lifetime_rupees: number;
  total_earnings_this_ay_rupees: number;
  total_tds_deducted_rupees: number;
  top_earner_user_id: string | null;
  top_earner_total_rupees: number;
  cashout_requests_pending: number;
  cashout_requests_approved: number;
  cashout_requests_queued: number;
  cashout_requests_sent: number;
  cashout_requests_rejected: number;
  cashout_requests_total_30d: number;
  cashout_amount_sent_lifetime: number;
  cashout_amount_pending_rupees: number;
  avg_days_request_to_sent: number;
  engineers_with_tax_assist: number;
  engineers_gst_filed_this_ay: number;
  engineers_it_filed_this_ay: number;
  current_ay_label: string;
};

type CashoutRow = {
  id: string;
  engineer_user_id: string;
  amount_rupees: number;
  request_status: string;
  approved_at: string | null;
  payout_id: string | null;
  rejection_reason: string | null;
  requested_at: string;
  sent_at: string | null;
  days_open: number;
};

type TaxRow = {
  engineer_user_id: string;
  assessment_year: string;
  total_income_rupees: number;
  total_tds_deducted_rupees: number;
  gst_filed: boolean;
  it_filed: boolean;
  form_16a_url: string | null;
  form_26as_url: string | null;
  itr_v_url: string | null;
  last_updated_at: string;
};

function Card({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs font-medium uppercase tracking-wider text-neutral-500">{label}</div>
      <div className="mt-2 text-2xl font-semibold text-neutral-900">{value}</div>
      {hint ? <div className="mt-1 text-xs text-neutral-500">{hint}</div> : null}
    </div>
  );
}

function StatusPill({ status }: { status: string }) {
  const color =
    status === 'sent' ? 'bg-emerald-100 text-emerald-800' :
    status === 'approved' ? 'bg-blue-100 text-blue-800' :
    status === 'queued_for_payout' ? 'bg-indigo-100 text-indigo-800' :
    status === 'requested' ? 'bg-amber-100 text-amber-800' :
    status === 'rejected' ? 'bg-red-100 text-red-800' :
    'bg-neutral-100 text-neutral-700';
  return <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${color}`}>{status}</span>;
}

export default async function FounderEngineerEarningsV2Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, cashoutRes, taxRes] = await Promise.all([
    supabase.rpc('founder_engineer_earnings_v2_summary'),
    supabase.rpc('founder_engineer_earnings_v2_cashout_recent', { p_status: null, p_limit: 100 }),
    supabase.rpc('founder_engineer_earnings_v2_tax_filing_status'),
  ]);

  const summary = (summaryRes.data ?? {}) as Partial<SummaryRow>;
  const cashout = (cashoutRes.data ?? []) as CashoutRow[];
  const tax = (taxRes.data ?? []) as TaxRow[];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-neutral-900">Engineer Earnings v2</h1>
        <p className="mt-1 text-sm text-neutral-600">
          Cashout request ledger and tax filing assistance for {summary.current_ay_label ?? 'current AY'}.
        </p>
      </header>

      <section className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-4">
        <Card label="Lifetime Earnings" value={`₹${formatNumber(summary.total_earnings_lifetime_rupees ?? 0)}`} hint="All processed payouts" />
        <Card label={`This ${summary.current_ay_label ?? 'AY'}`} value={`₹${formatNumber(summary.total_earnings_this_ay_rupees ?? 0)}`} />
        <Card label="TDS Deducted" value={`₹${formatNumber(summary.total_tds_deducted_rupees ?? 0)}`} hint="Cumulative" />
        <Card label="Top Earner" value={`₹${formatNumber(summary.top_earner_total_rupees ?? 0)}`} hint={summary.top_earner_user_id ? `${summary.top_earner_user_id.slice(0, 8)}…` : 'n/a'} />
        <Card label="Pending Cashouts" value={formatNumber(summary.cashout_requests_pending ?? 0)} />
        <Card label="Approved Cashouts" value={formatNumber(summary.cashout_requests_approved ?? 0)} />
        <Card label="Queued For Payout" value={formatNumber(summary.cashout_requests_queued ?? 0)} />
        <Card label="Sent Cashouts" value={formatNumber(summary.cashout_requests_sent ?? 0)} />
        <Card label="Rejected" value={formatNumber(summary.cashout_requests_rejected ?? 0)} />
        <Card label="Requests Last 30d" value={formatNumber(summary.cashout_requests_total_30d ?? 0)} />
        <Card label="Cashout Sent Lifetime" value={`₹${formatNumber(summary.cashout_amount_sent_lifetime ?? 0)}`} />
        <Card label="Cashout Pending ₹" value={`₹${formatNumber(summary.cashout_amount_pending_rupees ?? 0)}`} />
        <Card label="Avg Days Request→Sent" value={`${formatNumber(summary.avg_days_request_to_sent ?? 0)}d`} />
        <Card label="Engineers With Tax Assist" value={formatNumber(summary.engineers_with_tax_assist ?? 0)} />
        <Card label="GST Filed This AY" value={formatNumber(summary.engineers_gst_filed_this_ay ?? 0)} />
        <Card label="IT Filed This AY" value={formatNumber(summary.engineers_it_filed_this_ay ?? 0)} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">Cashout Request Ledger (latest 100)</h2>
        <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-neutral-200 text-sm">
            <thead className="bg-neutral-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Requested</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Engineer</th>
                <th className="px-3 py-2 text-right font-medium text-neutral-700">Amount</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Status</th>
                <th className="px-3 py-2 text-right font-medium text-neutral-700">Days Open</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Sent</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Payout</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {cashout.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-6 text-center text-neutral-500">No cashout requests yet.</td></tr>
              ) : cashout.map((r) => (
                <tr key={r.id} className="hover:bg-neutral-50">
                  <td className="px-3 py-2 text-neutral-600">{new Date(r.requested_at).toLocaleString()}</td>
                  <td className="px-3 py-2 font-mono text-xs text-neutral-700">{r.engineer_user_id.slice(0, 8)}…</td>
                  <td className="px-3 py-2 text-right font-medium text-neutral-900">₹{formatNumber(r.amount_rupees)}</td>
                  <td className="px-3 py-2"><StatusPill status={r.request_status} /></td>
                  <td className="px-3 py-2 text-right text-neutral-700">{formatNumber(r.days_open)}d</td>
                  <td className="px-3 py-2 text-neutral-600">{r.sent_at ? new Date(r.sent_at).toLocaleDateString() : '—'}</td>
                  <td className="px-3 py-2 font-mono text-xs text-neutral-600">{r.payout_id ? `${r.payout_id.slice(0, 8)}…` : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">Tax Filing Status — {summary.current_ay_label ?? 'Current AY'}</h2>
        <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-neutral-200 text-sm">
            <thead className="bg-neutral-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Engineer</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">AY</th>
                <th className="px-3 py-2 text-right font-medium text-neutral-700">Income</th>
                <th className="px-3 py-2 text-right font-medium text-neutral-700">TDS</th>
                <th className="px-3 py-2 text-center font-medium text-neutral-700">GST</th>
                <th className="px-3 py-2 text-center font-medium text-neutral-700">IT</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Form 16A</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">26AS</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">ITR-V</th>
                <th className="px-3 py-2 text-left font-medium text-neutral-700">Updated</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {tax.length === 0 ? (
                <tr><td colSpan={10} className="px-3 py-6 text-center text-neutral-500">No tax filing records for this AY.</td></tr>
              ) : tax.map((r) => (
                <tr key={`${r.engineer_user_id}-${r.assessment_year}`} className="hover:bg-neutral-50">
                  <td className="px-3 py-2 font-mono text-xs text-neutral-700">{r.engineer_user_id.slice(0, 8)}…</td>
                  <td className="px-3 py-2 text-neutral-700">{r.assessment_year}</td>
                  <td className="px-3 py-2 text-right font-medium text-neutral-900">₹{formatNumber(r.total_income_rupees)}</td>
                  <td className="px-3 py-2 text-right text-neutral-700">₹{formatNumber(r.total_tds_deducted_rupees)}</td>
                  <td className="px-3 py-2 text-center">{r.gst_filed ? <span className="text-emerald-700">Filed</span> : <span className="text-neutral-400">—</span>}</td>
                  <td className="px-3 py-2 text-center">{r.it_filed ? <span className="text-emerald-700">Filed</span> : <span className="text-neutral-400">—</span>}</td>
                  <td className="px-3 py-2">{r.form_16a_url ? <a className="text-blue-600 underline" href={r.form_16a_url}>link</a> : '—'}</td>
                  <td className="px-3 py-2">{r.form_26as_url ? <a className="text-blue-600 underline" href={r.form_26as_url}>link</a> : '—'}</td>
                  <td className="px-3 py-2">{r.itr_v_url ? <a className="text-blue-600 underline" href={r.itr_v_url}>link</a> : '—'}</td>
                  <td className="px-3 py-2 text-neutral-600">{new Date(r.last_updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
