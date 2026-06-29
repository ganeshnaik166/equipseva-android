import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { metric: string; value: string };
type RegionRow = { region: string; total_audits: number; completed: number; overdue: number; avg_compliance: number | null; total_shrinkage: number };
type EngineerRow = { engineer_label: string; region: string; audits_count: number; shrinkage_rupees: number; avg_compliance: number | null };
type DiscRow = { part_sku: string; part_name: string; severity: string; discrepancy_type: string; variance_qty: number; unit_cost_rupees: number; engineer_label: string; customer_site: string; reported_at: string };
type TypeRow = { discrepancy_type: string; total_count: number; resolved_count: number; total_loss_rupees: number };
type OverdueRow = { engineer_label: string; region: string; customer_site: string; truck_plate: string; scheduled_at: string; notes: string | null };
type RecentRow = { engineer_label: string; region: string; customer_site: string; status: string; parts_scanned: number; parts_expected: number; compliance_score: number; shrinkage_value_rupees: number; completed_at: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, byRegion, topEng, openCrit, typeBreak, overdue, recent] = await Promise.all([
    supabase.rpc('founder_r2914_summary_kpis'),
    supabase.rpc('founder_r2914_audits_by_region'),
    supabase.rpc('founder_r2914_top_shrinkage_engineers'),
    supabase.rpc('founder_r2914_open_critical_discrepancies'),
    supabase.rpc('founder_r2914_discrepancy_type_breakdown'),
    supabase.rpc('founder_r2914_overdue_audits'),
    supabase.rpc('founder_r2914_recent_audits'),
  ]);

  const kpiRows: Kpi[] = (kpis.data ?? []) as Kpi[];
  const regionRows: RegionRow[] = (byRegion.data ?? []) as RegionRow[];
  const engRows: EngineerRow[] = (topEng.data ?? []) as EngineerRow[];
  const critRows: DiscRow[] = (openCrit.data ?? []) as DiscRow[];
  const typeRows: TypeRow[] = (typeBreak.data ?? []) as TypeRow[];
  const overdueRows: OverdueRow[] = (overdue.data ?? []) as OverdueRow[];
  const recentRows: RecentRow[] = (recent.data ?? []) as RecentRow[];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'total', header: 'Audits', render: (r) => r.total_audits },
    { key: 'done', header: 'Completed', render: (r) => r.completed },
    { key: 'over', header: 'Overdue', render: (r) => r.overdue },
    { key: 'comp', header: 'Avg Compliance %', render: (r) => r.avg_compliance ?? '—' },
    { key: 'shrink', header: 'Shrinkage ₹', render: (r) => r.total_shrinkage?.toLocaleString() ?? 0 },
  ];

  const engCols: Column<EngineerRow>[] = [
    { key: 'eng', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'aud', header: 'Audits', render: (r) => r.audits_count },
    { key: 'shrink', header: 'Shrinkage ₹', render: (r) => r.shrinkage_rupees?.toLocaleString() ?? 0 },
    { key: 'comp', header: 'Avg Compliance %', render: (r) => r.avg_compliance ?? '—' },
  ];

  const critCols: Column<DiscRow>[] = [
    { key: 'sku', header: 'SKU', render: (r) => r.part_sku },
    { key: 'name', header: 'Part', render: (r) => r.part_name },
    { key: 'sev', header: 'Severity', render: (r) => r.severity },
    { key: 'type', header: 'Type', render: (r) => r.discrepancy_type },
    { key: 'var', header: 'Variance', render: (r) => r.variance_qty },
    { key: 'cost', header: 'Unit ₹', render: (r) => r.unit_cost_rupees?.toLocaleString() ?? 0 },
    { key: 'eng', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'site', header: 'Site', render: (r) => r.customer_site },
    { key: 'when', header: 'Reported', render: (r) => new Date(r.reported_at).toLocaleString() },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'type', header: 'Discrepancy Type', render: (r) => r.discrepancy_type },
    { key: 'cnt', header: 'Count', render: (r) => r.total_count },
    { key: 'res', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'loss', header: 'Total Loss ₹', render: (r) => r.total_loss_rupees?.toLocaleString() ?? 0 },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'eng', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'site', header: 'Customer Site', render: (r) => r.customer_site },
    { key: 'plate', header: 'Truck', render: (r) => r.truck_plate },
    { key: 'sched', header: 'Scheduled', render: (r) => new Date(r.scheduled_at).toLocaleString() },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'eng', header: 'Engineer', render: (r) => r.engineer_label },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'site', header: 'Site', render: (r) => r.customer_site },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'scan', header: 'Scanned/Expected', render: (r) => `${r.parts_scanned}/${r.parts_expected}` },
    { key: 'comp', header: 'Compliance %', render: (r) => r.compliance_score },
    { key: 'shrink', header: 'Shrinkage ₹', render: (r) => r.shrinkage_value_rupees?.toLocaleString() ?? 0 },
    { key: 'done', header: 'Completed', render: (r) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '—' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Monthly Customer-Site Spare-Parts Inventory Truck Audit
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Monthly on-site truck inventory audits across engineer fleet — track shrinkage, compliance & open discrepancies.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Summary KPIs</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '12px' }}>
          {kpiRows.map((k) => (
            <div key={k.metric} style={{ border: '1px solid #e5e5e5', borderRadius: '8px', padding: '16px', background: '#fafafa' }}>
              <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{k.metric}</div>
              <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Audits By Region</h2>
        <DataTable rows={regionRows} columns={regionCols} emptyMessage="No regional data" rowKey={(r, i) => String(r.region ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Shrinkage Engineers</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String(r.engineer_label ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Open Critical & High Discrepancies</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No open critical items" rowKey={(r, i) => String(r.part_sku + i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Discrepancy Type Breakdown</h2>
        <DataTable rows={typeRows} columns={typeCols} emptyMessage="No discrepancies" rowKey={(r, i) => String(r.discrepancy_type ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Overdue & Cancelled Audits</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue audits" rowKey={(r, i) => String(r.truck_plate + i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Audits (last 25)</h2>
        <DataTable rows={recentRows} columns={recentCols} emptyMessage="No recent audits" rowKey={(r, i) => String(r.engineer_label + i)} />
      </section>
    </div>
  );
}
