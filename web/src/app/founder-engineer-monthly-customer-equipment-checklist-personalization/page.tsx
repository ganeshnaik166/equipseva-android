import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_personalizations: number;
  avg_variance: number;
  avg_csat: number;
  rework_rate_pct: number;
  supervisor_overrides: number;
  excellent_outcomes: number;
  failed_outcomes: number;
};

type EngineerRow = {
  engineer_name: string;
  total_rows: number;
  avg_variance: number;
  avg_csat: number;
  rework_count: number;
};

type ReasonRow = {
  personalization_reason: string;
  total: number;
  avg_variance: number;
  excellent_pct: number;
  poor_or_failed_pct: number;
};

type CategoryRow = {
  equipment_category: string;
  total: number;
  avg_variance: number;
  avg_csat: number;
  rework_count: number;
};

type RecentRow = {
  id: string;
  cycle_month: string;
  engineer_name: string;
  customer_name: string;
  equipment_label: string;
  equipment_category: string;
  baseline_checklist_items: number;
  customized_checklist_items: number;
  variance_score: number;
  outcome_quality: string;
  customer_csat: number;
  rework_required: boolean;
  approved_by_supervisor: boolean;
  personalization_reason: string;
  notes: string;
};

type AuditRow = {
  audit_month: string;
  engineer_name: string;
  total_personalizations: number;
  avg_variance: number;
  avg_csat: number;
  rework_rate_pct: number;
  supervisor_override_count: number;
  founder_disposition: string;
  recommended_action: string;
  reviewer: string;
};

type DispositionRow = {
  founder_disposition: string;
  engineers: number;
  avg_variance: number;
  avg_csat: number;
};

