import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_projects: number;
  active_projects: number;
  total_publications: number;
  published_count: number;
  total_data_points_millions: number;
  total_budget_lakhs: number;
  total_followon_grant_lakhs: number;
  total_citations: number;
  avg_impact_factor: number;
  equipseva_credited_pct: number;
  national_policy_impact_count: number;
  unique_chains: number;
};

type ProjectRow = {
  project_code: string;
  chain_name: string;
  quarter: string;
  project_title: string;
  equipment_category: string;
  equipment_count: number;
  data_points_shared: number;
  budget_inr_lakhs: number;
  status: string;
  ethics_clearance_status: string;
};

type PublicationRow = {
  publication_title: string;
  journal_name: string;
  impact_factor: number;
  publication_date: string;
  citation_count: number;
  publication_type: string;
  policy_impact_level: string;
  equipseva_credited: boolean;
  follow_on_grant_inr_lakhs: number;
  status: string;
};

type ChainRow = {
  chain_name: string;
  chain_tier: string;
  project_count: number;
  total_equipment: number;
  total_data_points: number;
  total_budget_lakhs: number;
  publication_count: number;
};

type DataShareRow = {
  quarter: string;
  projects: number;
  data_points_millions: number;
  budget_lakhs: number;
  active_chains: number;
};

type OutcomeRow = {
  policy_impact_level: string;
  publication_count: number;
  total_citations: number;
  total_followon_grant_lakhs: number;
  total_press_coverage: number;
};

type PipelineRow = {
  status: string;
  project_count: number;
  total_budget_lakhs: number;
  pct_of_portfolio: number;
};

type EquipmentRow = {
  equipment_category: string;
  project_count: number;
  total_units: number;
  total_data_points: number;
  total_budget_lakhs: number;
};

