import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [outcomesRes, proofRes, focusRes, kindRes, funnelRes, trendRes, summaryRes] = await Promise.all([
    supabase.rpc('list_outcomes_r2643'),
    supabase.rpc('list_proof_log_r2643'),
    supabase.rpc('top_value_focus_r2643'),
    supabase.rpc('outcome_kind_distribution_r2643'),
    supabase.rpc('status_funnel_r2643'),
    supabase.rpc('quarterly_outcome_trend_r2643'),
    supabase.rpc('total_value_summary_r2643'),
  ]);

  const outcomes = (outcomesRes.data ?? []) as any[];
  const proof = (proofRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const kind = (kindRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const s = summary[0] ?? {};

  const fmtCr = (n: number | null | undefined) => {
    const v = Number(n ?? 0);
    if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
    if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
    return `Rs ${v.toLocaleString('en-IN')}`;
  };

  const outcomeColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'our_uptime_pct', header: 'Uptime', render: (r: any) => `${r.our_uptime_pct}%` },
    { key: 'clinical_outcome_kind', header: 'Outcome', render: (r: any) => r.clinical_outcome_kind },
    { key: 'value_estimate_rupees', header: 'Value', render: (r: any) => fmtCr(r.value_estimate_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const proofColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'proof_at', header: 'When', render: (r: any) => new Date(r.proof_at).toLocaleDateString('en-IN') },
    { key: 'proof_kind', header: 'Kind', render: (r: any) => r.proof_kind },
    { key: 'reach', header: 'Reach', render: (r: any) => r.reach },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'clinical_outcome_kind', header: 'Outcome', render: (r: any) => r.clinical_outcome_kind },
    { key: 'value_estimate_rupees', header: 'Value', render: (r: any) => fmtCr(r.value_estimate_rupees) },
    { key: 'our_uptime_pct', header: 'Uptime', render: (r: any) => `${r.our_uptime_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindColumns: Column<any>[] = [
    { key: 'clinical_outcome_kind', header: 'Outcome', render: (r: any) => r.clinical_outcome_kind },
    { key: 'outcome_count', header: 'Count', render: (r: any) => r.outcome_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'avg_uptime', header: 'Avg Uptime', render: (r: any) => `${r.avg_uptime ?? 0}%` },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome_count', header: 'Count', render: (r: any) => r.outcome_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'outcome_count', header: 'Count', render: (r: any) => r.outcome_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'published_count', header: 'Published', render: (r: any) => r.published_count },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly Clinical Outcome Link</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Link our uptime to chain clinical outcomes quarter-by-quarter & turn proof into board / investor / conference share.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Outcomes</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{s.total_outcomes ?? 0}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Value Linked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtCr(s.total_value_rupees)}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Published Value</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtCr(s.published_value_rupees)}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Uptime</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{s.avg_uptime ?? 0}%</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Proof Events</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{s.total_proof_events ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Value Focus (Not Yet Published)</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No outcomes to focus on"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.chain_name}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Clinical Outcome Links</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeColumns}
          emptyMessage="No outcome records"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Proof Log</h2>
        <DataTable
          rows={proof}
          columns={proofColumns}
          emptyMessage="No proof events logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: 24, marginBottom: 32 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Outcome Kind Distribution</h2>
          <DataTable
            rows={kind}
            columns={kindColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.clinical_outcome_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly Trend</h2>
          <DataTable
            rows={trend}
            columns={trendColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
