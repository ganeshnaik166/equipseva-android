import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; units_audited: number; avg_readiness: number; red_or_critical_chapters: number; blockers: number };
type HeatRow = { chapter_code: string; chapter_name: string; units_count: number; avg_readiness: number; critical_units: number };
type CriticalRow = { chain_name: string; hospital_unit: string; chapter_code: string; readiness_score: number; readiness_band: string; next_review_due_at: string; lead_auditor: string };
type BlockerRow = { chain_name: string; hospital_unit: string; chapter_code: string; finding_severity: string; finding_title: string; capa_status: string; capa_due_at: string; cost_to_close_rupees: number };
type CapaRow = { capa_status: string; finding_count: number; total_cost_rupees: number; blockers: number };
type OverdueRow = { chain_name: string; hospital_unit: string; finding_title: string; capa_owner: string; capa_due_at: string; days_overdue: number; severity: string };
type CostRow = { chain_name: string; total_findings: number; open_findings: number; blocker_findings: number; total_remediation_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [chainRes, heatRes, critRes, blockRes, capaRes, overRes, costRes] = await Promise.all([
    supabase.rpc('r2943_chain_readiness_rollup'),
    supabase.rpc('r2943_chapter_heatmap'),
    supabase.rpc('r2943_critical_units'),
    supabase.rpc('r2943_open_blocker_findings'),
    supabase.rpc('r2943_capa_status_breakdown'),
    supabase.rpc('r2943_overdue_capas'),
    supabase.rpc('r2943_cost_to_remediation'),
  ]);

  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const heat: HeatRow[] = (heatRes.data as HeatRow[]) ?? [];
  const critical: CriticalRow[] = (critRes.data as CriticalRow[]) ?? [];
  const blockers: BlockerRow[] = (blockRes.data as BlockerRow[]) ?? [];
  const capa: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const overdue: OverdueRow[] = (overRes.data as OverdueRow[]) ?? [];
  const costs: CostRow[] = (costRes.data as CostRow[]) ?? [];

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'units_audited', header: 'Units audited', render: (r) => r.units_audited },
    { key: 'avg_readiness', header: 'Avg readiness %', render: (r) => r.avg_readiness },
    { key: 'red_or_critical_chapters', header: 'Red/critical chapters', render: (r) => r.red_or_critical_chapters },
    { key: 'blockers', header: 'Blockers', render: (r) => r.blockers },
  ];

  const heatCols: Column<HeatRow>[] = [
    { key: 'chapter_code', header: 'Chapter', render: (r) => r.chapter_code },
    { key: 'chapter_name', header: 'Name', render: (r) => r.chapter_name },
    { key: 'units_count', header: 'Units', render: (r) => r.units_count },
    { key: 'avg_readiness', header: 'Avg readiness %', render: (r) => r.avg_readiness },
    { key: 'critical_units', header: 'Critical units', render: (r) => r.critical_units },
  ];

  const critCols: Column<CriticalRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_unit', header: 'Unit', render: (r) => r.hospital_unit },
    { key: 'chapter_code', header: 'Chapter', render: (r) => r.chapter_code },
    { key: 'readiness_score', header: 'Readiness %', render: (r) => r.readiness_score },
    { key: 'readiness_band', header: 'Band', render: (r) => r.readiness_band },
    { key: 'next_review_due_at', header: 'Next review', render: (r) => new Date(r.next_review_due_at).toLocaleDateString() },
    { key: 'lead_auditor', header: 'Lead auditor', render: (r) => r.lead_auditor },
  ];

  const blockCols: Column<BlockerRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_unit', header: 'Unit', render: (r) => r.hospital_unit },
    { key: 'chapter_code', header: 'Chapter', render: (r) => r.chapter_code },
    { key: 'finding_severity', header: 'Severity', render: (r) => r.finding_severity },
    { key: 'finding_title', header: 'Finding', render: (r) => r.finding_title },
    { key: 'capa_status', header: 'CAPA', render: (r) => r.capa_status },
    { key: 'capa_due_at', header: 'Due', render: (r) => new Date(r.capa_due_at).toLocaleDateString() },
    { key: 'cost_to_close_rupees', header: 'Cost (Rs)', render: (r) => r.cost_to_close_rupees.toLocaleString('en-IN') },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA status', render: (r) => r.capa_status },
    { key: 'finding_count', header: 'Findings', render: (r) => r.finding_count },
    { key: 'total_cost_rupees', header: 'Total cost (Rs)', render: (r) => r.total_cost_rupees.toLocaleString('en-IN') },
    { key: 'blockers', header: 'Blockers', render: (r) => r.blockers },
  ];

  const overCols: Column<OverdueRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_unit', header: 'Unit', render: (r) => r.hospital_unit },
    { key: 'finding_title', header: 'Finding', render: (r) => r.finding_title },
    { key: 'capa_owner', header: 'Owner', render: (r) => r.capa_owner },
    { key: 'capa_due_at', header: 'Due', render: (r) => new Date(r.capa_due_at).toLocaleDateString() },
    { key: 'days_overdue', header: 'Days overdue', render: (r) => r.days_overdue },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'total_findings', header: 'Total findings', render: (r) => r.total_findings },
    { key: 'open_findings', header: 'Open', render: (r) => r.open_findings },
    { key: 'blocker_findings', header: 'Blockers', render: (r) => r.blocker_findings },
    { key: 'total_remediation_rupees', header: 'Remediation cost (Rs)', render: (r) => r.total_remediation_rupees.toLocaleString('en-IN') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly NABH Re-Accreditation Readiness Pre-Audit</h1>
        <p className="text-sm text-gray-600 mt-1">Chain-level rollup of pre-audit readiness across NABH chapters. Surfaces re-accreditation blockers & overdue CAPAs before the surveyor visit.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain readiness rollup</h2>
        <DataTable rows={chains} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String((r as ChainRow).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chapter heatmap (avg across all units)</h2>
        <DataTable rows={heat} columns={heatCols} emptyMessage="No chapters" rowKey={(r, i) => String((r as HeatRow).chapter_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical units (band &gt;= red)</h2>
        <DataTable rows={critical} columns={critCols} emptyMessage="No critical units" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open re-accreditation blocker findings</h2>
        <DataTable rows={blockers} columns={blockCols} emptyMessage="No open blockers" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CAPA status breakdown</h2>
        <DataTable rows={capa} columns={capaCols} emptyMessage="No CAPAs" rowKey={(r, i) => String((r as CapaRow).capa_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue CAPAs</h2>
        <DataTable rows={overdue} columns={overCols} emptyMessage="No overdue CAPAs" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cost-to-remediation by chain</h2>
        <DataTable rows={costs} columns={costCols} emptyMessage="No cost data" rowKey={(r, i) => String((r as CostRow).chain_name ?? i)} />
      </section>
    </div>
  );
}
