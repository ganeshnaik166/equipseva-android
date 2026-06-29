import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: string };
type Breacher = { engineer_code: string; engineer_tier: string; sla_breaches: number; avg_latency_minutes: number; penalty_rupees: number };
type TierRow = { engineer_tier: string; eng_count: number; avg_latency: number; total_breaches: number; total_bonus: number; total_penalty: number };
type WindowRow = { message_window: string; msg_count: number; avg_latency: number; breach_pct: number };
type CustomerRow = { customer_org: string; msg_count: number; breached: number; avg_csat: number };
type SeverityRow = { issue_severity: string; sla_target_minutes: number; msg_count: number; avg_latency: number; breaches: number };
type PerformerRow = { engineer_code: string; engineer_tier: string; avg_latency_minutes: number; incentive_bonus_rupees: number; rank_in_tier: number };
type UnrespondedRow = { customer_org: string; engineer_code: string; message_sent_at: string; issue_severity: string; sla_target_minutes: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [kpiR, breachR, tierR, windowR, custR, sevR, perfR, unrespR] = await Promise.all([
    supabase.rpc('founder_r2912_kpi_summary'),
    supabase.rpc('founder_r2912_top_breachers'),
    supabase.rpc('founder_r2912_tier_rollup'),
    supabase.rpc('founder_r2912_window_split'),
    supabase.rpc('founder_r2912_customer_pain'),
    supabase.rpc('founder_r2912_severity_heatmap'),
    supabase.rpc('founder_r2912_top_performers'),
    supabase.rpc('founder_r2912_unresponded'),
  ]);

  const kpis = (kpiR.data ?? []) as KpiRow[];
  const breachers = (breachR.data ?? []) as Breacher[];
  const tiers = (tierR.data ?? []) as TierRow[];
  const windows = (windowR.data ?? []) as WindowRow[];
  const customers = (custR.data ?? []) as CustomerRow[];
  const severities = (sevR.data ?? []) as SeverityRow[];
  const performers = (perfR.data ?? []) as PerformerRow[];
  const unresponded = (unrespR.data ?? []) as UnrespondedRow[];

  const kpiCols: Column<KpiRow>[] = [
    { key: 'metric', header: 'Metric', render: (r) => r.metric },
    { key: 'value', header: 'Value', render: (r) => r.value },
  ];
  const breachCols: Column<Breacher>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'sla_breaches', header: 'SLA Breaches', render: (r) => String(r.sla_breaches) },
    { key: 'avg_latency_minutes', header: 'Avg Latency (min)', render: (r) => String(r.avg_latency_minutes) },
    { key: 'penalty_rupees', header: 'Penalty (Rs)', render: (r) => String(r.penalty_rupees) },
  ];
  const tierCols: Column<TierRow>[] = [
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'eng_count', header: 'Engineers', render: (r) => String(r.eng_count) },
    { key: 'avg_latency', header: 'Avg Latency', render: (r) => String(r.avg_latency) },
    { key: 'total_breaches', header: 'Breaches', render: (r) => String(r.total_breaches) },
    { key: 'total_bonus', header: 'Bonus (Rs)', render: (r) => String(r.total_bonus) },
    { key: 'total_penalty', header: 'Penalty (Rs)', render: (r) => String(r.total_penalty) },
  ];
  const windowCols: Column<WindowRow>[] = [
    { key: 'message_window', header: 'Window', render: (r) => r.message_window },
    { key: 'msg_count', header: 'Messages', render: (r) => String(r.msg_count) },
    { key: 'avg_latency', header: 'Avg Latency', render: (r) => String(r.avg_latency) },
    { key: 'breach_pct', header: 'Breach %', render: (r) => String(r.breach_pct) },
  ];
  const custCols: Column<CustomerRow>[] = [
    { key: 'customer_org', header: 'Customer Org', render: (r) => r.customer_org },
    { key: 'msg_count', header: 'Msgs', render: (r) => String(r.msg_count) },
    { key: 'breached', header: 'Breached', render: (r) => String(r.breached) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r) => String(r.avg_csat) },
  ];
  const sevCols: Column<SeverityRow>[] = [
    { key: 'issue_severity', header: 'Severity', render: (r) => r.issue_severity },
    { key: 'sla_target_minutes', header: 'SLA Target (min)', render: (r) => String(r.sla_target_minutes) },
    { key: 'msg_count', header: 'Msgs', render: (r) => String(r.msg_count) },
    { key: 'avg_latency', header: 'Avg Latency', render: (r) => String(r.avg_latency) },
    { key: 'breaches', header: 'Breaches', render: (r) => String(r.breaches) },
  ];
  const perfCols: Column<PerformerRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'avg_latency_minutes', header: 'Avg Latency', render: (r) => String(r.avg_latency_minutes) },
    { key: 'incentive_bonus_rupees', header: 'Bonus (Rs)', render: (r) => String(r.incentive_bonus_rupees) },
    { key: 'rank_in_tier', header: 'Rank', render: (r) => String(r.rank_in_tier) },
  ];
  const unrespCols: Column<UnrespondedRow>[] = [
    { key: 'customer_org', header: 'Customer Org', render: (r) => r.customer_org },
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'message_sent_at', header: 'Sent', render: (r) => r.message_sent_at },
    { key: 'issue_severity', header: 'Severity', render: (r) => r.issue_severity },
    { key: 'sla_target_minutes', header: 'SLA (min)', render: (r) => String(r.sla_target_minutes) },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer Monthly Engineer After-Hours WhatsApp-Response Latency</h1>
      <p style={{ color: '#666', marginTop: 8 }}>
        Founder console r2912 — how fast engineers reply on WhatsApp after-hours (evening & late-night windows). Track SLA breaches, tier roll-ups, customer pain, and unresponded escalations.
      </p>

      <section style={{ marginTop: 24, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px,1fr))', gap: 12 }}>
        {kpis.map((k) => (
          <div key={k.metric} style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.metric}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>KPI Summary</h2>
        <DataTable rows={kpis} columns={kpiCols} emptyMessage="No KPI data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Top SLA Breachers</h2>
        <DataTable rows={breachers} columns={breachCols} emptyMessage="No breachers" rowKey={(r, i) => String(r.engineer_code ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Tier Roll-up</h2>
        <DataTable rows={tiers} columns={tierCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.engineer_tier ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Window Split (evening vs late-night)</h2>
        <DataTable rows={windows} columns={windowCols} emptyMessage="No window data" rowKey={(r, i) => String(r.message_window ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Customer Pain Index</h2>
        <DataTable rows={customers} columns={custCols} emptyMessage="No customer data" rowKey={(r, i) => String(r.customer_org ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Severity Heatmap</h2>
        <DataTable rows={severities} columns={sevCols} emptyMessage="No severity data" rowKey={(r, i) => String(r.issue_severity ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Top Performers (zero breaches)</h2>
        <DataTable rows={performers} columns={perfCols} emptyMessage="No performers" rowKey={(r, i) => String(r.engineer_code ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Unresponded After-Hours Messages</h2>
        <DataTable rows={unresponded} columns={unrespCols} emptyMessage="None — all responded" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
