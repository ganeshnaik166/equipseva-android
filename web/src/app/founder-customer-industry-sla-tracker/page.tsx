import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TargetRow = {
  id: string;
  segment: string;
  segment_label: string;
  response_target_hours: number;
  resolution_target_hours: number;
  uptime_target_pct: number;
  penalty_rate_pct: number;
  priority_rank: number;
  notes: string | null;
};

type ComplianceRow = {
  id: string;
  customer_email: string;
  segment: string;
  period_start: string;
  period_end: string;
  jobs_total: number;
  response_compliance_pct: number | null;
  resolution_compliance_pct: number | null;
  breach_count: number;
  penalty_amount_rupees: number;
  status: string;
};

type RollupRow = {
  segment: string;
  segment_label: string;
  response_target_hours: number;
  resolution_target_hours: number;
  uptime_target_pct: number;
  customers_tracked: number;
  total_jobs: number;
  avg_response_compliance_pct: number | null;
  avg_resolution_compliance_pct: number | null;
  total_breaches: number;
  total_penalties_rupees: number;
};

type BreachRow = {
  customer_email: string;
  segment: string;
  segment_label: string;
  breach_count: number;
  penalty_amount_rupees: number;
  response_compliance_pct: number | null;
  resolution_compliance_pct: number | null;
  last_breach_at: string | null;
};

type Kpi = {
  total_segments: number;
  total_customers_tracked: number;
  total_jobs: number;
  total_breaches: number;
  total_penalty_rupees: number;
  worst_segment: string | null;
  best_segment: string | null;
  avg_response_compliance_pct: number | null;
  avg_resolution_compliance_pct: number | null;
};

function fmtPct(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—';
  return `${Number(v).toFixed(2)}%`;
}

