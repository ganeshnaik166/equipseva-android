import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_code: string; audits: number; failed: number; quarantined: number; avg_brake_lock: number; total_remediation_rupees: number };
type FailedBoom = { chain_code: string; hospital_site: string; operating_room: string; boom_asset_tag: string; articulation_score: number; brake_lock_score: number; drift_mm_per_hour: number };
type TypeBreak = { boom_type: string; audits: number; avg_articulation: number; avg_brake_lock: number; avg_drift: number };
type StatusMix = { audit_status: string; n: number; pct: number };
type SevFind = { severity: string; findings: number; resolved: number; open_count: number };
type TopDrift = { boom_asset_tag: string; hospital_site: string; operating_room: string; drift_mm_per_hour: number; audit_status: string };
type CatFind = { category: string; n: number; avg_measured: number };
type CostChain = { chain_code: string; failed_or_quarantined: number; total_cost_rupees: number; avg_cost_rupees: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [rollup, failed, types, mix, sev, drift, cats, costs] = await Promise.all([
    sb.rpc('r3051_chain_rollup'),
    sb.rpc('r3051_failed_booms'),
    sb.rpc('r3051_boom_type_breakdown'),
    sb.rpc('r3051_status_mix'),
    sb.rpc('r3051_severity_findings'),
    sb.rpc('r3051_top_drift'),
    sb.rpc('r3051_category_findings'),
    sb.rpc('r3051_remediation_cost_by_chain'),
  ]);

  const rollupRows = (rollup.data ?? []) as ChainRollup[];
  const failedRows = (failed.data ?? []) as FailedBoom[];
  const typeRows = (types.data ?? []) as TypeBreak[];
  const mixRows = (mix.data ?? []) as StatusMix[];
  const sevRows = (sev.data ?? []) as SevFind[];
  const driftRows = (drift.data ?? []) as TopDrift[];
  const catRows = (cats.data ?? []) as CatFind[];
  const costRows = (costs.data ?? []) as CostChain[];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Quarantined', accessor: (r) => r.quarantined },
    { header: 'Avg Brake Lock', accessor: (r) => r.avg_brake_lock },
    { header: 'Remediation (Rs)', accessor: (r) => r.total_remediation_rupees },
  ];
  const failedCols: Column<FailedBoom>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'OR', accessor: (r) => r.operating_room },
    { header: 'Boom', accessor: (r) => r.boom_asset_tag },
    { header: 'Articulation', accessor: (r) => r.articulation_score },
    { header: 'Brake Lock', accessor: (r) => r.brake_lock_score },
    { header: 'Drift mm/hr', accessor: (r) => r.drift_mm_per_hour },
  ];
  const typeCols: Column<TypeBreak>[] = [
    { header: 'Boom Type', accessor: (r) => r.boom_type },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Articulation', accessor: (r) => r.avg_articulation },
    { header: 'Avg Brake Lock', accessor: (r) => r.avg_brake_lock },
    { header: 'Avg Drift', accessor: (r) => r.avg_drift },
  ];
  const mixCols: Column<StatusMix>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Pct %', accessor: (r) => r.pct },
  ];
  const sevCols: Column<SevFind>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Resolved', accessor: (r) => r.resolved },
    { header: 'Open', accessor: (r) => r.open_count },
  ];
  const driftCols: Column<TopDrift>[] = [
    { header: 'Boom', accessor: (r) => r.boom_asset_tag },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'OR', accessor: (r) => r.operating_room },
    { header: 'Drift mm/hr', accessor: (r) => r.drift_mm_per_hour },
    { header: 'Status', accessor: (r) => r.audit_status },
  ];
  const catCols: Column<CatFind>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Avg Measured', accessor: (r) => r.avg_measured },
  ];
  const costCols: Column<CostChain>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Fail/Quar', accessor: (r) => r.failed_or_quarantined },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost_rupees },
    { header: 'Avg Cost (Rs)', accessor: (r) => r.avg_cost_rupees },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Surgical Tower Boom Audit</h1>
        <p className="text-sm text-gray-600">Articulation &amp; brake lock — drift &gt;= 1.5 mm/hr flagged; spec &lt;= 1.5 mm/hr</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Rollup</h2>
        <DataTable rows={rollupRows} columns={rollupCols} emptyMessage="No chains" rowKey={(r, i) => String((r as { chain_code?: string }).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failed & Quarantined Booms</h2>
        <DataTable rows={failedRows} columns={failedCols} emptyMessage="No failures" rowKey={(r, i) => String((r as { boom_asset_tag?: string }).boom_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Boom Type Breakdown</h2>
        <DataTable rows={typeRows} columns={typeCols} emptyMessage="No data" rowKey={(r, i) => String((r as { boom_type?: string }).boom_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Mix</h2>
        <DataTable rows={mixRows} columns={mixCols} emptyMessage="No status" rowKey={(r, i) => String((r as { audit_status?: string }).audit_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity Findings</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No findings" rowKey={(r, i) => String((r as { severity?: string }).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top 10 Drift</h2>
        <DataTable rows={driftRows} columns={driftCols} emptyMessage="No drift" rowKey={(r, i) => String((r as { boom_asset_tag?: string }).boom_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Findings</h2>
        <DataTable rows={catRows} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String((r as { category?: string }).category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation Cost by Chain</h2>
        <DataTable rows={costRows} columns={costCols} emptyMessage="No costs" rowKey={(r, i) => String((r as { chain_code?: string }).chain_code ?? i)} />
      </section>
    </div>
  );
}
