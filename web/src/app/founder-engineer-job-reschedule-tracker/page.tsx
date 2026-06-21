import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Reschedule = {
  id: string;
  repair_job_id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  original_scheduled_at: string;
  new_scheduled_at: string;
  reschedule_reason: string;
  requested_by: string;
  requested_at: string;
  customer_impact_score: number;
  delay_hours: number | null;
};

type Compensation = {
  id: string;
  reschedule_id: string;
  compensation_type: string;
  applied_at: string;
  applied_by_email: string | null;
  value_rupees: number;
  engineer_user_id: string;
  reschedule_reason: string;
};

type Summary = {
  total_reschedules: number;
  high_impact_count: number;
  total_compensation_rupees: number;
  avg_impact_score: number;
  engineer_initiated: number;
  hospital_initiated: number;
  founder_initiated: number;
};

type TopEngineer = {
  engineer_user_id: string;
  engineer_email: string | null;
  reschedule_count: number;
  avg_impact: number;
  high_impact_count: number;
};

type HighImpact = {
  id: string;
  repair_job_id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  reschedule_reason: string;
  requested_by: string;
  requested_at: string;
  customer_impact_score: number;
  delay_hours: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reschedules, compensations, summary, topEngineers, highImpact] = await Promise.all([
    sb.rpc('list_reschedules_r1756', { p_limit: 100 }),
    sb.rpc('list_compensations_r1756', { p_limit: 100 }),
    sb.rpc('reschedule_summary_r1756'),
    sb.rpc('top_reschedule_engineers_r1756', { p_limit: 20 }),
    sb.rpc('high_impact_reschedules_r1756', { p_limit: 50 }),
  ]);

  const rows: Reschedule[] = (reschedules.data as Reschedule[]) ?? [];
  const comps: Compensation[] = (compensations.data as Compensation[]) ?? [];
  const sumRow: Summary | null = Array.isArray(summary.data) && summary.data.length > 0
    ? (summary.data[0] as Summary)
    : null;
  const topEng: TopEngineer[] = (topEngineers.data as TopEngineer[]) ?? [];
  const high: HighImpact[] = (highImpact.data as HighImpact[]) ?? [];

  const rescheduleCols: Column<Reschedule>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'reschedule_reason', header: 'Reason', render: (r: any) => r.reschedule_reason },
    { key: 'requested_by', header: 'By', render: (r: any) => r.requested_by },
    { key: 'customer_impact_score', header: 'Impact', render: (r: any) => `${r.customer_impact_score}/5` },
    { key: 'delay_hours', header: 'Delay (h)', render: (r: any) => r.delay_hours ?? '—' },
    { key: 'repair_job_id', header: 'Job', render: (r: any) => String(r.repair_job_id).slice(0, 8) },
  ];

  const compCols: Column<Compensation>[] = [
    { key: 'applied_at', header: 'Applied', render: (r: any) => new Date(r.applied_at).toLocaleString() },
    { key: 'compensation_type', header: 'Type', render: (r: any) => r.compensation_type },
    { key: 'value_rupees', header: 'Value (Rs)', render: (r: any) => `Rs ${r.value_rupees}` },
    { key: 'applied_by_email', header: 'Applied By', render: (r: any) => r.applied_by_email ?? '—' },
    { key: 'reschedule_reason', header: 'Reason', render: (r: any) => r.reschedule_reason },
  ];

  const topCols: Column<TopEngineer>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'reschedule_count', header: 'Reschedules', render: (r: any) => r.reschedule_count },
    { key: 'avg_impact', header: 'Avg Impact', render: (r: any) => r.avg_impact },
    { key: 'high_impact_count', header: 'High Impact', render: (r: any) => r.high_impact_count },
  ];

  const highCols: Column<HighImpact>[] = [
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'reschedule_reason', header: 'Reason', render: (r: any) => r.reschedule_reason },
    { key: 'customer_impact_score', header: 'Impact', render: (r: any) => `${r.customer_impact_score}/5` },
    { key: 'delay_hours', header: 'Delay (h)', render: (r: any) => r.delay_hours ?? '—' },
    { key: 'requested_by', header: 'By', render: (r: any) => r.requested_by },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Job Reschedule Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track reschedule patterns, customer impact (1–5), and compensation applied. High impact = score &gt;= 4.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        {sumRow ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
            <Card label="Total Reschedules" value={String(sumRow.total_reschedules)} />
            <Card label="High Impact" value={String(sumRow.high_impact_count)} />
            <Card label="Total Compensation" value={`Rs ${sumRow.total_compensation_rupees}`} />
            <Card label="Avg Impact Score" value={String(sumRow.avg_impact_score)} />
            <Card label="Engineer Initiated" value={String(sumRow.engineer_initiated)} />
            <Card label="Hospital Initiated" value={String(sumRow.hospital_initiated)} />
            <Card label="Founder Initiated" value={String(sumRow.founder_initiated)} />
          </div>
        ) : (
          <p style={{ color: '#888' }}>No summary data.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Reschedules</h2>
        <DataTable rows={rows} columns={rescheduleCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>High Impact (score &gt;= 4)</h2>
        <DataTable rows={high} columns={highCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Reschedule Engineers</h2>
        <DataTable rows={topEng} columns={topCols} rowKey={(r, i) => String(r.engineer_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Compensations Applied</h2>
        <DataTable rows={comps} columns={compCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
