import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  chains_tracked: number;
  total_attrition: number;
  weighted_attrition_rate_pct: number;
  total_arr_at_risk_rupees: number;
  contracts_at_risk: number;
  critical_chain_count: number;
};

type ChainRow = {
  id: string;
  chain_code: string;
  chain_name: string;
  quarter_label: string;
  attrition_count: number;
  attrition_rate_pct: number;
  primary_cause: string;
  exposure_band: string;
  amc_contracts_at_risk: number;
  arr_at_risk_rupees: number;
  knowledge_loss_score: number;
};

type CauseRow = {
  primary_cause: string;
  chain_count: number;
  total_attrition: number;
  arr_at_risk_rupees: number;
  avg_knowledge_loss: number;
};

type ExposureRow = {
  exposure_band: string;
  chain_count: number;
  contracts_at_risk: number;
  arr_at_risk_rupees: number;
};

type OutcomeRow = {
  outcome: string;
  action_count: number;
  retained_arr_rupees: number;
  lost_arr_rupees: number;
  avg_effectiveness: number;
};

type ActionRow = {
  id: string;
  chain_code: string;
  adapt_action: string;
  action_owner: string;
  initiated_at: string;
  closed_at: string | null;
  outcome: string;
  retained_arr_rupees: number;
  lost_arr_rupees: number;
  effectiveness_score: number;
  notes: string | null;
};

