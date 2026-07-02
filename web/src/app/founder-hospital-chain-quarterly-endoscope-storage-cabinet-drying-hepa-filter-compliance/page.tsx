import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; cabinets: number; compliant: number; breach: number; overdue: number; quarantined: number; avg_airflow: number | null };
type HepaRow = { chain_name: string; hospital_site: string; cabinet_asset_tag: string; hepa_filter_serial: string | null; hepa_replacement_due: string; days_to_due: number };
type OpenRow = { severity: string; open_count: number; total_fine_risk: number };
type CatRow = { finding_category: string; total: number; open_int: number; closed_int: number };
type AirRow = { cabinet_asset_tag: string; chain_name: string; drying_airflow_lpm: number | null; particle_count_0_5um: number | null; compliance_status: string };
type QuarterRow = { quarter_label: string; total: number; compliant: number; compliance_pct: number | null };
type FineRow = { finding_code: string; severity: string; finding_category: string; observation: string; fine_risk_rupees: number | null; closure_status: string };
type EscRow = { chain_name: string; escalated_findings: number; total_fine_risk: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chain, hepa, open, cat, air, quarter, fine, esc] = await Promise.all([
    supabase.rpc('rpc_r3031_chain_rollup'),
    supabase.rpc('rpc_r3031_hepa_schedule'),
    supabase.rpc('rpc_r3031_open_findings'),
    supabase.rpc('rpc_r3031_category_breakdown'),
    supabase.rpc('rpc_r3031_airflow_watchlist'),
    supabase.rpc('rpc_r3031_quarter_compliance'),
    supabase.rpc('rpc_r3031_top_fine_risk'),
    supabase.rpc('rpc_r3031_escalated_summary'),
  ]);

  const chainRows = (chain.data ?? []) as ChainRow[];
  const hepaRows = (hepa.data ?? []) as HepaRow[];
  const openRows = (open.data ?? []) as OpenRow[];
  const catRows = (cat.data ?? []) as CatRow[];
  const airRows = (air.data ?? []) as AirRow[];
  const quarterRows = (quarter.data ?? []) as QuarterRow[];
  const fineRows = (fine.data ?? []) as FineRow[];
  const escRows = (esc.data ?? []) as EscRow[];

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Cabinets', cell: (r) => r.cabinets },
    { header: 'Compliant', cell: (r) => r.compliant },
    { header: 'Breach', cell: (r) => r.breach },
    { header: 'Overdue', cell: (r) => r.overdue },
    { header: 'Quarantined', cell: (r) => r.quarantined },
    { header: 'Avg airflow (LPM)', cell: (r) => r.avg_airflow ?? '-' },
  ];

  const hepaCols: Column<HepaRow>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Site', cell: (r) => r.hospital_site },
    { header: 'Cabinet', cell: (r) => r.cabinet_asset_tag },
    { header: 'HEPA serial', cell: (r) => r.hepa_filter_serial ?? 'MISSING' },
    { header: 'Replace by', cell: (r) => r.hepa_replacement_due },
    { header: 'Days to due', cell: (r) => r.days_to_due },
  ];

  const openCols: Column<OpenRow>[] = [
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Open count', cell: (r) => r.open_count },
    { header: 'Fine risk (₹)', cell: (r) => r.total_fine_risk.toLocaleString('en-IN') },
  ];

  const catCols: Column<CatRow>[] = [
    { header: 'Category', cell: (r) => r.finding_category },
    { header: 'Total', cell: (r) => r.total },
    { header: 'Open', cell: (r) => r.open_int },
    { header: 'Closed', cell: (r) => r.closed_int },
  ];

  const airCols: Column<AirRow>[] = [
    { header: 'Cabinet', cell: (r) => r.cabinet_asset_tag },
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Airflow (LPM)', cell: (r) => r.drying_airflow_lpm ?? 'NO DATA' },
    { header: 'Particles', cell: (r) => r.particle_count_0_5um ?? '-' },
    { header: 'Status', cell: (r) => r.compliance_status },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', cell: (r) => r.quarter_label },
    { header: 'Total', cell: (r) => r.total },
    { header: 'Compliant', cell: (r) => r.compliant },
    { header: 'Compliance %', cell: (r) => r.compliance_pct ?? '-' },
  ];

  const fineCols: Column<FineRow>[] = [
    { header: 'Code', cell: (r) => r.finding_code },
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Category', cell: (r) => r.finding_category },
    { header: 'Observation', cell: (r) => r.observation },
    { header: 'Fine risk (₹)', cell: (r) => (r.fine_risk_rupees ?? 0).toLocaleString('en-IN') },
    { header: 'Status', cell: (r) => r.closure_status },
  ];

  const escCols: Column<EscRow>[] = [
    { header: 'Chain', cell: (r) => r.chain_name },
    { header: 'Escalated', cell: (r) => r.escalated_findings },
    { header: 'Fine risk (₹)', cell: (r) => r.total_fine_risk.toLocaleString('en-IN') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Endoscope Storage-Cabinet Drying &amp; HEPA Filter Compliance</h1>
        <p className="text-sm text-gray-600">Round r3031 — drying airflow &gt;= 80 LPM, humidity &lt;= 50%, HEPA replaced annually.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Chain rollup</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains." rowKey={(r, i) => String((r as ChainRow).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">HEPA replacement schedule</h2>
        <DataTable rows={hepaRows} columns={hepaCols} emptyMessage="No cabinets." rowKey={(r, i) => String((r as HepaRow).cabinet_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open findings by severity</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="No findings." rowKey={(r, i) => String((r as OpenRow).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Category breakdown</h2>
        <DataTable rows={catRows} columns={catCols} emptyMessage="No categories." rowKey={(r, i) => String((r as CatRow).finding_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Airflow watchlist (&lt; 80 LPM)</h2>
        <DataTable rows={airRows} columns={airCols} emptyMessage="All cabinets &gt;= 80 LPM." rowKey={(r, i) => String((r as AirRow).cabinet_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Quarter compliance</h2>
        <DataTable rows={quarterRows} columns={quarterCols} emptyMessage="No quarters." rowKey={(r, i) => String((r as QuarterRow).quarter_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top fine-risk findings</h2>
        <DataTable rows={fineRows} columns={fineCols} emptyMessage="No findings." rowKey={(r, i) => String((r as FineRow).finding_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Escalated summary by chain</h2>
        <DataTable rows={escRows} columns={escCols} emptyMessage="No escalations." rowKey={(r, i) => String((r as EscRow).chain_name ?? i)} />
      </section>
    </div>
  );
}