function fmtRupees(v: number | null | undefined): string {
  if (v === null || v === undefined) return '₹0';
  return `₹${Number(v).toLocaleString('en-IN')}`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [targetsRes, complianceRes, rollupRes, breachesRes, kpiRes] = await Promise.all([
    supabase.rpc('r2364_list_targets'),
    supabase.rpc('r2364_list_compliance', { p_segment: null, p_limit: 200 }),
    supabase.rpc('r2364_segment_rollup'),
    supabase.rpc('r2364_top_breaches', { p_limit: 25 }),
    supabase.rpc('r2364_kpi_summary'),
  ]);

  const targets: TargetRow[] = (targetsRes.data ?? []) as TargetRow[];
  const compliance: ComplianceRow[] = (complianceRes.data ?? []) as ComplianceRow[];
  const rollup: RollupRow[] = (rollupRes.data ?? []) as RollupRow[];
  const breaches: BreachRow[] = (breachesRes.data ?? []) as BreachRow[];
  const kpiArr = (kpiRes.data ?? []) as Kpi[];
  const kpi: Kpi | null = kpiArr.length > 0 ? kpiArr[0] : null;

  const targetCols: Column<any>[] = [
    { key: 'priority_rank', header: 'Rank', render: (r: TargetRow) => <span>#{r.priority_rank}</span> },
    { key: 'segment_label', header: 'Segment', render: (r: TargetRow) => <strong>{r.segment_label}</strong> },
    { key: 'response_target_hours', header: 'Response <=', render: (r: TargetRow) => <span>{r.response_target_hours}h</span> },
    { key: 'resolution_target_hours', header: 'Resolve <=', render: (r: TargetRow) => <span>{r.resolution_target_hours}h</span> },
    { key: 'uptime_target_pct', header: 'Uptime >=', render: (r: TargetRow) => <span>{fmtPct(r.uptime_target_pct)}</span> },
    { key: 'penalty_rate_pct', header: 'Penalty', render: (r: TargetRow) => <span>{fmtPct(r.penalty_rate_pct)}</span> },
    { key: 'notes', header: 'Notes', render: (r: TargetRow) => <span style={{ color: '#666' }}>{r.notes ?? '—'}</span> },
  ];

  const rollupCols: Column<any>[] = [
    { key: 'segment_label', header: 'Segment', render: (r: RollupRow) => <strong>{r.segment_label}</strong> },
    { key: 'customers_tracked', header: 'Customers', render: (r: RollupRow) => <span>{r.customers_tracked}</span> },
    { key: 'total_jobs', header: 'Jobs', render: (r: RollupRow) => <span>{r.total_jobs}</span> },
    { key: 'avg_response_compliance_pct', header: 'Avg Response %', render: (r: RollupRow) => <span>{fmtPct(r.avg_response_compliance_pct)}</span> },
    { key: 'avg_resolution_compliance_pct', header: 'Avg Resolve %', render: (r: RollupRow) => <span>{fmtPct(r.avg_resolution_compliance_pct)}</span> },
    { key: 'total_breaches', header: 'Breaches', render: (r: RollupRow) => <span style={{ color: r.total_breaches > 0 ? '#c00' : '#0a0' }}>{r.total_breaches}</span> },
    { key: 'total_penalties_rupees', header: 'Penalties', render: (r: RollupRow) => <span>{fmtRupees(r.total_penalties_rupees)}</span> },
  ];

  const complianceCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: ComplianceRow) => <span>{r.customer_email}</span> },
    { key: 'segment', header: 'Segment', render: (r: ComplianceRow) => <span>{r.segment}</span> },
    { key: 'period_end', header: 'Period End', render: (r: ComplianceRow) => <span>{r.period_end}</span> },
    { key: 'jobs_total', header: 'Jobs', render: (r: ComplianceRow) => <span>{r.jobs_total}</span> },
    { key: 'response_compliance_pct', header: 'Response %', render: (r: ComplianceRow) => <span>{fmtPct(r.response_compliance_pct)}</span> },
    { key: 'resolution_compliance_pct', header: 'Resolve %', render: (r: ComplianceRow) => <span>{fmtPct(r.resolution_compliance_pct)}</span> },
    { key: 'breach_count', header: 'Breaches', render: (r: ComplianceRow) => <span style={{ color: r.breach_count > 0 ? '#c00' : '#0a0' }}>{r.breach_count}</span> },
    { key: 'penalty_amount_rupees', header: 'Penalty', render: (r: ComplianceRow) => <span>{fmtRupees(r.penalty_amount_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: ComplianceRow) => <span>{r.status}</span> },
  ];

  const breachCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: BreachRow) => <strong>{r.customer_email}</strong> },
    { key: 'segment_label', header: 'Segment', render: (r: BreachRow) => <span>{r.segment_label ?? r.segment}</span> },
    { key: 'breach_count', header: 'Breaches', render: (r: BreachRow) => <span style={{ color: '#c00' }}>{r.breach_count}</span> },
    { key: 'penalty_amount_rupees', header: 'Penalty', render: (r: BreachRow) => <span>{fmtRupees(r.penalty_amount_rupees)}</span> },
    { key: 'response_compliance_pct', header: 'Response %', render: (r: BreachRow) => <span>{fmtPct(r.response_compliance_pct)}</span> },
    { key: 'resolution_compliance_pct', header: 'Resolve %', render: (r: BreachRow) => <span>{fmtPct(r.resolution_compliance_pct)}</span> },
    { key: 'last_breach_at', header: 'Last Breach', render: (r: BreachRow) => <span>{r.last_breach_at ? new Date(r.last_breach_at).toLocaleString() : '—'}</span> },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.25rem' }}>Customer Industry SLA Tracker</h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Round 2364 · Per-segment SLA targets & per-customer compliance — super-specialty hospitals vs clinics
      </p>

      {kpi && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.75rem', marginBottom: '1.5rem' }}>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Segments</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpi.total_segments}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Customers Tracked</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpi.total_customers_tracked}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Total Jobs</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpi.total_jobs}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Total Breaches</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600, color: kpi.total_breaches > 0 ? '#c00' : '#0a0' }}>{kpi.total_breaches}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Penalty Rupees</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{fmtRupees(kpi.total_penalty_rupees)}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Worst Segment</div>
            <div style={{ fontSize: '1rem', fontWeight: 600, color: '#c00' }}>{kpi.worst_segment ?? '—'}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Best Segment</div>
            <div style={{ fontSize: '1rem', fontWeight: 600, color: '#0a0' }}>{kpi.best_segment ?? '—'}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#666' }}>Avg Response %</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{fmtPct(kpi.avg_response_compliance_pct)}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', marginBottom: '0.5rem' }}>Segment SLA Targets</h2>
        <p style={{ color: '#666', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
          Response &amp; resolution targets vary by industry — super-specialty =&gt; 1h response, clinic =&gt; 8h response
        </p>
        <DataTable
          rows={targets}
          rowKey={(r: TargetRow) => r.id}
          columns={targetCols}
          emptyMessage="No SLA targets configured."
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', marginBottom: '0.5rem' }}>Segment Rollup</h2>
        <DataTable
          rows={rollup}
          rowKey={(r: RollupRow) => r.segment}
          columns={rollupCols}
          emptyMessage="No rollup data yet."
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', marginBottom: '0.5rem' }}>Top Breaching Customers</h2>
        <DataTable
          rows={breaches}
          rowKey={(r: BreachRow) => `${r.customer_email}-${r.segment}`}
          columns={breachCols}
          emptyMessage="No breaches recorded — all customers compliant."
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', marginBottom: '0.5rem' }}>Per-Customer Compliance</h2>
        <DataTable
          rows={compliance}
          rowKey={(r: ComplianceRow) => r.id}
          columns={complianceCols}
          emptyMessage="No compliance records yet."
        />
      </section>
    </main>
  );
}