type EffectivenessRow = {
  adapt_action: string;
  action_count: number;
  avg_effectiveness: number;
  total_retained_arr: number;
  total_lost_arr: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return 'Rs ' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    chainsRes,
    causesRes,
    exposureRes,
    outcomesRes,
    actionsRes,
    effRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2755_attrition_overview'),
    supabase.rpc('founder_r2755_chain_breakdown'),
    supabase.rpc('founder_r2755_cause_distribution'),
    supabase.rpc('founder_r2755_exposure_summary'),
    supabase.rpc('founder_r2755_action_outcomes'),
    supabase.rpc('founder_r2755_action_log'),
    supabase.rpc('founder_r2755_action_effectiveness_by_type'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] as Overview) ?? {
    chains_tracked: 0,
    total_attrition: 0,
    weighted_attrition_rate_pct: 0,
    total_arr_at_risk_rupees: 0,
    contracts_at_risk: 0,
    critical_chain_count: 0,
  };
  const chains: ChainRow[] = (chainsRes.data as ChainRow[]) ?? [];
  const causes: CauseRow[] = (causesRes.data as CauseRow[]) ?? [];
  const exposures: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomesRes.data as OutcomeRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const effectiveness: EffectivenessRow[] =
    (effRes.data as EffectivenessRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">
          Hospital Chain Quarterly Staff Attrition Impact
        </h1>
        <p className="text-sm text-gray-600 mt-1">
          chain x attrition rate x cause x our exposure x adapt action x outcome
          — track which biomed teams are bleeding, why, and whether our
          adapt actions retain ARR.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <KPI label="Chains tracked" value={String(overview.chains_tracked)} />
        <KPI label="Total attrition" value={String(overview.total_attrition)} />
        <KPI
          label="Weighted attrition rate"
          value={`${Number(overview.weighted_attrition_rate_pct ?? 0).toFixed(2)}%`}
        />
        <KPI
          label="ARR at risk"
          value={rupees(overview.total_arr_at_risk_rupees)}
        />
        <KPI
          label="Contracts at risk"
          value={String(overview.contracts_at_risk)}
        />
        <KPI
          label="Critical-band chains"
          value={String(overview.critical_chain_count)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain breakdown</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'quarter_label', header: 'Quarter', render: (r: ChainRow) => r.quarter_label },
            { key: 'attrition_count', header: 'Lost', render: (r: ChainRow) => String(r.attrition_count) },
            { key: 'attrition_rate_pct', header: 'Rate %', render: (r: ChainRow) => `${Number(r.attrition_rate_pct).toFixed(2)}%` },
            { key: 'primary_cause', header: 'Cause', render: (r: ChainRow) => r.primary_cause },
            { key: 'exposure_band', header: 'Exposure', render: (r: ChainRow) => r.exposure_band },
            { key: 'amc_contracts_at_risk', header: 'AMC at risk', render: (r: ChainRow) => String(r.amc_contracts_at_risk) },
            { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: ChainRow) => rupees(r.arr_at_risk_rupees) },
            { key: 'knowledge_loss_score', header: 'Knowledge loss', render: (r: ChainRow) => `${r.knowledge_loss_score}/100` },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Cause distribution</h2>
          <DataTable
            rows={causes}
            columns={[
              { key: 'primary_cause', header: 'Cause', render: (r: CauseRow) => r.primary_cause },
              { key: 'chain_count', header: 'Chains', render: (r: CauseRow) => String(r.chain_count) },
              { key: 'total_attrition', header: 'Attrition', render: (r: CauseRow) => String(r.total_attrition) },
              { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: CauseRow) => rupees(r.arr_at_risk_rupees) },
              { key: 'avg_knowledge_loss', header: 'Avg knowledge loss', render: (r: CauseRow) => Number(r.avg_knowledge_loss ?? 0).toFixed(1) },
            ]}
            emptyMessage="No data"
            rowKey={(r: CauseRow, i: number) => String(r.primary_cause ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Exposure band</h2>
          <DataTable
            rows={exposures}
            columns={[
              { key: 'exposure_band', header: 'Band', render: (r: ExposureRow) => r.exposure_band },
              { key: 'chain_count', header: 'Chains', render: (r: ExposureRow) => String(r.chain_count) },
              { key: 'contracts_at_risk', header: 'Contracts', render: (r: ExposureRow) => String(r.contracts_at_risk) },
              { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: ExposureRow) => rupees(r.arr_at_risk_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: ExposureRow, i: number) => String(r.exposure_band ?? i)}
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Action outcomes</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'action_count', header: 'Count', render: (r: OutcomeRow) => String(r.action_count) },
              { key: 'retained_arr_rupees', header: 'Retained ARR', render: (r: OutcomeRow) => rupees(r.retained_arr_rupees) },
              { key: 'lost_arr_rupees', header: 'Lost ARR', render: (r: OutcomeRow) => rupees(r.lost_arr_rupees) },
              { key: 'avg_effectiveness', header: 'Avg effect.', render: (r: OutcomeRow) => Number(r.avg_effectiveness ?? 0).toFixed(1) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Action effectiveness by type</h2>
          <DataTable
            rows={effectiveness}
            columns={[
              { key: 'adapt_action', header: 'Action', render: (r: EffectivenessRow) => r.adapt_action },
              { key: 'action_count', header: 'Count', render: (r: EffectivenessRow) => String(r.action_count) },
              { key: 'avg_effectiveness', header: 'Avg score', render: (r: EffectivenessRow) => Number(r.avg_effectiveness ?? 0).toFixed(1) },
              { key: 'total_retained_arr', header: 'Retained ARR', render: (r: EffectivenessRow) => rupees(r.total_retained_arr) },
              { key: 'total_lost_arr', header: 'Lost ARR', render: (r: EffectivenessRow) => rupees(r.total_lost_arr) },
            ]}
            emptyMessage="No data"
            rowKey={(r: EffectivenessRow, i: number) => String(r.adapt_action ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Adapt action log</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: ActionRow) => r.chain_code },
            { key: 'adapt_action', header: 'Action', render: (r: ActionRow) => r.adapt_action },
            { key: 'action_owner', header: 'Owner', render: (r: ActionRow) => r.action_owner },
            { key: 'initiated_at', header: 'Initiated', render: (r: ActionRow) => r.initiated_at },
            { key: 'closed_at', header: 'Closed', render: (r: ActionRow) => r.closed_at ?? '-' },
            { key: 'outcome', header: 'Outcome', render: (r: ActionRow) => r.outcome },
            { key: 'retained_arr_rupees', header: 'Retained ARR', render: (r: ActionRow) => rupees(r.retained_arr_rupees) },
            { key: 'lost_arr_rupees', header: 'Lost ARR', render: (r: ActionRow) => rupees(r.lost_arr_rupees) },
            { key: 'effectiveness_score', header: 'Score', render: (r: ActionRow) => `${r.effectiveness_score}/100` },
            { key: 'notes', header: 'Notes', render: (r: ActionRow) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 p-4 bg-white">
      <div className="text-xs uppercase text-gray-500">{label}</div>
      <div className="text-xl font-semibold mt-1">{value}</div>
    </div>
  );
}