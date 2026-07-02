import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_bets: number;
  active_bets: number;
  total_cost_lakhs: number;
  total_upside_lakhs: number;
  portfolio_payback_months: number;
  weighted_risk: number;
  weighted_confidence: number;
  doubled_down_count: number;
  killed_or_paused_count: number;
};

type Ranking = {
  bet_code: string;
  bet_name: string;
  quarter: string;
  commit_level: string;
  cost_inr_lakhs: number;
  upside_inr_lakhs: number;
  roi_multiple: number;
  risk_adj_score: number;
  priority_rank: number;
};

type QuarterDist = {
  quarter: string;
  bet_count: number;
  total_cost_lakhs: number;
  total_upside_lakhs: number;
  avg_risk: number;
  avg_confidence: number;
};

type Reweight = {
  bet_code: string;
  bet_name: string;
  event_date: string;
  prior_commit: string;
  new_commit: string;
  prior_weight_pct: number;
  new_weight_pct: number;
  weight_delta: number;
  signal_strength: string;
  evidence_note: string;
};

type StopTrigger = {
  bet_code: string;
  bet_name: string;
  status: string;
  commit_level: string;
  stop_trigger: string;
  risk_score: number;
  alert_level: string;
};

type CommitLadder = {
  commit_level: string;
  bet_count: number;
  total_cost_lakhs: number;
  total_upside_lakhs: number;
  avg_payback_months: number;
};

