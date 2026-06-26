import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_assets: number;
  fully_ready: number;
  blocked_assets: number;
  major_incidents: number;
  avg_risk_score: number;
  total_downtime_minutes: number;
  exemplary_verdicts: number;
  escalations: number;
};

type Assessment = {
  id: string;
  chain_name: string;
  hospital_site: string;
  asset_category: string;
  asset_serial: string;
  festival_name: string;
  festival_weekend_start: string;
  prep_status: string;
  on_call_engineer: string;
  outcome: string;
  downtime_minutes: number;
  verdict: string;
  risk_score: number;
};

type ChainSummary = {
  chain_name: string;
  total_assets: number;
  ready_assets: number;
  high_risk_assets: number;
  total_downtime: number;
  avg_risk: number;
};

type FestivalBreakdown = {
  festival_name: string;
  asset_count: number;
  ready_count: number;
  incidents: number;
  total_downtime: number;
  next_weekend: string;
};

type Rotation = {
  id: string;
  engineer_name: string;
  city: string;
  festival_window: string;
  chains_covered: string;
  total_sites: number;
  shift_hours: number;
  incidents_handled: number;
  avg_response_minutes: number;
  fatigue_score: number;
  bonus_eligible: boolean;
  rotation_verdict: string;
};

type HighRisk = {
  chain_name: string;
  hospital_site: string;
  asset_serial: string;
  asset_category: string;
  prep_status: string;
  risk_score: number;
  verdict: string;
  notes: string | null;
};

type Fatigue = {
  engineer_name: string;
  total_sites: number;
  shift_hours: number;
  fatigue_score: number;
  incidents_handled: number;
  verdict: string;
};

