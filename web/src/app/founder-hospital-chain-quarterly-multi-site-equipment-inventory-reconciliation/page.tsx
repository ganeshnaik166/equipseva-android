import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; sites: number; expected_units: number; scanned_units: number; missing_units: number; avg_reconciliation: number };
type StatusRow = { sweep_status: string; cnt: number; total_missing: number };
type SevRow = { severity: string; total: number; open_cnt: number; value_at_risk: number };
type LossRow = { chain_name: string; site_code: string; city: string; missing_units: number; value_at_risk: number };
type CatRow = { equipment_category: string; exceptions: number; value_at_risk: number; p0_cnt: number };
type P0Row = { asset_tag: string; chain_name: string; site_code: string; equipment_category: string; exception_type: string; value_rupees: number };
type KpiRow = { total_sweeps: number; sites_closed: number; sites_open: number; total_exceptions: number; open_value_rupees: number; avg_recon_pct: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [chain, status, sev, loss, cat, p0, kpi] = await Promise.all([
    sb.rpc('r2939_chain_rollup'),
    sb.rpc('r2939_status_mix'),
    sb.rpc('r2939_exceptions_by_severity'),
    sb.rpc('r2939_top_loss_sites'),
    sb.rpc('r2939_category_breakdown'),
    sb.rpc('r2939_open_p0_exceptions'),
    sb.rpc('r2939_kpi_summary'),
  ]);

  const chainRows = (chain.data ?? []) as ChainRow[];
  const statusRows = (status.data ?? []) as StatusRow[];
  const sevRows = (sev.data ?? []) as SevRow[];
  const lossRows = (loss.data ?? []) as LossRow[];
  const catRows = (cat.data ?? []) as CatRow[];
  const p0Rows = (p0.data ?? []) as P0Row[];
  const kpiRow = ((kpi.data ?? [])[0] ?? null) as KpiRow | null;

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: r => r.chain_name },
    { key: 'sites', header: 'Sites', render: r => r.sites },
    { key: 'expected_units', header: 'Expected', render: r => r.expected_units },
    { key: 'scanned_units', header: 'Scanned', render: r => r.scanned_units },
    { key: 'missing_units', header: 'Missing', render: r => r.missing_units },
    { key: 'avg_reconciliation', header: 'Avg Recon %', render: r => r.avg_reconciliation },
  ];

  const statusCols: Column<StatusRow>[] = [
    { key: 'sweep_status', header: 'Status', render: r => r.sweep_status },
    { key: 'cnt', header: 'Count', render: r => r.cnt },
    { key: 'total_missing', header: 'Total Missing', render: r => r.total_missing },
  ];

  const sevCols: Column<SevRow>[] = [
    { key: 'severity', header: 'Severity', render: r => r.severity },
    { key: 'total', header: 'Total', render: r => r.total },
    { key: 'open_cnt', header: 'Open', render: r => r.open_cnt },
    { key: 'value_at_risk', header: 'Value At Risk', render: r => '₹' + (r.value_at_risk ?? 0).toLocaleString('en-IN') },
  ];

  const lossCols: Column<LossRow>[] = [
    { key: 'chain_name', header: 'Chain', render: r => r.chain_name },
    { key: 'site_code', header: 'Site', render: r => r.site_code },
    { key: 'city', header: 'City', render: r => r.city },
    { key: 'missing_units', header: 'Missing', render: r => r.missing_units },
    { key: 'value_at_risk', header: 'Value At Risk', render: r => '₹' + (r.value_at_risk ?? 0).toLocaleString('en-IN') },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'equipment_category', header: 'Category', render: r => r.equipment_category },
    { key: 'exceptions', header: 'Exceptions', render: r => r.exceptions },
    { key: 'p0_cnt', header: 'P0', render: r => r.p0_cnt },
    { key: 'value_at_risk', header: 'Value At Risk', render: r => '₹' + (r.value_at_risk ?? 0).toLocaleString('en-IN') },
  ];

  const p0Cols: Column<P0Row>[] = [
    { key: 'asset_tag', header: 'Asset', render: r => r.asset_tag },
    { key: 'chain_name', header: 'Chain', render: r => r.chain_name },
    { key: 'site_code', header: 'Site', render: r => r.site_code },
    { key: 'equipment_category', header: 'Category', render: r => r.equipment_category },
    { key: 'exception_type', header: 'Type', render: r => r.exception_type },
    { key: 'value_rupees', header: 'Value', render: r => '₹' + (r.value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital Chain Quarterly Multi-Site Equipment Inventory Reconciliation</h1>
        <p style={{ color: '#666', fontSize: 13 }}>r2939 — chain-wide sweep rollup & exception triage</p>
      </header>

      {kpiRow && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))', gap: 12 }}>
          <Kpi label="Total Sweeps" value={String(kpiRow.total_sweeps)} />
          <Kpi label="Closed" value={String(kpiRow.sites_closed)} />
          <Kpi label="Open" value={String(kpiRow.sites_open)} />
          <Kpi label="Exceptions" value={String(kpiRow.total_exceptions)} />
          <Kpi label="Open Value At Risk" value={'₹' + (kpiRow.open_value_rupees ?? 0).toLocaleString('en-IN')} />
          <Kpi label="Avg Recon %" value={String(kpiRow.avg_recon_pct ?? 0)} />
        </section>
      )}

      <Section title="Chain Rollup">
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String(r.chain_name ?? i)} />
      </Section>

      <Section title="Sweep Status Mix">
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No status data" rowKey={(r, i) => String(r.sweep_status ?? i)} />
      </Section>

      <Section title="Exceptions By Severity">
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No exceptions" rowKey={(r, i) => String(r.severity ?? i)} />
      </Section>

      <Section title="Top Loss Sites">
        <DataTable rows={lossRows} columns={lossCols} emptyMessage="No loss sites" rowKey={(r, i) => String(r.site_code ?? i)} />
      </Section>

      <Section title="Category Breakdown">
        <DataTable rows={catRows} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String(r.equipment_category ?? i)} />
      </Section>

      <Section title="Open P0 Exceptions">
        <DataTable rows={p0Rows} columns={p0Cols} emptyMessage="No open P0 exceptions" rowKey={(r, i) => String(r.asset_tag ?? i)} />
      </Section>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <h2 style={{ fontSize: 15, fontWeight: 600 }}>{title}</h2>
      {children}
    </section>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
