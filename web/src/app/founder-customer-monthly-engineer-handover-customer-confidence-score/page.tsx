import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KPI = {
  total_handovers: number;
  avg_delta: number | null;
  critical_count: number;
  red_count: number;
  unresolved_count: number;
  total_winback_cost: number;
  recovered_count: number;
};

type HandoverRow = {
  id: string;
  job_code: string;
  customer_name: string;
  hospital_city: string;
  prior_engineer: string;
  new_engineer: string;
  handover_date: string;
  confidence_pre: number;
  confidence_post: number;
  delta_score: number;
  primary_cause: string;
  severity: string;
  winback_action: string;
  resolved: boolean;
};

type CauseRow = {
  primary_cause: string;
  event_count: number;
  avg_delta: number;
  worst_delta: number;
};

type SeverityRow = {
  severity: string;
  event_count: number;
  avg_pre: number;
  avg_post: number;
  avg_delta: number;
};

type WinbackRow = {
  id: string;
  customer_name: string;
  action_type: string;
  taken_by: string;
  taken_at: string;
  outcome: string;
  recovery_score: number;
  cost_inr: number;
};

type AtRiskRow = {
  customer_name: string;
  hospital_city: string;
  worst_delta: number;
  events: number;
  unresolved_count: number;
  last_handover: string;
};

type EngineerRow = {
  engineer_name: string;
  handovers_received: number;
  avg_post_score: number;
  avg_delta: number;
  worst_delta: number;
};

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(digits);
}

