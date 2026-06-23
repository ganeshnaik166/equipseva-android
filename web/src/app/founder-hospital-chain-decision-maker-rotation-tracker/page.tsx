import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  open_rotations: number;
  p0_existential: number;
  p1_critical: number;
  total_arr_at_risk_rupees: number;
  retained_last_90d: number;
  lost_last_90d: number;
  retention_rate_pct: number;
  avg_risk_score: number;
  overdue_actions: number;
};

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10_000_000) return `Rs ${(v / 10_000_000).toFixed(2)} Cr`;
  if (v >= 100_000) return `Rs ${(v / 100_000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  if (!email || !email.endsWith('@equipseva.com')) {
    return (
      <main style={{ padding: 24 }}>
        <h1>Forbidden</h1>
        <p>Founder access only.</p>
      </main>
    );
  }

  const [summaryRes, queueRes, overdueRes, riskRes, recentRes, detectRes, topActRes] = await Promise.all([
    supabase.rpc('founder_chain_rotation_summary_r2371'),
    supabase.rpc('founder_chain_rotation_open_queue_r2371'),
    supabase.rpc('founder_chain_rotation_overdue_actions_r2371'),
    supabase.rpc('founder_chain_rotation_risk_breakdown_r2371'),
    supabase.rpc('founder_chain_rotation_recent_outcomes_r2371'),
    supabase.rpc('founder_chain_rotation_detection_mix_r2371'),
    supabase.rpc('founder_chain_rotation_top_actions_r2371'),
  ]);

  const summary: SummaryRow = (summaryRes.data?.[0] ?? {
    open_rotations: 0, p0_existential: 0, p1_critical: 0,
    total_arr_at_risk_rupees: 0, retained_last_90d: 0, lost_last_90d: 0,
    retention_rate_pct: 0, avg_risk_score: 0, overdue_actions: 0,
  }) as SummaryRow;

  const queueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'arr_rupees', header: 'ARR', render: (r) => fmtRupees(r.arr_rupees) },
    { key: 'outgoing_label', header: 'Outgoing', render: (r) => r.outgoing_label },
    { key: 'incoming_label', header: 'Incoming', render: (r) => r.incoming_label },
    { key: 'risk_score', header: 'Risk', render: (r) => `${r.risk_score}/100` },
    { key: 'risk_category', header: 'Category', render: (r) => r.risk_category },
    { key: 'rotation_age_days', header: 'Age (d)', render: (r) => r.rotation_age_days },
    { key: 'open_actions', header: 'Open actions', render: (r) => r.open_actions },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'action_title', header: 'Action', render: (r) => r.action_title },
    { key: 'action_type', header: 'Type', render: (r) => r.action_type },
    { key: 'owner_label', header: 'Owner', render: (r) => r.owner_label },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date },
    { key: 'days_overdue', header: 'Days overdue', render: (r) => r.days_overdue },
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'risk_category', header: 'Risk', render: (r) => r.risk_category },
  ];

  const riskCols: Column<any>[] = [
    { key: 'risk_category', header: 'Risk category', render: (r) => r.risk_category },
    { key: 'rotation_count', header: 'Rotations', render: (r) => r.rotation_count },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r) => fmtRupees(r.arr_at_risk_rupees) },
    { key: 'hospital_count_at_risk', header: 'Hospitals', render: (r) => r.hospital_count_at_risk },
    { key: 'avg_risk_score', header: 'Avg score', render: (r) => r.avg_risk_score },
  ];

  const recentCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'outgoing_label', header: 'Outgoing', render: (r) => r.outgoing_label },
    { key: 'resolved_status', header: 'Outcome', render: (r) => r.resolved_status },
    { key: 'arr_rupees', header: 'ARR', render: (r) => fmtRupees(r.arr_rupees) },
    { key: 'days_to_resolve', header: 'Days to resolve', render: (r) => r.days_to_resolve },
    { key: 'outcome_summary', header: 'Summary', render: (r) => r.outcome_summary },
    { key: 'resolved_at', header: 'Resolved at', render: (r) => r.resolved_at ? new Date(r.resolved_at).toLocaleDateString('en-IN') : '—' },
  ];

  const detectCols: Column<any>[] = [
    { key: 'detection_source', header: 'Source', render: (r) => r.detection_source },
    { key: 'rotation_count', header: 'Count', render: (r) => r.rotation_count },
    { key: 'share_pct', header: 'Share %', render: (r) => `${r.share_pct}%` },
    { key: 'retained_count', header: 'Retained', render: (r) => r.retained_count },
    { key: 'lost_count', header: 'Lost', render: (r) => r.lost_count },
  ];

  const topActCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'risk_category', header: 'Risk', render: (r) => r.risk_category },
    { key: 'action_title', header: 'Action', render: (r) => r.action_title },
    { key: 'action_type', header: 'Type', render: (r) => r.action_type },
    { key: 'owner_label', header: 'Owner', render: (r) => r.owner_label },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date },
    { key: 'days_to_due', header: 'Days to due', render: (r) => r.days_to_due },
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Hospital chain decision-maker rotation tracker
      </h1>
      <p style={{ color: '#475569', marginBottom: 24, maxWidth: 900 }}>
        When a chain CXO, CEO, or Procurement Head rotates out, the relationship that won us
        the contract can vaporize overnight. This console logs every rotation, scores transition
        risk (0–100), and tracks the concrete action plan we must execute &gt;=30 days before
        the new decision-maker locks in their preferred vendor list. Risk categories: p0 existential
        &gt;= strategic chain &amp; champion gone &amp; cold incoming; p1 critical &gt;= tier1 chain or
        adversarial incoming; p2 elevated; p3 routine.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <Kpi label="Open rotations" value={String(summary.open_rotations)} />
        <Kpi label="P0 existential" value={String(summary.p0_existential)} tone="danger" />
        <Kpi label="P1 critical" value={String(summary.p1_critical)} tone="warn" />
        <Kpi label="ARR at risk" value={fmtRupees(summary.total_arr_at_risk_rupees)} />
        <Kpi label="Retained 90d" value={String(summary.retained_last_90d)} tone="good" />
        <Kpi label="Lost 90d" value={String(summary.lost_last_90d)} tone="danger" />
        <Kpi label="Retention rate" value={`${summary.retention_rate_pct}%`} />
        <Kpi label="Avg risk score" value={String(summary.avg_risk_score)} />
        <Kpi label="Overdue actions" value={String(summary.overdue_actions)} tone="warn" />
      </section>

      <Section title="Open rotation queue (risk-sorted)">
        <DataTable
          rows={(queueRes.data ?? []) as any[]}
          columns={queueCols}
          rowKey={(r: any) => String(r.id)}
          emptyMessage="No open chain rotations — every chain decision-maker is stable."
        />
      </Section>

      <Section title="Overdue action items">
        <DataTable
          rows={(overdueRes.data ?? []) as any[]}
          columns={overdueCols}
          rowKey={(r: any) => String(r.action_id)}
          emptyMessage="No overdue actions. Every retention play is on schedule."
        />
      </Section>

      <Section title="Risk-category breakdown">
        <DataTable
          rows={(riskRes.data ?? []) as any[]}
          columns={riskCols}
          rowKey={(r: any) => String(r.risk_category)}
          emptyMessage="No open rotations to break down."
        />
      </Section>

      <Section title="Top upcoming actions (next 25)">
        <DataTable
          rows={(topActRes.data ?? []) as any[]}
          columns={topActCols}
          rowKey={(r: any) => String(r.action_id)}
          emptyMessage="No pending actions on the books."
        />
      </Section>

      <Section title="Recent outcomes (last 90 days)">
        <DataTable
          rows={(recentRes.data ?? []) as any[]}
          columns={recentCols}
          rowKey={(r: any) => String(r.id)}
          emptyMessage="No rotations have resolved in the last 90 days."
        />
      </Section>

      <Section title="Detection-source mix">
        <DataTable
          rows={(detectRes.data ?? []) as any[]}
          columns={detectCols}
          rowKey={(r: any) => String(r.detection_source)}
          emptyMessage="No rotations logged yet."
        />
      </Section>
    </main>
  );
}

function Kpi({ label, value, tone }: { label: string; value: string; tone?: 'good' | 'warn' | 'danger' }) {
  const color = tone === 'danger' ? '#b91c1c' : tone === 'warn' ? '#b45309' : tone === 'good' ? '#15803d' : '#0f172a';
  return (
    <div style={{ border: '1px solid #e2e8f0', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#64748b', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