type HotspotRow = {
  engineer_name: string;
  customer_name: string;
  equipment_label: string;
  variance_score: number;
  outcome_quality: string;
  customer_csat: number;
  notes: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    perEngineerRes,
    reasonRes,
    categoryRes,
    recentRes,
    auditRes,
    dispositionRes,
    hotspotRes,
  ] = await Promise.all([
    supabase.rpc('r2838_kpi_summary'),
    supabase.rpc('r2838_per_engineer_breakdown'),
    supabase.rpc('r2838_reason_outcome_matrix'),
    supabase.rpc('r2838_equipment_category_drill'),
    supabase.rpc('r2838_recent_personalizations', { p_limit: 50 }),
    supabase.rpc('r2838_outcome_audit_rollup'),
    supabase.rpc('r2838_disposition_counts'),
    supabase.rpc('r2838_rework_hotspots'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_personalizations: 0,
    avg_variance: 0,
    avg_csat: 0,
    rework_rate_pct: 0,
    supervisor_overrides: 0,
    excellent_outcomes: 0,
    failed_outcomes: 0,
  };

  const engineers: EngineerRow[] = (perEngineerRes.data as EngineerRow[]) ?? [];
  const reasons: ReasonRow[] = (reasonRes.data as ReasonRow[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const recents: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];
  const audits: AuditRow[] = (auditRes.data as AuditRow[]) ?? [];
  const dispositions: DispositionRow[] = (dispositionRes.data as DispositionRow[]) ?? [];
  const hotspots: HotspotRow[] = (hotspotRes.data as HotspotRow[]) ?? [];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
          Engineer Monthly Customer Equipment Checklist Personalization
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Per-engineer, per-customer, per-equipment custom checklists: variance vs baseline, outcome quality,
          rework rate, and founder disposition. Higher variance is fine when CSAT stays high & rework stays low.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <KpiCard label="Personalizations" value={String(kpi.total_personalizations)} />
        <KpiCard label="Avg variance score" value={`${kpi.avg_variance}`} />
        <KpiCard label="Avg customer CSAT" value={`${kpi.avg_csat} / 5`} />
        <KpiCard label="Rework rate" value={`${kpi.rework_rate_pct}%`} />
        <KpiCard label="Supervisor overrides pending" value={String(kpi.supervisor_overrides)} />
        <KpiCard label="Excellent outcomes" value={String(kpi.excellent_outcomes)} />
        <KpiCard label="Failed outcomes" value={String(kpi.failed_outcomes)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per-engineer breakdown</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => <span>{r.engineer_name}</span> },
            { key: 'total_rows', header: 'Personalizations', render: (r: EngineerRow) => <span>{r.total_rows}</span> },
            { key: 'avg_variance', header: 'Avg variance', render: (r: EngineerRow) => <span>{r.avg_variance}</span> },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: EngineerRow) => <span>{r.avg_csat}</span> },
            { key: 'rework_count', header: 'Rework count', render: (r: EngineerRow) => <span>{r.rework_count}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Reason vs outcome matrix</h2>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
          Which personalization reasons produce excellent outcomes vs poor/failed ones.
        </p>
        <DataTable
          rows={reasons}
          columns={[
            { key: 'personalization_reason', header: 'Reason', render: (r: ReasonRow) => <span>{r.personalization_reason}</span> },
            { key: 'total', header: 'Count', render: (r: ReasonRow) => <span>{r.total}</span> },
            { key: 'avg_variance', header: 'Avg variance', render: (r: ReasonRow) => <span>{r.avg_variance}</span> },
            { key: 'excellent_pct', header: 'Excellent %', render: (r: ReasonRow) => <span>{r.excellent_pct}%</span> },
            { key: 'poor_or_failed_pct', header: 'Poor/Failed %', render: (r: ReasonRow) => <span>{r.poor_or_failed_pct}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ReasonRow, i: number) => String(r.personalization_reason ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Equipment category drill</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: CategoryRow) => <span>{r.equipment_category}</span> },
            { key: 'total', header: 'Count', render: (r: CategoryRow) => <span>{r.total}</span> },
            { key: 'avg_variance', header: 'Avg variance', render: (r: CategoryRow) => <span>{r.avg_variance}</span> },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: CategoryRow) => <span>{r.avg_csat}</span> },
            { key: 'rework_count', header: 'Rework count', render: (r: CategoryRow) => <span>{r.rework_count}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent personalizations</h2>
        <DataTable
          rows={recents}
          columns={[
            { key: 'cycle_month', header: 'Month', render: (r: RecentRow) => <span>{r.cycle_month}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: RecentRow) => <span>{r.engineer_name}</span> },
            { key: 'customer_name', header: 'Customer', render: (r: RecentRow) => <span>{r.customer_name}</span> },
            { key: 'equipment_label', header: 'Equipment', render: (r: RecentRow) => <span>{r.equipment_label}</span> },
            { key: 'equipment_category', header: 'Category', render: (r: RecentRow) => <span>{r.equipment_category}</span> },
            { key: 'baseline_checklist_items', header: 'Baseline', render: (r: RecentRow) => <span>{r.baseline_checklist_items}</span> },
            { key: 'customized_checklist_items', header: 'Custom', render: (r: RecentRow) => <span>{r.customized_checklist_items}</span> },
            { key: 'variance_score', header: 'Variance', render: (r: RecentRow) => <span>{r.variance_score}</span> },
            { key: 'outcome_quality', header: 'Outcome', render: (r: RecentRow) => <span>{r.outcome_quality}</span> },
            { key: 'customer_csat', header: 'CSAT', render: (r: RecentRow) => <span>{r.customer_csat}</span> },
            { key: 'rework_required', header: 'Rework?', render: (r: RecentRow) => <span>{r.rework_required ? 'yes' : 'no'}</span> },
            { key: 'approved_by_supervisor', header: 'Approved?', render: (r: RecentRow) => <span>{r.approved_by_supervisor ? 'yes' : 'no'}</span> },
            { key: 'personalization_reason', header: 'Reason', render: (r: RecentRow) => <span>{r.personalization_reason}</span> },
            { key: 'notes', header: 'Notes', render: (r: RecentRow) => <span>{r.notes}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecentRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder outcome audit</h2>
        <DataTable
          rows={audits}
          columns={[
            { key: 'audit_month', header: 'Month', render: (r: AuditRow) => <span>{r.audit_month}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: AuditRow) => <span>{r.engineer_name}</span> },
            { key: 'total_personalizations', header: 'Total', render: (r: AuditRow) => <span>{r.total_personalizations}</span> },
            { key: 'avg_variance', header: 'Avg variance', render: (r: AuditRow) => <span>{r.avg_variance}</span> },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: AuditRow) => <span>{r.avg_csat}</span> },
            { key: 'rework_rate_pct', header: 'Rework %', render: (r: AuditRow) => <span>{r.rework_rate_pct}%</span> },
            { key: 'supervisor_override_count', header: 'Overrides', render: (r: AuditRow) => <span>{r.supervisor_override_count}</span> },
            { key: 'founder_disposition', header: 'Disposition', render: (r: AuditRow) => <span>{r.founder_disposition}</span> },
            { key: 'recommended_action', header: 'Action', render: (r: AuditRow) => <span>{r.recommended_action}</span> },
            { key: 'reviewer', header: 'Reviewer', render: (r: AuditRow) => <span>{r.reviewer}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: AuditRow, i: number) => String(`${r.engineer_name}-${r.audit_month}` ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder disposition counts</h2>
        <DataTable
          rows={dispositions}
          columns={[
            { key: 'founder_disposition', header: 'Disposition', render: (r: DispositionRow) => <span>{r.founder_disposition}</span> },
            { key: 'engineers', header: 'Engineers', render: (r: DispositionRow) => <span>{r.engineers}</span> },
            { key: 'avg_variance', header: 'Avg variance', render: (r: DispositionRow) => <span>{r.avg_variance}</span> },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: DispositionRow) => <span>{r.avg_csat}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: DispositionRow, i: number) => String(r.founder_disposition ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Rework hotspots</h2>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
          Rows flagged for rework or that landed at poor/failed outcome. Variance &gt;= 40 with CSAT &lt;= 3.5 is the danger zone.
        </p>
        <DataTable
          rows={hotspots}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: HotspotRow) => <span>{r.engineer_name}</span> },
            { key: 'customer_name', header: 'Customer', render: (r: HotspotRow) => <span>{r.customer_name}</span> },
            { key: 'equipment_label', header: 'Equipment', render: (r: HotspotRow) => <span>{r.equipment_label}</span> },
            { key: 'variance_score', header: 'Variance', render: (r: HotspotRow) => <span>{r.variance_score}</span> },
            { key: 'outcome_quality', header: 'Outcome', render: (r: HotspotRow) => <span>{r.outcome_quality}</span> },
            { key: 'customer_csat', header: 'CSAT', render: (r: HotspotRow) => <span>{r.customer_csat}</span> },
            { key: 'notes', header: 'Notes', render: (r: HotspotRow) => <span>{r.notes}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: HotspotRow, i: number) => String(`${r.engineer_name}-${r.equipment_label}` ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
