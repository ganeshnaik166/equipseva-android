import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { renewal_status: string; licences: number; pct: number };
type EntityRow = {
  entity_name: string;
  total_licences: number;
  renewed: number;
  expiring_soon: number;
  expired_lapsed: number;
  critical: number;
  avg_days_to_expiry: number;
  compliance_pct: number;
};
type MatrixRow = {
  authority: string;
  licence_type: string;
  licences: number;
  renewed: number;
  avg_days_to_expiry: number;
};
type TrendRow = {
  expiry_month: string;
  licences: number;
  expired: number;
  renewed: number;
  critical: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  entity_name: string;
  authority: string;
  licence_type: string;
  licence_no: string;
  expiry_date: string;
  days_to_expiry: number;
  renewal_owner: string;
  renewal_status: string;
  criticality: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3153_renewal_status_rollup'),
    supabase.rpc('founder_r3153_entity_scorecard'),
    supabase.rpc('founder_r3153_authority_type_matrix'),
    supabase.rpc('founder_r3153_expiry_month_trend'),
    supabase.rpc('founder_r3153_capa_status_board'),
    supabase.rpc('founder_r3153_root_cause_pareto'),
    supabase.rpc('founder_r3153_regulatory_impact_digest'),
    supabase.rpc('founder_r3153_priority_renewal_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'licences', header: 'Licences' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'total_licences', header: 'Licences' },
    { key: 'renewed', header: 'Renewed' },
    { key: 'expiring_soon', header: 'Expiring in 30d' },
    { key: 'expired_lapsed', header: 'Expired / Lapsed' },
    { key: 'critical', header: 'Critical' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'compliance_pct', header: 'Renewed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'authority', header: 'Authority' },
    { key: 'licence_type', header: 'Licence Type' },
    { key: 'licences', header: 'Licences' },
    { key: 'renewed', header: 'Renewed' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'expiry_month', header: 'Expiry Month' },
    { key: 'licences', header: 'Licences' },
    { key: 'expired', header: 'Expired / Lapsed' },
    { key: 'renewed', header: 'Renewed' },
    { key: 'critical', header: 'Critical' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'authority', header: 'Authority' },
    { key: 'licence_type', header: 'Licence Type' },
    { key: 'licence_no', header: 'Licence No' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'renewal_owner', header: 'Owner' },
    { key: 'renewal_status', header: 'Status' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Regulatory Licence &amp; Statutory-Renewal Calendar
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory licence register — authority (CDSCO / NABH / GST / PF-ESI / labour / fire / pollution) &times;
        licence type &times; issued/expiry &times; days-to-expiry &times; renewal owner &times; renewal status &times;
        criticality &amp; CAPA closure. Founder-gated view: renewal-status rollup, entity scorecards, root-cause
        pareto, and a priority renewal queue for licences expiring soon or already lapsed.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Renewal status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No licences registered yet."
          rowKey={(r, i) => String(r.renewal_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity compliance scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Authority &times; licence-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No licences by authority."
          rowKey={(r, i) => `${r.authority}-${r.licence_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Expiry-by-month trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.expiry_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority renewal queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No priority renewals."
          rowKey={(r, i) => `${r.licence_no}-${i}`}
        />
      </section>
    </main>
  );
}
