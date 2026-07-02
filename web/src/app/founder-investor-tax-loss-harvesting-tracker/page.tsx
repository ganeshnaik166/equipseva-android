import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorTaxLossHarvestingTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [plansRes, recsRes, summaryRes, urgentRes] = await Promise.all([
    sb.rpc('r1865_list_plans', { p_status: null }),
    sb.rpc('r1865_list_recommendations', { p_plan_id: null }),
    sb.rpc('r1865_total_savings_summary'),
    sb.rpc('r1865_urgent_recommendations', { p_limit: 10 }),
  ]);

  const plans: any[] = Array.isArray(plansRes.data) ? plansRes.data : [];
  const recs: any[] = Array.isArray(recsRes.data) ? recsRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const urgent: any[] = Array.isArray(urgentRes.data) ? urgentRes.data : [];

  const anyErr = plansRes.error || recsRes.error || summaryRes.error || urgentRes.error;

  const fmtRupees = (n: any): string => {
    const num = Number(n ?? 0);
    if (!isFinite(num)) return '0';
    return '₹' + num.toLocaleString('en-IN');
  };

  const planCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => <span>{r.fiscal_year ?? '—'}</span> },
    { key: 'total_realized_gain_rupees', header: 'Realized Gain', render: (r: any) => <span>{fmtRupees(r.total_realized_gain_rupees)}</span> },
    { key: 'total_realized_loss_rupees', header: 'Realized Loss', render: (r: any) => <span>{fmtRupees(r.total_realized_loss_rupees)}</span> },
    { key: 'net_position_rupees', header: 'Net Position', render: (r: any) => <span>{fmtRupees(r.net_position_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'recommendations_count', header: 'Recs', render: (r: any) => <span>{r.recommendations_count ?? 0}</span> },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => <span>{r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleDateString() : '—'}</span> },
  ];

  const urgentCols: Column<any>[] = [
    { key: 'urgency', header: 'Urgency', render: (r: any) => <span>{r.urgency ?? '—'}</span> },
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => <span>{r.fiscal_year ?? '—'}</span> },
    { key: 'recommendation', header: 'Recommendation', render: (r: any) => <span>{r.recommendation ?? '—'}</span> },
    { key: 'estimated_savings_rupees', header: 'Est. Savings', render: (r: any) => <span>{fmtRupees(r.estimated_savings_rupees)}</span> },
    { key: 'days_pending', header: 'Days Pending', render: (r: any) => <span>{r.days_pending ?? 0}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span> },
  ];

  const recCols: Column<any>[] = [
    { key: 'urgency', header: 'Urgency', render: (r: any) => <span>{r.urgency ?? '—'}</span> },
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => <span>{r.fiscal_year ?? '—'}</span> },
    { key: 'recommendation', header: 'Recommendation', render: (r: any) => <span>{r.recommendation ?? '—'}</span> },
    { key: 'estimated_savings_rupees', header: 'Est. Savings', render: (r: any) => <span>{fmtRupees(r.estimated_savings_rupees)}</span> },
    { key: 'founder_decision', header: 'Decision', render: (r: any) => <span>{r.founder_decision ?? 'pending'}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—'}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span> },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Investor Tax-Loss Harvesting Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Offset gains with strategic losses. Track harvesting plans, recommendations & founder decisions (r1865).
      </p>

      {anyErr ? (
        <div style={{ padding: 12, background: '#fee', border: '1px solid #fcc', borderRadius: 6, marginBottom: 16, color: '#900' }}>
          Error loading data: {String(anyErr.message ?? anyErr)}
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 12 }}>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Plans</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.total_plans ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#ecfdf5', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#065f46' }}>Active Plans</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#065f46' }}>{summary?.active_plans ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Planned</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.planned_plans ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Superseded</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.superseded_plans ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Recs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.total_recommendations ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#ecfdf5', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#065f46' }}>Accepted</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#065f46' }}>{summary?.accepted_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#fff5f5', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#900' }}>Declined</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#900' }}>{summary?.declined_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#fffbeb', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#854d0e' }}>Deferred</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#854d0e' }}>{summary?.deferred_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#eff6ff', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#1e40af' }}>Pending</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#1e40af' }}>{summary?.pending_count ?? 0}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Realized Gain</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summary?.total_realized_gain_rupees)}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Realized Loss</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summary?.total_realized_loss_rupees)}</div>
          </div>
          <div style={{ padding: 12, background: '#f6f8fa', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Est. Total Savings</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summary?.total_estimated_savings_rupees)}</div>
          </div>
          <div style={{ padding: 12, background: '#ecfdf5', borderRadius: 6 }}>
            <div style={{ fontSize: 12, color: '#065f46' }}>Accepted Savings</div>
            <div style={{ fontSize: 18, fontWeight: 700, color: '#065f46' }}>{fmtRupees(summary?.accepted_savings_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Urgent Pending Recommendations</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Critical & important recommendations awaiting founder decision.
        </p>
        <DataTable rows={urgent} columns={urgentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Harvesting Plans</h2>
        <DataTable rows={plans} columns={planCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Recommendations</h2>
        <DataTable rows={recs} columns={recCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
