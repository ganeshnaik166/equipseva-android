import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AnyRow = Record<string, unknown> & { id?: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [topA, sevA, typeA, engA, openA, tierA, expA] = await Promise.all([
    supabase.rpc('r2944_top_anomalies'),
    supabase.rpc('r2944_severity_rollup'),
    supabase.rpc('r2944_anomaly_type_breakdown'),
    supabase.rpc('r2944_engineer_offenders'),
    supabase.rpc('r2944_open_escalations'),
    supabase.rpc('r2944_tier_rollup'),
    supabase.rpc('r2944_founder_exposure'),
  ]);

  const top = (topA.data ?? []) as AnyRow[];
  const sev = (sevA.data ?? []) as AnyRow[];
  const types = (typeA.data ?? []) as AnyRow[];
  const eng = (engA.data ?? []) as AnyRow[];
  const open = (openA.data ?? []) as AnyRow[];
  const tier = (tierA.data ?? []) as AnyRow[];
  const exp = (expA.data ?? []) as AnyRow[];

  const topCols: Column<AnyRow>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => String(r.customer_org_name ?? '') },
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'anomaly_type', header: 'Type', render: (r) => String(r.anomaly_type ?? '') },
    { key: 'severity', header: 'Severity', render: (r) => String(r.severity ?? '') },
    { key: 'anomaly_score', header: 'Score', render: (r) => String(r.anomaly_score ?? '') },
    { key: 'actual_visits', header: 'Actual', render: (r) => String(r.actual_visits ?? '') },
    { key: 'expected_visits', header: 'Expected', render: (r) => String(r.expected_visits ?? '') },
  ];

  const sevCols: Column<AnyRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => String(r.severity ?? '') },
    { key: 'signal_count', header: 'Signals', render: (r) => String(r.signal_count ?? '') },
    { key: 'avg_score', header: 'Avg Score', render: (r) => String(r.avg_score ?? '') },
  ];

  const typeCols: Column<AnyRow>[] = [
    { key: 'anomaly_type', header: 'Type', render: (r) => String(r.anomaly_type ?? '') },
    { key: 'total', header: 'Total', render: (r) => String(r.total ?? '') },
    { key: 'critical_count', header: 'Critical', render: (r) => String(r.critical_count ?? '') },
    { key: 'high_count', header: 'High', render: (r) => String(r.high_count ?? '') },
  ];

  const engCols: Column<AnyRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'signal_count', header: 'Signals', render: (r) => String(r.signal_count ?? '') },
    { key: 'avg_score', header: 'Avg Score', render: (r) => String(r.avg_score ?? '') },
    { key: 'critical_count', header: 'Critical', render: (r) => String(r.critical_count ?? '') },
  ];

  const openCols: Column<AnyRow>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => String(r.customer_org_name ?? '') },
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'escalation_tier', header: 'Tier', render: (r) => String(r.escalation_tier ?? '') },
    { key: 'status', header: 'Status', render: (r) => String(r.status ?? '') },
    { key: 'assigned_to', header: 'Assigned To', render: (r) => String(r.assigned_to ?? '') },
    { key: 'credit_rupees', header: 'Credit (INR)', render: (r) => String(r.credit_rupees ?? '') },
  ];

  const tierCols: Column<AnyRow>[] = [
    { key: 'escalation_tier', header: 'Tier', render: (r) => String(r.escalation_tier ?? '') },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count ?? '') },
    { key: 'resolved_count', header: 'Resolved', render: (r) => String(r.resolved_count ?? '') },
    { key: 'total_credit', header: 'Total Credit (INR)', render: (r) => String(r.total_credit ?? '') },
  ];

  const expCols: Column<AnyRow>[] = [
    { key: 'metric', header: 'Metric', render: (r) => String(r.metric ?? '') },
    { key: 'value', header: 'Value', render: (r) => String(r.value ?? '') },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Customer Monthly Engineer Site-Visit Anomaly Detection & Auto-Escalation</h1>
        <p style={{ color: '#666', marginTop: 6 }}>Round r2944 — detect under/over visits, GPS mismatches, signature gaps; route to tiered escalation with credit exposure.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Founder Exposure Snapshot</h2>
        <DataTable rows={exp} columns={expCols} emptyMessage="No exposure metrics" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Anomaly Signals</h2>
        <DataTable rows={top} columns={topCols} emptyMessage="No anomalies" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Severity Rollup</h2>
        <DataTable rows={sev} columns={sevCols} emptyMessage="No severity data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Anomaly Type Breakdown</h2>
        <DataTable rows={types} columns={typeCols} emptyMessage="No type data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Offender Ranking</h2>
        <DataTable rows={eng} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open Escalations</h2>
        <DataTable rows={open} columns={openCols} emptyMessage="No open escalations" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Escalation Tier Rollup</h2>
        <DataTable rows={tier} columns={tierCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
