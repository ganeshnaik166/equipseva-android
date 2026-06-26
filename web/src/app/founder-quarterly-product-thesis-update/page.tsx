import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_theses: number;
  validated: number;
  partially: number;
  inconclusive: number;
  invalidated: number;
  total_stake_lakh: number;
  avg_confidence: number;
};

type PillarRow = {
  pillar: string;
  thesis_count: number;
  avg_confidence: number;
  total_stake_lakh: number;
  persist_count: number;
  pivot_count: number;
};

type ThesisRow = {
  id: string;
  thesis_title: string;
  pillar: string;
  decision: string;
  verdict: string;
  confidence_pct: number;
  capital_stake_lakh: number;
  target_value: number;
  current_value: number;
  attainment_pct: number;
  outcome_note: string;
};

type SignalRow = {
  signal_label: string;
  thesis_title: string;
  signal_kind: string;
  measured_value: number;
  expected_value: number;
  delta_pct: number;
  strength: string;
  direction: string;
  observed_on: string;
  note: string;
};

type DecisionRow = {
  decision: string;
  thesis_count: number;
  total_stake_lakh: number;
  avg_confidence: number;
};

type AtRiskRow = {
  thesis_title: string;
  pillar: string;
  confidence_pct: number;
  capital_stake_lakh: number;
  verdict: string;
  decision: string;
  attainment_pct: number;
};

