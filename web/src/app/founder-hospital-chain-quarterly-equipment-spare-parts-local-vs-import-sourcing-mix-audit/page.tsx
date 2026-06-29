import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_code: string; chain_name: string; total_orders: number; local_share_pct: number; target_local_share_pct: number; gap_pct: number; forex_impact_rupees: number; audit_status: string };
type QoQ = { chain_code: string; prev_share: number; curr_share: number; delta_pp: number; trend: string };
type ImportRisk = { chain_code: string; part_category: string; origin_country: string; unit_count: number; unit_price_rupees: number; lead_time_days: number; risk_flag: string; substitutable: boolean };
type SubOpp = { chain_code: string; part_category: string; origin_country: string; annualised_spend_rupees: number; lead_time_days: number; defect_rate_pct: number };
type LeadPressure = { chain_code: string; avg_local_lead_days: number; avg_import_lead_days: number; lead_gap_days: number; audit_status: string };
type ModalityMix = { modality: string; local_lines: number; import_lines: number; local_spend_rupees: number; import_spend_rupees: number; local_share_pct: number };
type AuditBoard = { audit_status: string; chain_count: number; total_orders: number; total_forex_impact_rupees: number };
type DefectByOrigin = { origin: string; line_count: number; avg_defect_rate_pct: number; max_defect_rate_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollup, qoq, risk, sub, lead, modality, board, defect] = await Promise.all([
    supabase.rpc('r2979_chain_rollup_current'),
    supabase.rpc('r2979_qoq_delta'),
    supabase.rpc('r2979_import_risk_lines'),
    supabase.rpc('r2979_substitution_opportunities'),
    supabase.rpc('r2979_lead_time_pressure'),
    supabase.rpc('r2979_modality_mix'),
    supabase.rpc('r2979_audit_board'),
    supabase.rpc('r2979_defect_by_origin'),
  ]);

  const rollupRows: ChainRollup[] = rollup.data ?? [];
  const qoqRows: QoQ[] = qoq.data ?? [];
  const riskRows: ImportRisk[] = risk.data ?? [];
  const subRows: SubOpp[] = sub.data ?? [];
  const leadRows: LeadPressure[] = lead.data ?? [];
  const modRows: ModalityMix[] = modality.data ?? [];
  const boardRows: AuditBoard[] = board.data ?? [];
  const defectRows: DefectByOrigin[] = defect.data ?? [];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Orders', accessor: (r) => r.total_orders },
    { header: 'Local %', accessor: (r) => `${r.local_share_pct}%` },
    { header: 'Target %', accessor: (r) => `${r.target_local_share_pct}%` },
    { header: 'Gap (pp)', accessor: (r) => r.gap_pct.toFixed(2) },
    { header: 'Forex impact', accessor: (r) => `Rs ${r.forex_impact_rupees.toLocaleString('en-IN')}` },
    { header: 'Status', accessor: (r) => r.audit_status.toUpperCase() },
  ];

  const qoqCols: Column<QoQ>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Q4 FY25', accessor: (r) => `${r.prev_share}%` },
    { header: 'Q1 FY26', accessor: (r) => `${r.curr_share}%` },
    { header: 'Delta (pp)', accessor: (r) => r.delta_pp.toFixed(2) },
    { header: 'Trend', accessor: (r) => r.trend },
  ];

  const riskCols: Column<ImportRisk>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Part', accessor: (r) => r.part_category },
    { header: 'Country', accessor: (r) => r.origin_country },
    { header: 'Units', accessor: (r) => r.unit_count },
    { header: 'Unit Rs', accessor: (r) => `Rs ${r.unit_price_rupees.toLocaleString('en-IN')}` },
    { header: 'Lead days', accessor: (r) => r.lead_time_days },
    { header: 'Risk', accessor: (r) => r.risk_flag },
    { header: 'Sub?', accessor: (r) => (r.substitutable ? 'yes' : 'no') },
  ];

  const subCols: Column<SubOpp>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Part', accessor: (r) => r.part_category },
    { header: 'From', accessor: (r) => r.origin_country },
    { header: 'Annual spend', accessor: (r) => `Rs ${r.annualised_spend_rupees.toLocaleString('en-IN')}` },
    { header: 'Lead', accessor: (r) => `${r.lead_time_days}d` },
    { header: 'Defect %', accessor: (r) => `${r.defect_rate_pct}%` },
  ];

  const leadCols: Column<LeadPressure>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Local lead', accessor: (r) => `${r.avg_local_lead_days}d` },
    { header: 'Import lead', accessor: (r) => `${r.avg_import_lead_days}d` },
    { header: 'Gap', accessor: (r) => `${r.lead_gap_days}d` },
    { header: 'Status', accessor: (r) => r.audit_status },
  ];

  const modCols: Column<ModalityMix>[] = [
    { header: 'Modality', accessor: (r) => r.modality },
    { header: 'Local lines', accessor: (r) => r.local_lines },
    { header: 'Import lines', accessor: (r) => r.import_lines },
    { header: 'Local Rs', accessor: (r) => `Rs ${r.local_spend_rupees.toLocaleString('en-IN')}` },
    { header: 'Import Rs', accessor: (r) => `Rs ${r.import_spend_rupees.toLocaleString('en-IN')}` },
    { header: 'Local %', accessor: (r) => `${r.local_share_pct}%` },
  ];

  const boardCols: Column<AuditBoard>[] = [
    { header: 'Status', accessor: (r) => r.audit_status.toUpperCase() },
    { header: 'Chains', accessor: (r) => r.chain_count },
    { header: 'Orders', accessor: (r) => r.total_orders },
    { header: 'Forex impact', accessor: (r) => `Rs ${r.total_forex_impact_rupees.toLocaleString('en-IN')}` },
  ];

  const defectCols: Column<DefectByOrigin>[] = [
    { header: 'Origin', accessor: (r) => r.origin },
    { header: 'Lines', accessor: (r) => r.line_count },
    { header: 'Avg defect %', accessor: (r) => `${r.avg_defect_rate_pct}%` },
    { header: 'Max defect %', accessor: (r) => `${r.max_defect_rate_pct}%` },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-10">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Spare-Parts Local-vs-Import Sourcing Mix Audit</h1>
        <p className="text-sm text-gray-600 mt-2">Round r2979 — founder audit of chain-level localisation progress, import concentration risk, and substitution opportunities across Q4 FY25 vs Q1 FY26.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Chain rollup — current quarter (Q1 FY26)</h2>
        <DataTable rows={rollupRows} columns={rollupCols} emptyMessage="No chain rollup." rowKey={(r, i) => String(r.chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">QoQ delta — local share Q4 FY25 vs Q1 FY26</h2>
        <DataTable rows={qoqRows} columns={qoqCols} emptyMessage="No QoQ data." rowKey={(r, i) => String(r.chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Import concentration risk lines</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No import risk lines." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Substitution opportunities (import & substitutable)</h2>
        <DataTable rows={subRows} columns={subCols} emptyMessage="No substitution opportunities." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Lead time pressure</h2>
        <DataTable rows={leadRows} columns={leadCols} emptyMessage="No lead data." rowKey={(r, i) => String(r.chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Modality mix — local vs import</h2>
        <DataTable rows={modRows} columns={modCols} emptyMessage="No modality data." rowKey={(r, i) => String(r.modality ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Audit status board</h2>
        <DataTable rows={boardRows} columns={boardCols} emptyMessage="No audit board." rowKey={(r, i) => String(r.audit_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Defect rate by origin</h2>
        <DataTable rows={defectRows} columns={defectCols} emptyMessage="No defect data." rowKey={(r, i) => String(r.origin ?? i)} />
      </section>
    </main>
  );
}