type TrendRow = {
  quarter: string;
  publications: number;
  citations: number;
  avg_impact_factor: number;
  followon_grant_lakhs: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    projectsRes,
    publicationsRes,
    chainsRes,
    dataShareRes,
    outcomesRes,
    pipelineRes,
    equipmentRes,
    trendRes,
  ] = await Promise.all([
    supabase.rpc('founder_icmr_collab_overview_r2727'),
    supabase.rpc('founder_icmr_collab_projects_r2727'),
    supabase.rpc('founder_icmr_collab_publications_r2727'),
    supabase.rpc('founder_icmr_collab_chain_breakdown_r2727'),
    supabase.rpc('founder_icmr_collab_data_share_r2727'),
    supabase.rpc('founder_icmr_collab_outcomes_r2727'),
    supabase.rpc('founder_icmr_collab_pipeline_r2727'),
    supabase.rpc('founder_icmr_collab_top_equipment_r2727'),
    supabase.rpc('founder_icmr_collab_quarterly_trend_r2727'),
  ]);

  const overview: Overview | null = (overviewRes.data?.[0] as Overview) ?? null;
  const projects: ProjectRow[] = (projectsRes.data as ProjectRow[]) ?? [];
  const publications: PublicationRow[] = (publicationsRes.data as PublicationRow[]) ?? [];
  const chains: ChainRow[] = (chainsRes.data as ChainRow[]) ?? [];
  const dataShare: DataShareRow[] = (dataShareRes.data as DataShareRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomesRes.data as OutcomeRow[]) ?? [];
  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[]) ?? [];
  const equipment: EquipmentRow[] = (equipmentRes.data as EquipmentRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  const fmtNum = (n: number | null | undefined) =>
    typeof n === 'number' ? n.toLocaleString('en-IN') : '-';
  const fmtMoney = (n: number | null | undefined) =>
    typeof n === 'number' ? `₹${n.toLocaleString('en-IN')} L` : '-';

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="border-b pb-4">
        <h1 className="text-3xl font-bold">Hospital Chain Quarterly ICMR Research Collab</h1>
        <p className="text-sm text-gray-600 mt-1">
          Quarterly tracker: chain &times; ICMR project &times; equipment &times; data shared &times; publication &times; outcome.
          Founder view of research moat &amp; policy influence funnel.
        </p>
      </header>

      {overview && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <KPI label="Total Projects" value={fmtNum(overview.total_projects)} sub={`${fmtNum(overview.active_projects)} active`} />
          <KPI label="Publications" value={fmtNum(overview.total_publications)} sub={`${fmtNum(overview.published_count)} published`} />
          <KPI label="Data Points (M)" value={String(overview.total_data_points_millions ?? 0)} sub="shared with ICMR" />
          <KPI label="Total Budget" value={fmtMoney(overview.total_budget_lakhs)} sub="committed across chains" />
          <KPI label="Follow-on Grants" value={fmtMoney(overview.total_followon_grant_lakhs)} sub="post-publication" />
          <KPI label="Total Citations" value={fmtNum(overview.total_citations)} sub={`avg IF ${overview.avg_impact_factor ?? 0}`} />
          <KPI label="EquipSeva Credited" value={`${overview.equipseva_credited_pct ?? 0}%`} sub="of publications" />
          <KPI label="National Policy Impact" value={fmtNum(overview.national_policy_impact_count)} sub={`${fmtNum(overview.unique_chains)} chains`} />
        </section>
      )}

      <section>
        <h2 className="text-xl font-semibold mb-3">Quarterly Data Share Volume</h2>
        <DataTable
          rows={dataShare}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: DataShareRow) => r.quarter },
            { key: 'projects', header: 'Projects', render: (r: DataShareRow) => fmtNum(r.projects) },
            { key: 'data_points_millions', header: 'Data Points (M)', render: (r: DataShareRow) => String(r.data_points_millions) },
            { key: 'budget_lakhs', header: 'Budget', render: (r: DataShareRow) => fmtMoney(r.budget_lakhs) },
            { key: 'active_chains', header: 'Active Chains', render: (r: DataShareRow) => fmtNum(r.active_chains) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DataShareRow, i: number) => String(r.quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Chain Breakdown</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'chain_tier', header: 'Tier', render: (r: ChainRow) => r.chain_tier },
            { key: 'project_count', header: 'Projects', render: (r: ChainRow) => fmtNum(r.project_count) },
            { key: 'total_equipment', header: 'Equipment', render: (r: ChainRow) => fmtNum(r.total_equipment) },
            { key: 'total_data_points', header: 'Data Points', render: (r: ChainRow) => fmtNum(r.total_data_points) },
            { key: 'total_budget_lakhs', header: 'Budget', render: (r: ChainRow) => fmtMoney(r.total_budget_lakhs) },
            { key: 'publication_count', header: 'Publications', render: (r: ChainRow) => fmtNum(r.publication_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Active &amp; Pipeline Projects</h2>
        <DataTable
          rows={projects}
          columns={[
            { key: 'project_code', header: 'Code', render: (r: ProjectRow) => r.project_code },
            { key: 'chain_name', header: 'Chain', render: (r: ProjectRow) => r.chain_name },
            { key: 'quarter', header: 'Quarter', render: (r: ProjectRow) => r.quarter },
            { key: 'project_title', header: 'Title', render: (r: ProjectRow) => r.project_title },
            { key: 'equipment_category', header: 'Equipment', render: (r: ProjectRow) => `${r.equipment_category} (${r.equipment_count})` },
            { key: 'data_points_shared', header: 'Data Points', render: (r: ProjectRow) => fmtNum(r.data_points_shared) },
            { key: 'budget_inr_lakhs', header: 'Budget', render: (r: ProjectRow) => fmtMoney(r.budget_inr_lakhs) },
            { key: 'status', header: 'Status', render: (r: ProjectRow) => r.status },
            { key: 'ethics_clearance_status', header: 'Ethics', render: (r: ProjectRow) => r.ethics_clearance_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: ProjectRow, i: number) => String(r.project_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Publications &amp; Outcomes</h2>
        <DataTable
          rows={publications}
          columns={[
            { key: 'publication_title', header: 'Title', render: (r: PublicationRow) => r.publication_title },
            { key: 'journal_name', header: 'Journal', render: (r: PublicationRow) => r.journal_name },
            { key: 'impact_factor', header: 'IF', render: (r: PublicationRow) => String(r.impact_factor) },
            { key: 'publication_date', header: 'Date', render: (r: PublicationRow) => r.publication_date },
            { key: 'citation_count', header: 'Cites', render: (r: PublicationRow) => fmtNum(r.citation_count) },
            { key: 'publication_type', header: 'Type', render: (r: PublicationRow) => r.publication_type },
            { key: 'policy_impact_level', header: 'Policy Impact', render: (r: PublicationRow) => r.policy_impact_level },
            { key: 'equipseva_credited', header: 'Credited', render: (r: PublicationRow) => (r.equipseva_credited ? 'Yes' : 'No') },
            { key: 'follow_on_grant_inr_lakhs', header: 'Grant', render: (r: PublicationRow) => fmtMoney(r.follow_on_grant_inr_lakhs) },
            { key: 'status', header: 'Status', render: (r: PublicationRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: PublicationRow, i: number) => String(r.publication_title ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 className="text-xl font-semibold mb-3">Outcome &amp; Policy Funnel</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'policy_impact_level', header: 'Level', render: (r: OutcomeRow) => r.policy_impact_level },
              { key: 'publication_count', header: 'Pubs', render: (r: OutcomeRow) => fmtNum(r.publication_count) },
              { key: 'total_citations', header: 'Cites', render: (r: OutcomeRow) => fmtNum(r.total_citations) },
              { key: 'total_followon_grant_lakhs', header: 'Grant', render: (r: OutcomeRow) => fmtMoney(r.total_followon_grant_lakhs) },
              { key: 'total_press_coverage', header: 'Press', render: (r: OutcomeRow) => fmtNum(r.total_press_coverage) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.policy_impact_level ?? i)}
          />
        </div>

        <div>
          <h2 className="text-xl font-semibold mb-3">Pipeline Status</h2>
          <DataTable
            rows={pipeline}
            columns={[
              { key: 'status', header: 'Status', render: (r: PipelineRow) => r.status },
              { key: 'project_count', header: 'Count', render: (r: PipelineRow) => fmtNum(r.project_count) },
              { key: 'total_budget_lakhs', header: 'Budget', render: (r: PipelineRow) => fmtMoney(r.total_budget_lakhs) },
              { key: 'pct_of_portfolio', header: '% Portfolio', render: (r: PipelineRow) => `${r.pct_of_portfolio ?? 0}%` },
            ]}
            emptyMessage="No data"
            rowKey={(r: PipelineRow, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Equipment Categories</h2>
        <DataTable
          rows={equipment}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: EquipmentRow) => r.equipment_category },
            { key: 'project_count', header: 'Projects', render: (r: EquipmentRow) => fmtNum(r.project_count) },
            { key: 'total_units', header: 'Units', render: (r: EquipmentRow) => fmtNum(r.total_units) },
            { key: 'total_data_points', header: 'Data Points', render: (r: EquipmentRow) => fmtNum(r.total_data_points) },
            { key: 'total_budget_lakhs', header: 'Budget', render: (r: EquipmentRow) => fmtMoney(r.total_budget_lakhs) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EquipmentRow, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Quarterly Publication Trend</h2>
        <DataTable
          rows={trend}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: TrendRow) => r.quarter },
            { key: 'publications', header: 'Publications', render: (r: TrendRow) => fmtNum(r.publications) },
            { key: 'citations', header: 'Citations', render: (r: TrendRow) => fmtNum(r.citations) },
            { key: 'avg_impact_factor', header: 'Avg IF', render: (r: TrendRow) => String(r.avg_impact_factor) },
            { key: 'followon_grant_lakhs', header: 'Follow-on Grant', render: (r: TrendRow) => fmtMoney(r.followon_grant_lakhs) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => String(r.quarter ?? i)}
        />
      </section>
    </div>
  );
}

function KPI({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="border rounded-lg p-4 bg-white shadow-sm">
      <div className="text-xs text-gray-500 uppercase tracking-wide">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
      {sub && <div className="text-xs text-gray-500 mt-1">{sub}</div>}
    </div>
  );
}
