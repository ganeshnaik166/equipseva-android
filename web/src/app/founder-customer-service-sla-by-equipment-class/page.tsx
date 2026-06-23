import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overview, byCategory, byClass, bySeverity, recentBreaches, topCauses, crosstab] = await Promise.all([
    sb.rpc('founder_cs_sla_overview_r2316'),
    sb.rpc('founder_cs_sla_by_category_r2316'),
    sb.rpc('founder_cs_sla_by_class_r2316'),
    sb.rpc('founder_cs_sla_by_severity_r2316'),
    sb.rpc('founder_cs_sla_recent_breaches_r2316'),
    sb.rpc('founder_cs_sla_top_causes_r2316'),
    sb.rpc('founder_cs_sla_category_cause_crosstab_r2316'),
  ]);

  const ov = (overview.data?.[0] ?? {}) as Record<string, unknown>;

  const categoryCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Equipment Category', render: (r) => String(r.equipment_category) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_response_min', header: 'Avg Response (min)', render: (r) => String(r.avg_response_min ?? '-') },
    { key: 'avg_resolve_min', header: 'Avg Resolve (min)', render: (r) => String(r.avg_resolve_min ?? '-') },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
    { key: 'breach_pct', header: 'Breach %', render: (r) => String(r.breach_pct ?? '-') },
  ];

  const classCols: Column<any>[] = [
    { key: 'equipment_class', header: 'Class', render: (r) => String(r.equipment_class) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_response_min', header: 'Avg Response (min)', render: (r) => String(r.avg_response_min ?? '-') },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
    { key: 'breach_pct', header: 'Breach %', render: (r) => String(r.breach_pct ?? '-') },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r) => String(r.severity) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_response_min', header: 'Avg Response (min)', render: (r) => String(r.avg_response_min ?? '-') },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
  ];

  const breachCols: Column<any>[] = [
    { key: 'ticket_code', header: 'Ticket', render: (r) => String(r.ticket_code) },
    { key: 'equipment_category', header: 'Category', render: (r) => String(r.equipment_category) },
    { key: 'equipment_class', header: 'Class', render: (r) => String(r.equipment_class) },
    { key: 'severity', header: 'Severity', render: (r) => String(r.severity) },
    { key: 'target_response_min', header: 'Target (min)', render: (r) => String(r.target_response_min) },
    { key: 'actual_response_min', header: 'Actual (min)', render: (r) => String(r.actual_response_min ?? '-') },
    { key: 'minutes_over', header: 'Min Over', render: (r) => String(r.minutes_over) },
    { key: 'cause_category', header: 'Cause', render: (r) => String(r.cause_category ?? '-') },
    { key: 'cause_notes', header: 'Notes', render: (r) => String(r.cause_notes ?? '-') },
  ];

  const causeCols: Column<any>[] = [
    { key: 'cause_category', header: 'Cause', render: (r) => String(r.cause_category) },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
    { key: 'total_minutes_over', header: 'Total Min Over', render: (r) => String(r.total_minutes_over) },
    { key: 'avg_minutes_over', header: 'Avg Min Over', render: (r) => String(r.avg_minutes_over ?? '-') },
  ];

  const crosstabCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => String(r.equipment_category) },
    { key: 'cause_category', header: 'Cause', render: (r) => String(r.cause_category) },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
    { key: 'avg_minutes_over', header: 'Avg Min Over', render: (r) => String(r.avg_minutes_over ?? '-') },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Customer Service-SLA Adherence by Equipment Class</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Per equipment category (CT / MRI / ventilator etc.) the avg response time, breach percent & cause.
        Critical-class SLA target &lt;= 30 min; high &lt;= 60 min; normal &lt;= 240 min.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Total Tickets" value={String(ov.total_tickets ?? '-')} />
        <Card label="Avg Response (min)" value={String(ov.avg_response_min ?? '-')} />
        <Card label="Response Breach %" value={String(ov.response_breach_pct ?? '-')} />
        <Card label="Open Unresolved" value={String(ov.open_unresolved ?? '-')} />
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>By Equipment Category</h2>
      <DataTable columns={categoryCols} rows={byCategory.data ?? []} rowKey={(_, i) => String(i)} emptyMessage="No category data yet." />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>By Equipment Class (A / B / C / D)</h2>
      <DataTable columns={classCols} rows={byClass.data ?? []} rowKey={(_, i) => String(i)} emptyMessage="No class data yet." />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>By Severity</h2>
      <DataTable columns={severityCols} rows={bySeverity.data ?? []} rowKey={(_, i) => String(i)} emptyMessage="No severity data yet." />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Recent SLA Breaches</h2>
      <DataTable columns={breachCols} rows={recentBreaches.data ?? []} rowKey={(_, i) => String(i)} emptyMessage="No breaches recorded." />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top Root Causes (Pareto)</h2>
      <DataTable columns={causeCols} rows={topCauses.data ?? []} rowKey={(_, i) => String(i)} emptyMessage="No cause data yet." />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Category × Cause Crosstab</h2>
      <DataTable columns={crosstabCols} rows={crosstab.data ?? []} rowKey={(_, i) => String(i)} emptyMessage="No crosstab data yet." />
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
