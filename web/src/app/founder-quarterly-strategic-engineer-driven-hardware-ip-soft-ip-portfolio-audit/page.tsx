import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { asset_class: string; total_assets: number; total_value_rupees: number; grade_a_count: number; protected_count: number };
type TopEng = { engineer_name: string; hardware_assets: number; soft_assets: number; total_value_rupees: number; grade_a_total: number };
type PatStat = { patent_status: string; asset_count: number; total_value_rupees: number; avg_strength: number };
type Pillar = { strategic_pillar: string; hardware_count: number; soft_count: number; combined_value_rupees: number };
type Underprot = { asset_code: string; engineer_name: string; asset_title: string; estimated_value_rupees: number; patent_status: string; protection_strength_score: number; defensibility_grade: string };
type Adoption = { asset_code: string; engineer_name: string; asset_title: string; soft_ip_kind: string; adoption_score: number; active_user_engineers: number; invocation_count_quarter: number; estimated_value_rupees: number };
type Modality = { modality: string; hardware_assets: number; soft_assets: number; combined_value_rupees: number; best_grade: string };

function fmtINR(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overview, topEng, patStat, pillar, underprot, adoption, modality] = await Promise.all([
    sb.rpc('rpc_r3001_portfolio_overview'),
    sb.rpc('rpc_r3001_top_engineers'),
    sb.rpc('rpc_r3001_patent_status_breakdown'),
    sb.rpc('rpc_r3001_pillar_distribution'),
    sb.rpc('rpc_r3001_underprotected_flags'),
    sb.rpc('rpc_r3001_soft_ip_adoption_leaders'),
    sb.rpc('rpc_r3001_modality_coverage'),
  ]);

  const overviewRows: Overview[] = (overview.data ?? []) as Overview[];
  const topEngRows: TopEng[] = (topEng.data ?? []) as TopEng[];
  const patStatRows: PatStat[] = (patStat.data ?? []) as PatStat[];
  const pillarRows: Pillar[] = (pillar.data ?? []) as Pillar[];
  const underprotRows: Underprot[] = (underprot.data ?? []) as Underprot[];
  const adoptionRows: Adoption[] = (adoption.data ?? []) as Adoption[];
  const modalityRows: Modality[] = (modality.data ?? []) as Modality[];

  const overviewCols: Column<Overview>[] = [
    { key: 'asset_class', header: 'Asset class', render: (r) => r.asset_class },
    { key: 'total_assets', header: 'Total', render: (r) => r.total_assets },
    { key: 'total_value_rupees', header: 'Value', render: (r) => fmtINR(r.total_value_rupees) },
    { key: 'grade_a_count', header: 'Grade A', render: (r) => r.grade_a_count },
    { key: 'protected_count', header: 'Protected', render: (r) => r.protected_count },
  ];

  const topEngCols: Column<TopEng>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hardware_assets', header: 'HW', render: (r) => r.hardware_assets },
    { key: 'soft_assets', header: 'SW', render: (r) => r.soft_assets },
    { key: 'total_value_rupees', header: 'Total value', render: (r) => fmtINR(r.total_value_rupees) },
    { key: 'grade_a_total', header: 'Grade A', render: (r) => r.grade_a_total },
  ];

  const patStatCols: Column<PatStat>[] = [
    { key: 'patent_status', header: 'Patent status', render: (r) => r.patent_status },
    { key: 'asset_count', header: 'Assets', render: (r) => r.asset_count },
    { key: 'total_value_rupees', header: 'Value', render: (r) => fmtINR(r.total_value_rupees) },
    { key: 'avg_strength', header: 'Avg strength', render: (r) => r.avg_strength },
  ];

  const pillarCols: Column<Pillar>[] = [
    { key: 'strategic_pillar', header: 'Pillar', render: (r) => r.strategic_pillar },
    { key: 'hardware_count', header: 'HW', render: (r) => r.hardware_count },
    { key: 'soft_count', header: 'SW', render: (r) => r.soft_count },
    { key: 'combined_value_rupees', header: 'Combined value', render: (r) => fmtINR(r.combined_value_rupees) },
  ];

  const underprotCols: Column<Underprot>[] = [
    { key: 'asset_code', header: 'Code', render: (r) => r.asset_code },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'asset_title', header: 'Title', render: (r) => r.asset_title },
    { key: 'estimated_value_rupees', header: 'Value', render: (r) => fmtINR(r.estimated_value_rupees) },
    { key: 'patent_status', header: 'Patent', render: (r) => r.patent_status },
    { key: 'protection_strength_score', header: 'Strength', render: (r) => r.protection_strength_score },
    { key: 'defensibility_grade', header: 'Grade', render: (r) => r.defensibility_grade },
  ];

  const adoptionCols: Column<Adoption>[] = [
    { key: 'asset_code', header: 'Code', render: (r) => r.asset_code },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'asset_title', header: 'Title', render: (r) => r.asset_title },
    { key: 'soft_ip_kind', header: 'Kind', render: (r) => r.soft_ip_kind },
    { key: 'adoption_score', header: 'Adoption', render: (r) => r.adoption_score },
    { key: 'active_user_engineers', header: 'Active users', render: (r) => r.active_user_engineers },
    { key: 'invocation_count_quarter', header: 'Invocations Q', render: (r) => r.invocation_count_quarter },
    { key: 'estimated_value_rupees', header: 'Value', render: (r) => fmtINR(r.estimated_value_rupees) },
  ];

  const modalityCols: Column<Modality>[] = [
    { key: 'modality', header: 'Modality', render: (r) => r.modality },
    { key: 'hardware_assets', header: 'HW', render: (r) => r.hardware_assets },
    { key: 'soft_assets', header: 'SW', render: (r) => r.soft_assets },
    { key: 'combined_value_rupees', header: 'Combined value', render: (r) => fmtINR(r.combined_value_rupees) },
    { key: 'best_grade', header: 'Best grade', render: (r) => r.best_grade },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Quarterly Strategic Engineer-Driven Hardware-IP &amp; Soft-IP Portfolio Audit</h1>
        <p className="text-sm text-gray-600">Founder-only view. Engineer-surfaced IP — hardware jigs/fixtures/probes plus soft-IP algorithms/playbooks/datasets. Defensibility &gt;= grade B is the floor.</p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Portfolio overview</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No data" rowKey={(r, i) => String(r.asset_class ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top engineers by IP value</h2>
        <DataTable rows={topEngRows} columns={topEngCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Patent status breakdown (hardware)</h2>
        <DataTable rows={patStatRows} columns={patStatCols} emptyMessage="No patent data" rowKey={(r, i) => String(r.patent_status ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Strategic pillar distribution</h2>
        <DataTable rows={pillarRows} columns={pillarCols} emptyMessage="No pillars" rowKey={(r, i) => String(r.strategic_pillar ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Underprotected high-value assets (legal flag)</h2>
        <DataTable rows={underprotRows} columns={underprotCols} emptyMessage="None flagged" rowKey={(r, i) => String(r.asset_code ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Soft-IP adoption leaders</h2>
        <DataTable rows={adoptionRows} columns={adoptionCols} emptyMessage="No adoption data" rowKey={(r, i) => String(r.asset_code ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Modality coverage matrix</h2>
        <DataTable rows={modalityRows} columns={modalityCols} emptyMessage="No modality data" rowKey={(r, i) => String(r.modality ?? i)} />
      </section>
    </main>
  );
}