type CapitalRow = {
  verdict: string;
  total_stake_lakh: number;
  share_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, pillarRes, thesesRes, signalsRes, decisionsRes, atRiskRes, capitalRes] = await Promise.all([
    supabase.rpc('founder_thesis_overview_r2829'),
    supabase.rpc('founder_thesis_by_pillar_r2829'),
    supabase.rpc('founder_thesis_statements_list_r2829'),
    supabase.rpc('founder_thesis_signals_list_r2829'),
    supabase.rpc('founder_thesis_decision_breakdown_r2829'),
    supabase.rpc('founder_thesis_at_risk_r2829'),
    supabase.rpc('founder_thesis_capital_at_stake_r2829'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] as Overview) ?? {
    total_theses: 0,
    validated: 0,
    partially: 0,
    inconclusive: 0,
    invalidated: 0,
    total_stake_lakh: 0,
    avg_confidence: 0,
  };
  const pillars: PillarRow[] = (pillarRes.data as PillarRow[]) ?? [];
  const theses: ThesisRow[] = (thesesRes.data as ThesisRow[]) ?? [];
  const signals: SignalRow[] = (signalsRes.data as SignalRow[]) ?? [];
  const decisions: DecisionRow[] = (decisionsRes.data as DecisionRow[]) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[]) ?? [];
  const capital: CapitalRow[] = (capitalRes.data as CapitalRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Product Thesis Update</h1>
        <p className="text-sm text-gray-600">
          Round r2829 · thesis × signal × validation × pivot/persist × stake × outcome × verdict
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Theses" value={overview.total_theses} />
        <KpiCard label="Validated" value={overview.validated} />
        <KpiCard label="Partially Validated" value={overview.partially} />
        <KpiCard label="Inconclusive" value={overview.inconclusive} />
        <KpiCard label="Invalidated" value={overview.invalidated} />
        <KpiCard label="Capital At Stake (Lakh)" value={`Rs ${overview.total_stake_lakh}`} />
        <KpiCard label="Avg Confidence" value={`${overview.avg_confidence}%`} />
        <KpiCard label="At Risk Count" value={atRisk.length} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Pillar</h2>
        <DataTable
          rows={pillars}
          rowKey={(r, i) => String(r.pillar ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'pillar', header: 'Pillar', render: (r: PillarRow) => <span>{r.pillar}</span> },
            { key: 'thesis_count', header: 'Theses', render: (r: PillarRow) => <span>{r.thesis_count}</span> },
            { key: 'avg_confidence', header: 'Avg Confidence', render: (r: PillarRow) => <span>{r.avg_confidence}%</span> },
            { key: 'total_stake_lakh', header: 'Stake (Lakh)', render: (r: PillarRow) => <span>Rs {r.total_stake_lakh}</span> },
            { key: 'persist_count', header: 'Persist', render: (r: PillarRow) => <span>{r.persist_count}</span> },
            { key: 'pivot_count', header: 'Pivot', render: (r: PillarRow) => <span>{r.pivot_count}</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Thesis Statements</h2>
        <DataTable
          rows={theses}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'thesis_title', header: 'Thesis', render: (r: ThesisRow) => <span>{r.thesis_title}</span> },
            { key: 'pillar', header: 'Pillar', render: (r: ThesisRow) => <span>{r.pillar}</span> },
            { key: 'decision', header: 'Decision', render: (r: ThesisRow) => <span>{r.decision}</span> },
            { key: 'verdict', header: 'Verdict', render: (r: ThesisRow) => <span>{r.verdict}</span> },
            { key: 'confidence_pct', header: 'Confidence', render: (r: ThesisRow) => <span>{r.confidence_pct}%</span> },
            { key: 'capital_stake_lakh', header: 'Stake (Lakh)', render: (r: ThesisRow) => <span>Rs {r.capital_stake_lakh}</span> },
            { key: 'attainment_pct', header: 'Attainment', render: (r: ThesisRow) => <span>{r.attainment_pct}%</span> },
            { key: 'outcome_note', header: 'Outcome', render: (r: ThesisRow) => <span>{r.outcome_note}</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision Breakdown</h2>
        <DataTable
          rows={decisions}
          rowKey={(r, i) => String(r.decision ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'decision', header: 'Decision', render: (r: DecisionRow) => <span>{r.decision}</span> },
            { key: 'thesis_count', header: 'Theses', render: (r: DecisionRow) => <span>{r.thesis_count}</span> },
            { key: 'total_stake_lakh', header: 'Stake (Lakh)', render: (r: DecisionRow) => <span>Rs {r.total_stake_lakh}</span> },
            { key: 'avg_confidence', header: 'Avg Confidence', render: (r: DecisionRow) => <span>{r.avg_confidence}%</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Signals Log</h2>
        <DataTable
          rows={signals}
          rowKey={(r, i) => String(`${r.signal_label}-${i}`)}
          emptyMessage="No data"
          columns={[
            { key: 'observed_on', header: 'Observed', render: (r: SignalRow) => <span>{r.observed_on}</span> },
            { key: 'signal_label', header: 'Signal', render: (r: SignalRow) => <span>{r.signal_label}</span> },
            { key: 'thesis_title', header: 'Thesis', render: (r: SignalRow) => <span>{r.thesis_title}</span> },
            { key: 'signal_kind', header: 'Kind', render: (r: SignalRow) => <span>{r.signal_kind}</span> },
            { key: 'measured_value', header: 'Measured', render: (r: SignalRow) => <span>{r.measured_value}</span> },
            { key: 'expected_value', header: 'Expected', render: (r: SignalRow) => <span>{r.expected_value}</span> },
            { key: 'delta_pct', header: 'Delta', render: (r: SignalRow) => <span>{r.delta_pct}%</span> },
            { key: 'strength', header: 'Strength', render: (r: SignalRow) => <span>{r.strength}</span> },
            { key: 'direction', header: 'Direction', render: (r: SignalRow) => <span>{r.direction}</span> },
            { key: 'note', header: 'Note', render: (r: SignalRow) => <span>{r.note}</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-Risk Theses (confidence &lt; 70% or inconclusive)</h2>
        <DataTable
          rows={atRisk}
          rowKey={(r, i) => String(`${r.thesis_title}-${i}`)}
          emptyMessage="No data"
          columns={[
            { key: 'thesis_title', header: 'Thesis', render: (r: AtRiskRow) => <span>{r.thesis_title}</span> },
            { key: 'pillar', header: 'Pillar', render: (r: AtRiskRow) => <span>{r.pillar}</span> },
            { key: 'confidence_pct', header: 'Confidence', render: (r: AtRiskRow) => <span>{r.confidence_pct}%</span> },
            { key: 'capital_stake_lakh', header: 'Stake (Lakh)', render: (r: AtRiskRow) => <span>Rs {r.capital_stake_lakh}</span> },
            { key: 'verdict', header: 'Verdict', render: (r: AtRiskRow) => <span>{r.verdict}</span> },
            { key: 'decision', header: 'Decision', render: (r: AtRiskRow) => <span>{r.decision}</span> },
            { key: 'attainment_pct', header: 'Attainment', render: (r: AtRiskRow) => <span>{r.attainment_pct}%</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Capital At Stake by Verdict</h2>
        <DataTable
          rows={capital}
          rowKey={(r, i) => String(r.verdict ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: CapitalRow) => <span>{r.verdict}</span> },
            { key: 'total_stake_lakh', header: 'Stake (Lakh)', render: (r: CapitalRow) => <span>Rs {r.total_stake_lakh}</span> },
            { key: 'share_pct', header: 'Share', render: (r: CapitalRow) => <span>{r.share_pct}%</span> },
          ]}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border p-4 bg-white">
      <div className="text-xs uppercase text-gray-500">{label}</div>
      <div className="text-xl font-semibold mt-1">{value}</div>
    </div>
  );
}