type Velocity = {
  event_month: string;
  reweight_count: number;
  upgrades: number;
  downgrades: number;
  net_weight_delta: number;
  overwhelming_signals: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, rankRes, quarterRes, reweightRes, stopRes, ladderRes, velocityRes] = await Promise.all([
    supabase.rpc('founder_r2737_bet_portfolio_kpis'),
    supabase.rpc('founder_r2737_bet_priority_ranking'),
    supabase.rpc('founder_r2737_bet_quarter_distribution'),
    supabase.rpc('founder_r2737_bet_reweight_history'),
    supabase.rpc('founder_r2737_bet_stop_triggers'),
    supabase.rpc('founder_r2737_bet_commit_ladder'),
    supabase.rpc('founder_r2737_bet_reweight_velocity'),
  ]);

  const kpi: Kpi | null = (kpiRes.data as Kpi[] | null)?.[0] ?? null;
  const ranking: Ranking[] = (rankRes.data as Ranking[] | null) ?? [];
  const quarters: QuarterDist[] = (quarterRes.data as QuarterDist[] | null) ?? [];
  const reweights: Reweight[] = (reweightRes.data as Reweight[] | null) ?? [];
  const stops: StopTrigger[] = (stopRes.data as StopTrigger[] | null) ?? [];
  const ladder: CommitLadder[] = (ladderRes.data as CommitLadder[] | null) ?? [];
  const velocity: Velocity[] = (velocityRes.data as Velocity[] | null) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Bet Prioritization</h1>
        <p className="text-sm text-gray-600">
          bet × cost × upside × risk × commit × stop × reweight decision
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total bets</div>
          <div className="text-2xl font-bold">{kpi?.total_bets ?? 0}</div>
          <div className="text-xs text-gray-500">{kpi?.active_bets ?? 0} active</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Cost / Upside (Lakhs)</div>
          <div className="text-2xl font-bold">
            ₹{Number(kpi?.total_cost_lakhs ?? 0).toFixed(1)} / ₹{Number(kpi?.total_upside_lakhs ?? 0).toFixed(1)}
          </div>
          <div className="text-xs text-gray-500">payback {kpi?.portfolio_payback_months ?? 0} mo</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Weighted risk / confidence</div>
          <div className="text-2xl font-bold">
            {Number(kpi?.weighted_risk ?? 0).toFixed(2)} / {Number(kpi?.weighted_confidence ?? 0).toFixed(0)}%
          </div>
          <div className="text-xs text-gray-500">risk 0–10 scale</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Doubled down / Killed</div>
          <div className="text-2xl font-bold">
            {kpi?.doubled_down_count ?? 0} / {kpi?.killed_or_paused_count ?? 0}
          </div>
          <div className="text-xs text-gray-500">commit ladder extremes</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Priority ranking (risk-adjusted ROI)</h2>
        <DataTable
          rows={ranking}
          columns={[
            { key: 'priority_rank', header: 'Rank', render: (r: Ranking) => <span>#{r.priority_rank}</span> },
            { key: 'bet_code', header: 'Bet', render: (r: Ranking) => <span className="font-mono text-xs">{r.bet_code}</span> },
            { key: 'bet_name', header: 'Name', render: (r: Ranking) => <span>{r.bet_name}</span> },
            { key: 'quarter', header: 'Quarter', render: (r: Ranking) => <span>{r.quarter}</span> },
            { key: 'commit_level', header: 'Commit', render: (r: Ranking) => <span>{r.commit_level}</span> },
            { key: 'cost_inr_lakhs', header: 'Cost (L)', render: (r: Ranking) => <span>₹{Number(r.cost_inr_lakhs).toFixed(1)}</span> },
            { key: 'upside_inr_lakhs', header: 'Upside (L)', render: (r: Ranking) => <span>₹{Number(r.upside_inr_lakhs).toFixed(1)}</span> },
            { key: 'roi_multiple', header: 'ROI x', render: (r: Ranking) => <span>{Number(r.roi_multiple).toFixed(2)}x</span> },
            { key: 'risk_adj_score', header: 'Risk-adj', render: (r: Ranking) => <span>{Number(r.risk_adj_score).toFixed(3)}</span> },
          ]}
          emptyMessage="No bets"
          rowKey={(r: Ranking, i: number) => String(r.bet_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter distribution</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: QuarterDist) => <span>{r.quarter}</span> },
            { key: 'bet_count', header: 'Bets', render: (r: QuarterDist) => <span>{r.bet_count}</span> },
            { key: 'total_cost_lakhs', header: 'Cost (L)', render: (r: QuarterDist) => <span>₹{Number(r.total_cost_lakhs).toFixed(1)}</span> },
            { key: 'total_upside_lakhs', header: 'Upside (L)', render: (r: QuarterDist) => <span>₹{Number(r.total_upside_lakhs).toFixed(1)}</span> },
            { key: 'avg_risk', header: 'Avg risk', render: (r: QuarterDist) => <span>{Number(r.avg_risk).toFixed(2)}</span> },
            { key: 'avg_confidence', header: 'Avg conf', render: (r: QuarterDist) => <span>{Number(r.avg_confidence).toFixed(0)}%</span> },
          ]}
          emptyMessage="No quarters"
          rowKey={(r: QuarterDist, i: number) => String(r.quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Commit ladder</h2>
        <DataTable
          rows={ladder}
          columns={[
            { key: 'commit_level', header: 'Commit level', render: (r: CommitLadder) => <span>{r.commit_level}</span> },
            { key: 'bet_count', header: 'Bets', render: (r: CommitLadder) => <span>{r.bet_count}</span> },
            { key: 'total_cost_lakhs', header: 'Cost (L)', render: (r: CommitLadder) => <span>₹{Number(r.total_cost_lakhs).toFixed(1)}</span> },
            { key: 'total_upside_lakhs', header: 'Upside (L)', render: (r: CommitLadder) => <span>₹{Number(r.total_upside_lakhs).toFixed(1)}</span> },
            { key: 'avg_payback_months', header: 'Avg payback', render: (r: CommitLadder) => <span>{Number(r.avg_payback_months).toFixed(1)} mo</span> },
          ]}
          emptyMessage="No commit levels"
          rowKey={(r: CommitLadder, i: number) => String(r.commit_level ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stop triggers (active surveillance)</h2>
        <DataTable
          rows={stops}
          columns={[
            { key: 'bet_code', header: 'Bet', render: (r: StopTrigger) => <span className="font-mono text-xs">{r.bet_code}</span> },
            { key: 'bet_name', header: 'Name', render: (r: StopTrigger) => <span>{r.bet_name}</span> },
            { key: 'status', header: 'Status', render: (r: StopTrigger) => <span>{r.status}</span> },
            { key: 'commit_level', header: 'Commit', render: (r: StopTrigger) => <span>{r.commit_level}</span> },
            { key: 'risk_score', header: 'Risk', render: (r: StopTrigger) => <span>{Number(r.risk_score).toFixed(2)}</span> },
            { key: 'alert_level', header: 'Alert', render: (r: StopTrigger) => <span>{r.alert_level}</span> },
            { key: 'stop_trigger', header: 'Stop trigger', render: (r: StopTrigger) => <span className="text-xs">{r.stop_trigger}</span> },
          ]}
          emptyMessage="No stop triggers"
          rowKey={(r: StopTrigger, i: number) => String(r.bet_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reweight history</h2>
        <DataTable
          rows={reweights}
          columns={[
            { key: 'event_date', header: 'Date', render: (r: Reweight) => <span>{r.event_date}</span> },
            { key: 'bet_code', header: 'Bet', render: (r: Reweight) => <span className="font-mono text-xs">{r.bet_code}</span> },
            { key: 'prior_commit', header: 'From', render: (r: Reweight) => <span>{r.prior_commit}</span> },
            { key: 'new_commit', header: 'To', render: (r: Reweight) => <span>{r.new_commit}</span> },
            { key: 'prior_weight_pct', header: 'Prior %', render: (r: Reweight) => <span>{r.prior_weight_pct}%</span> },
            { key: 'new_weight_pct', header: 'New %', render: (r: Reweight) => <span>{r.new_weight_pct}%</span> },
            { key: 'weight_delta', header: 'Delta', render: (r: Reweight) => <span>{r.weight_delta >= 0 ? '+' : ''}{r.weight_delta}</span> },
            { key: 'signal_strength', header: 'Signal', render: (r: Reweight) => <span>{r.signal_strength}</span> },
            { key: 'evidence_note', header: 'Evidence', render: (r: Reweight) => <span className="text-xs">{r.evidence_note}</span> },
          ]}
          emptyMessage="No reweights"
          rowKey={(r: Reweight, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reweight velocity (monthly)</h2>
        <DataTable
          rows={velocity}
          columns={[
            { key: 'event_month', header: 'Month', render: (r: Velocity) => <span>{r.event_month}</span> },
            { key: 'reweight_count', header: 'Count', render: (r: Velocity) => <span>{r.reweight_count}</span> },
            { key: 'upgrades', header: 'Upgrades', render: (r: Velocity) => <span>{r.upgrades}</span> },
            { key: 'downgrades', header: 'Downgrades', render: (r: Velocity) => <span>{r.downgrades}</span> },
            { key: 'net_weight_delta', header: 'Net delta', render: (r: Velocity) => <span>{r.net_weight_delta >= 0 ? '+' : ''}{r.net_weight_delta}</span> },
            { key: 'overwhelming_signals', header: 'Strong signals', render: (r: Velocity) => <span>{r.overwhelming_signals}</span> },
          ]}
          emptyMessage="No velocity"
          rowKey={(r: Velocity, i: number) => String(r.event_month ?? i)}
        />
      </section>
    </div>
  );
}