type VerdictDist = {
  verdict: string;
  count: number;
  pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpisRes,
    assessmentsRes,
    chainsRes,
    festivalsRes,
    rotationsRes,
    highRiskRes,
    fatigueRes,
    verdictsRes,
  ] = await Promise.all([
    supabase.rpc('rpc_r2883_fleet_kpis'),
    supabase.rpc('rpc_r2883_assessments_list'),
    supabase.rpc('rpc_r2883_chain_summary'),
    supabase.rpc('rpc_r2883_festival_breakdown'),
    supabase.rpc('rpc_r2883_oncall_rotations'),
    supabase.rpc('rpc_r2883_high_risk_assets'),
    supabase.rpc('rpc_r2883_engineer_fatigue'),
    supabase.rpc('rpc_r2883_verdict_distribution'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_assets: 0,
    fully_ready: 0,
    blocked_assets: 0,
    major_incidents: 0,
    avg_risk_score: 0,
    total_downtime_minutes: 0,
    exemplary_verdicts: 0,
    escalations: 0,
  };

  const assessments: Assessment[] = (assessmentsRes.data as Assessment[]) ?? [];
  const chains: ChainSummary[] = (chainsRes.data as ChainSummary[]) ?? [];
  const festivals: FestivalBreakdown[] = (festivalsRes.data as FestivalBreakdown[]) ?? [];
  const rotations: Rotation[] = (rotationsRes.data as Rotation[]) ?? [];
  const highRisk: HighRisk[] = (highRiskRes.data as HighRisk[]) ?? [];
  const fatigue: Fatigue[] = (fatigueRes.data as Fatigue[]) ?? [];
  const verdicts: VerdictDist[] = (verdictsRes.data as VerdictDist[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">
          Hospital Chain Quarterly Equipment Fleet — Pre-Festival Readiness
        </h1>
        <p className="text-sm text-gray-600">
          Chain × asset × festival weekend × prep × on-call × outcome × verdict.
          Filter: risk_score &gt;= 40 OR prep_status = blocked surfaces in high-risk panel.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Total Assets" value={kpis.total_assets} />
        <Kpi label="Fully Ready" value={kpis.fully_ready} accent="green" />
        <Kpi label="Blocked" value={kpis.blocked_assets} accent="red" />
        <Kpi label="Major Incidents" value={kpis.major_incidents} accent="red" />
        <Kpi label="Avg Risk Score" value={kpis.avg_risk_score} />
        <Kpi label="Total Downtime (min)" value={kpis.total_downtime_minutes} />
        <Kpi label="Exemplary Verdicts" value={kpis.exemplary_verdicts} accent="green" />
        <Kpi label="Escalations" value={kpis.escalations} accent="amber" />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain Summary</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainSummary) => r.chain_name },
            { key: 'total_assets', header: 'Assets', render: (r: ChainSummary) => r.total_assets },
            { key: 'ready_assets', header: 'Ready', render: (r: ChainSummary) => r.ready_assets },
            { key: 'high_risk_assets', header: 'High Risk', render: (r: ChainSummary) => r.high_risk_assets },
            { key: 'total_downtime', header: 'Downtime (min)', render: (r: ChainSummary) => r.total_downtime },
            { key: 'avg_risk', header: 'Avg Risk', render: (r: ChainSummary) => r.avg_risk },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainSummary, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Festival Breakdown</h2>
        <DataTable
          rows={festivals}
          columns={[
            { key: 'festival_name', header: 'Festival', render: (r: FestivalBreakdown) => r.festival_name },
            { key: 'next_weekend', header: 'Next Weekend', render: (r: FestivalBreakdown) => r.next_weekend },
            { key: 'asset_count', header: 'Assets', render: (r: FestivalBreakdown) => r.asset_count },
            { key: 'ready_count', header: 'Ready', render: (r: FestivalBreakdown) => r.ready_count },
            { key: 'incidents', header: 'Incidents', render: (r: FestivalBreakdown) => r.incidents },
            { key: 'total_downtime', header: 'Downtime (min)', render: (r: FestivalBreakdown) => r.total_downtime },
          ]}
          emptyMessage="No data"
          rowKey={(r: FestivalBreakdown, i: number) => String(r.festival_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Assessments (sorted by risk)</h2>
        <DataTable
          rows={assessments}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Assessment) => r.chain_name },
            { key: 'hospital_site', header: 'Site', render: (r: Assessment) => r.hospital_site },
            { key: 'asset_category', header: 'Category', render: (r: Assessment) => r.asset_category },
            { key: 'asset_serial', header: 'Serial', render: (r: Assessment) => r.asset_serial },
            { key: 'festival_name', header: 'Festival', render: (r: Assessment) => r.festival_name },
            { key: 'festival_weekend_start', header: 'Weekend', render: (r: Assessment) => r.festival_weekend_start },
            { key: 'prep_status', header: 'Prep', render: (r: Assessment) => r.prep_status },
            { key: 'on_call_engineer', header: 'On-Call', render: (r: Assessment) => r.on_call_engineer },
            { key: 'outcome', header: 'Outcome', render: (r: Assessment) => r.outcome },
            { key: 'downtime_minutes', header: 'Downtime', render: (r: Assessment) => r.downtime_minutes },
            { key: 'verdict', header: 'Verdict', render: (r: Assessment) => r.verdict },
            { key: 'risk_score', header: 'Risk', render: (r: Assessment) => r.risk_score },
          ]}
          emptyMessage="No data"
          rowKey={(r: Assessment, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">High-Risk Assets (risk &gt;= 40 OR blocked)</h2>
        <DataTable
          rows={highRisk}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: HighRisk) => r.chain_name },
            { key: 'hospital_site', header: 'Site', render: (r: HighRisk) => r.hospital_site },
            { key: 'asset_serial', header: 'Serial', render: (r: HighRisk) => r.asset_serial },
            { key: 'asset_category', header: 'Category', render: (r: HighRisk) => r.asset_category },
            { key: 'prep_status', header: 'Prep', render: (r: HighRisk) => r.prep_status },
            { key: 'risk_score', header: 'Risk', render: (r: HighRisk) => r.risk_score },
            { key: 'verdict', header: 'Verdict', render: (r: HighRisk) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: HighRisk) => r.notes ?? '' },
          ]}
          emptyMessage="No high-risk assets"
          rowKey={(r: HighRisk, i: number) => String(r.asset_serial ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">On-Call Engineer Rotations</h2>
        <DataTable
          rows={rotations}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Rotation) => r.engineer_name },
            { key: 'city', header: 'City', render: (r: Rotation) => r.city },
            { key: 'festival_window', header: 'Window', render: (r: Rotation) => r.festival_window },
            { key: 'chains_covered', header: 'Chains', render: (r: Rotation) => r.chains_covered },
            { key: 'total_sites', header: 'Sites', render: (r: Rotation) => r.total_sites },
            { key: 'shift_hours', header: 'Shift Hrs', render: (r: Rotation) => r.shift_hours },
            { key: 'incidents_handled', header: 'Incidents', render: (r: Rotation) => r.incidents_handled },
            { key: 'avg_response_minutes', header: 'Avg Resp (min)', render: (r: Rotation) => r.avg_response_minutes },
            { key: 'fatigue_score', header: 'Fatigue', render: (r: Rotation) => r.fatigue_score },
            { key: 'bonus_eligible', header: 'Bonus', render: (r: Rotation) => (r.bonus_eligible ? 'yes' : 'no') },
            { key: 'rotation_verdict', header: 'Verdict', render: (r: Rotation) => r.rotation_verdict },
          ]}
          emptyMessage="No rotations"
          rowKey={(r: Rotation, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engineer Fatigue Watch (fatigue &gt;= 6.0)</h2>
        <DataTable
          rows={fatigue}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Fatigue) => r.engineer_name },
            { key: 'total_sites', header: 'Sites', render: (r: Fatigue) => r.total_sites },
            { key: 'shift_hours', header: 'Shift Hrs', render: (r: Fatigue) => r.shift_hours },
            { key: 'fatigue_score', header: 'Fatigue', render: (r: Fatigue) => r.fatigue_score },
            { key: 'incidents_handled', header: 'Incidents', render: (r: Fatigue) => r.incidents_handled },
            { key: 'verdict', header: 'Verdict', render: (r: Fatigue) => r.verdict },
          ]}
          emptyMessage="No fatigue alerts"
          rowKey={(r: Fatigue, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Verdict Distribution</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictDist) => r.verdict },
            { key: 'count', header: 'Count', render: (r: VerdictDist) => r.count },
            { key: 'pct', header: 'Pct (%)', render: (r: VerdictDist) => r.pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictDist, i: number) => String(r.verdict ?? i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value, accent }: { label: string; value: number | string; accent?: 'green' | 'red' | 'amber' }) {
  const color =
    accent === 'green'
      ? 'text-green-700'
      : accent === 'red'
      ? 'text-red-700'
      : accent === 'amber'
      ? 'text-amber-700'
      : 'text-gray-900';
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className={`text-2xl font-semibold ${color}`}>{value}</div>
    </div>
  );
}