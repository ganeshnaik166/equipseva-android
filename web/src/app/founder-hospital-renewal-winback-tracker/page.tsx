import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalRenewalWinbackTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [winbacksRes, attemptsRes, topRes, funnelRes] = await Promise.all([
    sb.rpc('list_winbacks_r1767'),
    sb.rpc('list_attempts_r1767', { p_winback_id: null }),
    sb.rpc('top_winback_targets_r1767'),
    sb.rpc('winback_funnel_summary_r1767'),
  ]);

  const winbacks: any[] = Array.isArray(winbacksRes.data) ? winbacksRes.data : [];
  const attempts: any[] = Array.isArray(attemptsRes.data) ? attemptsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const funnel: any = Array.isArray(funnelRes.data) && funnelRes.data[0] ? funnelRes.data[0] : {};

  const fmtRupees = (n: number | null | undefined) => {
    if (n == null) return '—';
    return '₹' + Number(n).toLocaleString('en-IN');
  };

  const fmtDate = (d: string | null | undefined) => {
    if (!d) return '—';
    return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  };

  const winbackColumns: Column<any>[] = [
    { key: 'hospital_org', header: 'Hospital', render: (r: any) => <span>{r.hospital_org ?? r.hospital_email ?? '—'}</span> },
    { key: 'churn_reason', header: 'Churn Reason', render: (r: any) => <span className="text-xs uppercase tracking-wide">{r.churn_reason}</span> },
    { key: 'churned_at', header: 'Churned', render: (r: any) => <span>{fmtDate(r.churned_at)}</span> },
    { key: 'target_winback_amount_rupees', header: 'Target', render: (r: any) => <span className="font-mono">{fmtRupees(r.target_winback_amount_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs font-medium">{r.status}</span> },
    { key: 'attempt_count', header: 'Attempts', render: (r: any) => <span className="font-mono">{r.attempt_count ?? 0}</span> },
    { key: 'last_attempt_at', header: 'Last Attempt', render: (r: any) => <span>{fmtDate(r.last_attempt_at)}</span> },
    { key: 'won_back_at', header: 'Won Back', render: (r: any) => <span>{fmtDate(r.won_back_at)}</span> },
  ];

  const topColumns: Column<any>[] = [
    { key: 'hospital_org', header: 'Hospital', render: (r: any) => <span>{r.hospital_org ?? r.hospital_email ?? '—'}</span> },
    { key: 'churn_reason', header: 'Reason', render: (r: any) => <span className="text-xs uppercase">{r.churn_reason}</span> },
    { key: 'target_winback_amount_rupees', header: 'Target Value', render: (r: any) => <span className="font-mono font-semibold">{fmtRupees(r.target_winback_amount_rupees)}</span> },
    { key: 'days_since_churn', header: 'Days Since Churn', render: (r: any) => <span className="font-mono">{r.days_since_churn ?? 0}</span> },
    { key: 'attempt_count', header: 'Attempts', render: (r: any) => <span className="font-mono">{r.attempt_count ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
  ];

  const attemptColumns: Column<any>[] = [
    { key: 'attempted_at', header: 'When', render: (r: any) => <span>{fmtDate(r.attempted_at)}</span> },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span className="text-xs">{r.hospital_email ?? '—'}</span> },
    { key: 'attempt_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.attempt_type}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email}</span> },
    { key: 'response', header: 'Response', render: (r: any) => <span className="text-xs">{r.response ?? '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Hospital Renewal Win-Back Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track churned hospital renewals and win-back attempts. Reasons: price, service quality, competitor,
          closed, internal team. Stages: in outreach → in negotiation → won back / lost permanently.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Funnel Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">Total Churned</div>
            <div className="text-xl font-bold">{funnel.total_churned ?? 0}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">In Outreach</div>
            <div className="text-xl font-bold">{funnel.in_outreach ?? 0}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">In Negotiation</div>
            <div className="text-xl font-bold">{funnel.in_negotiation ?? 0}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">Won Back</div>
            <div className="text-xl font-bold text-green-700">{funnel.won_back ?? 0}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">Lost Permanently</div>
            <div className="text-xl font-bold text-red-700">{funnel.lost_permanently ?? 0}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">Target Amount</div>
            <div className="text-lg font-bold font-mono">{fmtRupees(funnel.total_target_amount_rupees)}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">Won Back Amount</div>
            <div className="text-lg font-bold font-mono text-green-700">{fmtRupees(funnel.won_back_amount_rupees)}</div>
          </div>
          <div className="bg-white border rounded p-3">
            <div className="text-xs text-gray-500">Win Rate</div>
            <div className="text-xl font-bold">{funnel.win_rate_pct ?? 0}%</div>
          </div>
        </div>
        <p className="text-xs text-gray-500 mt-2">
          Win rate = won_back / (won_back + lost_permanently). Target win rate &gt;=40% on price-driven churn.
        </p>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Win-Back Targets</h2>
        <p className="text-xs text-gray-500 mb-2">
          Active win-back candidates ranked by target value. Founder should personally call any target &gt;=
          ₹1,00,000 or churned &gt;30 days ago.
        </p>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Win-Backs</h2>
        <p className="text-xs text-gray-500 mb-2">
          Most recent 200 churned hospitals with renewal win-back tracking.
        </p>
        <DataTable
          rows={winbacks}
          columns={winbackColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Win-Back Attempts</h2>
        <p className="text-xs text-gray-500 mb-2">
          Latest 200 outreach attempts. Types: call, visit, discount_offer, founder_call, customer_event.
        </p>
        <DataTable
          rows={attempts}
          columns={attemptColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