function fmtInr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, listRes, causeRes, sevRes, winbackRes, atRiskRes, engRes] = await Promise.all([
    supabase.rpc('founder_r2792_handover_kpis'),
    supabase.rpc('founder_r2792_handover_list'),
    supabase.rpc('founder_r2792_cause_breakdown'),
    supabase.rpc('founder_r2792_severity_breakdown'),
    supabase.rpc('founder_r2792_winback_actions'),
    supabase.rpc('founder_r2792_at_risk_customers'),
    supabase.rpc('founder_r2792_engineer_handover_quality'),
  ]);

  const kpi: KPI = (kpiRes.data?.[0] as KPI) ?? {
    total_handovers: 0, avg_delta: 0, critical_count: 0, red_count: 0,
    unresolved_count: 0, total_winback_cost: 0, recovered_count: 0,
  };
  const handovers: HandoverRow[] = (listRes.data as HandoverRow[]) ?? [];
  const causes: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const severities: SeverityRow[] = (sevRes.data as SeverityRow[]) ?? [];
  const winbacks: WinbackRow[] = (winbackRes.data as WinbackRow[]) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[]) ?? [];
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];

  const kpiCards = [
    { label: 'Total handovers', value: String(kpi.total_handovers) },
    { label: 'Avg confidence delta', value: fmtNum(kpi.avg_delta) },
    { label: 'Critical events', value: String(kpi.critical_count) },
    { label: 'Red events', value: String(kpi.red_count) },
    { label: 'Unresolved', value: String(kpi.unresolved_count) },
    { label: 'Winback cost', value: fmtInr(kpi.total_winback_cost) },
    { label: 'Recovered', value: String(kpi.recovered_count) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Monthly Engineer Handover — Confidence Score
      </h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Round r2792 — pre vs post handover confidence, primary cause, and winback action per job.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpiCards.map((c) => (
          <div key={c.label} style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280' }}>{c.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{c.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Handover confidence events</h2>
        <DataTable
          rows={handovers}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: HandoverRow) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r: HandoverRow) => r.customer_name },
            { key: 'hospital_city', header: 'City', render: (r: HandoverRow) => r.hospital_city },
            { key: 'prior_engineer', header: 'Prior eng.', render: (r: HandoverRow) => r.prior_engineer },
            { key: 'new_engineer', header: 'New eng.', render: (r: HandoverRow) => r.new_engineer },
            { key: 'handover_date', header: 'Date', render: (r: HandoverRow) => r.handover_date },
            { key: 'confidence_pre', header: 'Pre', render: (r: HandoverRow) => fmtNum(r.confidence_pre) },
            { key: 'confidence_post', header: 'Post', render: (r: HandoverRow) => fmtNum(r.confidence_post) },
            { key: 'delta_score', header: 'Delta', render: (r: HandoverRow) => fmtNum(r.delta_score) },
            { key: 'primary_cause', header: 'Cause', render: (r: HandoverRow) => r.primary_cause },
            { key: 'severity', header: 'Severity', render: (r: HandoverRow) => r.severity },
            { key: 'winback_action', header: 'Winback', render: (r: HandoverRow) => r.winback_action },
            { key: 'resolved', header: 'Resolved', render: (r: HandoverRow) => (r.resolved ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: HandoverRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Cause breakdown</h2>
          <DataTable
            rows={causes}
            columns={[
              { key: 'primary_cause', header: 'Cause', render: (r: CauseRow) => r.primary_cause },
              { key: 'event_count', header: 'Events', render: (r: CauseRow) => String(r.event_count) },
              { key: 'avg_delta', header: 'Avg delta', render: (r: CauseRow) => fmtNum(r.avg_delta) },
              { key: 'worst_delta', header: 'Worst', render: (r: CauseRow) => fmtNum(r.worst_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: CauseRow, i: number) => String(r.primary_cause ?? i)}
          />
        </div>

        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Severity breakdown</h2>
          <DataTable
            rows={severities}
            columns={[
              { key: 'severity', header: 'Severity', render: (r: SeverityRow) => r.severity },
              { key: 'event_count', header: 'Events', render: (r: SeverityRow) => String(r.event_count) },
              { key: 'avg_pre', header: 'Avg pre', render: (r: SeverityRow) => fmtNum(r.avg_pre) },
              { key: 'avg_post', header: 'Avg post', render: (r: SeverityRow) => fmtNum(r.avg_post) },
              { key: 'avg_delta', header: 'Avg delta', render: (r: SeverityRow) => fmtNum(r.avg_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: SeverityRow, i: number) => String(r.severity ?? i)}
          />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          At-risk customers (delta &lt;= -1.0)
        </h2>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: AtRiskRow) => r.customer_name },
            { key: 'hospital_city', header: 'City', render: (r: AtRiskRow) => r.hospital_city },
            { key: 'worst_delta', header: 'Worst delta', render: (r: AtRiskRow) => fmtNum(r.worst_delta) },
            { key: 'events', header: 'Events', render: (r: AtRiskRow) => String(r.events) },
            { key: 'unresolved_count', header: 'Unresolved', render: (r: AtRiskRow) => String(r.unresolved_count) },
            { key: 'last_handover', header: 'Last handover', render: (r: AtRiskRow) => r.last_handover },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRiskRow, i: number) => String(r.customer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engineer handover quality</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'handovers_received', header: 'Handovers', render: (r: EngineerRow) => String(r.handovers_received) },
            { key: 'avg_post_score', header: 'Avg post score', render: (r: EngineerRow) => fmtNum(r.avg_post_score) },
            { key: 'avg_delta', header: 'Avg delta', render: (r: EngineerRow) => fmtNum(r.avg_delta) },
            { key: 'worst_delta', header: 'Worst delta', render: (r: EngineerRow) => fmtNum(r.worst_delta) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Winback actions log</h2>
        <DataTable
          rows={winbacks}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: WinbackRow) => r.customer_name },
            { key: 'action_type', header: 'Action', render: (r: WinbackRow) => r.action_type },
            { key: 'taken_by', header: 'By', render: (r: WinbackRow) => r.taken_by },
            { key: 'taken_at', header: 'When', render: (r: WinbackRow) => new Date(r.taken_at).toLocaleString('en-IN') },
            { key: 'outcome', header: 'Outcome', render: (r: WinbackRow) => r.outcome },
            { key: 'recovery_score', header: 'Recovery', render: (r: WinbackRow) => fmtNum(r.recovery_score) },
            { key: 'cost_inr', header: 'Cost', render: (r: WinbackRow) => fmtInr(r.cost_inr) },
          ]}
          emptyMessage="No data"
          rowKey={(r: WinbackRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
