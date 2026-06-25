import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  segment_count: number;
  campaign_count: number;
  avg_aided_awareness: number;
  avg_unaided_awareness: number;
  avg_consideration: number;
  avg_preference: number;
  avg_nps: number;
  avg_nps_delta: number;
  total_spend_rupees: number;
  avg_qoq_shift: number;
  surging_segments: number;
  weak_segments: number;
};

type Segment = {
  id: string;
  quarter: string;
  segment: string;
  region: string;
  sample_size: number;
  aided_awareness_pct: number;
  unaided_awareness_pct: number;
  consideration_pct: number;
  preference_pct: number;
  nps_score: number;
  prior_nps_score: number;
  nps_delta: number;
  signal_strength: string;
  campaign_tag: string;
  qoq_shift_pct: number;
  surveyed_at: string;
};

type Campaign = {
  id: string;
  campaign_tag: string;
  campaign_name: string;
  quarter: string;
  channel: string;
  spend_rupees: number;
  impressions_count: number;
  reach_count: number;
  awareness_lift_pct: number;
  consideration_lift_pct: number;
  nps_delta: number;
  signal_label: string;
  shift_verdict: string;
  cost_per_reach: number;
};

type SignalRow = {
  signal_strength: string;
  segment_count: number;
  avg_nps: number;
  avg_shift: number;
};

type ShiftRow = {
  shift_verdict: string;
  campaign_count: number;
  total_spend: number;
  avg_awareness_lift: number;
  avg_nps_delta: number;
};

type NpsMover = {
  segment: string;
  region: string;
  nps_score: number;
  prior_nps_score: number;
  nps_delta: number;
  qoq_shift_pct: number;
  signal_strength: string;
};

type Efficiency = {
  campaign_name: string;
  channel: string;
  spend_rupees: number;
  awareness_lift_pct: number;
  cost_per_awareness_point: number | null;
  nps_delta: number;
  shift_verdict: string;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, segRes, campRes, signalRes, shiftRes, moverRes, effRes] = await Promise.all([
    supabase.rpc('brand_equity_pulse_kpis_r2781'),
    supabase.rpc('brand_equity_list_segments_r2781'),
    supabase.rpc('brand_equity_list_campaigns_r2781'),
    supabase.rpc('brand_equity_signal_mix_r2781'),
    supabase.rpc('brand_equity_shift_verdicts_r2781'),
    supabase.rpc('brand_equity_nps_movers_r2781'),
    supabase.rpc('brand_equity_efficiency_r2781'),
  ]);

  const kpis: Kpis | null = (kpisRes.data && kpisRes.data[0]) || null;
  const segments: Segment[] = segRes.data || [];
  const campaigns: Campaign[] = campRes.data || [];
  const signals: SignalRow[] = signalRes.data || [];
  const shifts: ShiftRow[] = shiftRes.data || [];
  const movers: NpsMover[] = moverRes.data || [];
  const efficiency: Efficiency[] = effRes.data || [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Brand Equity Pulse</h1>
        <p className="text-sm text-gray-600">
          Segment x awareness x consideration x NPS x signal x campaign x shift — Q2-2026 readout
        </p>
      </div>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Segments tracked</div>
          <div className="text-xl font-semibold">{kpis?.segment_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Campaigns live</div>
          <div className="text-xl font-semibold">{kpis?.campaign_count ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg aided awareness</div>
          <div className="text-xl font-semibold">{pct(kpis?.avg_aided_awareness)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg unaided awareness</div>
          <div className="text-xl font-semibold">{pct(kpis?.avg_unaided_awareness)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg consideration</div>
          <div className="text-xl font-semibold">{pct(kpis?.avg_consideration)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg preference</div>
          <div className="text-xl font-semibold">{pct(kpis?.avg_preference)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg NPS</div>
          <div className="text-xl font-semibold">{kpis?.avg_nps ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg NPS delta QoQ</div>
          <div className="text-xl font-semibold">{kpis?.avg_nps_delta ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total spend</div>
          <div className="text-xl font-semibold">{inr(kpis?.total_spend_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg QoQ shift</div>
          <div className="text-xl font-semibold">{pct(kpis?.avg_qoq_shift)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Surging segments</div>
          <div className="text-xl font-semibold">{kpis?.surging_segments ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Weak segments</div>
          <div className="text-xl font-semibold">{kpis?.weak_segments ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Segment pulse (awareness & consideration)</h2>
        <DataTable
          rows={segments}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Segment) => r.quarter },
            { key: 'segment', header: 'Segment', render: (r: Segment) => r.segment },
            { key: 'region', header: 'Region', render: (r: Segment) => r.region },
            { key: 'sample_size', header: 'n', render: (r: Segment) => r.sample_size },
            { key: 'aided', header: 'Aided', render: (r: Segment) => pct(r.aided_awareness_pct) },
            { key: 'unaided', header: 'Unaided', render: (r: Segment) => pct(r.unaided_awareness_pct) },
            { key: 'consideration', header: 'Consider', render: (r: Segment) => pct(r.consideration_pct) },
            { key: 'preference', header: 'Prefer', render: (r: Segment) => pct(r.preference_pct) },
            { key: 'nps', header: 'NPS', render: (r: Segment) => r.nps_score },
            { key: 'delta', header: 'NPS delta', render: (r: Segment) => r.nps_delta },
            { key: 'signal', header: 'Signal', render: (r: Segment) => r.signal_strength },
            { key: 'qoq', header: 'QoQ shift', render: (r: Segment) => pct(r.qoq_shift_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Segment, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Campaign portfolio (spend & lift)</h2>
        <DataTable
          rows={campaigns}
          columns={[
            { key: 'name', header: 'Campaign', render: (r: Campaign) => r.campaign_name },
            { key: 'quarter', header: 'Quarter', render: (r: Campaign) => r.quarter },
            { key: 'channel', header: 'Channel', render: (r: Campaign) => r.channel },
            { key: 'spend', header: 'Spend', render: (r: Campaign) => inr(r.spend_rupees) },
            { key: 'reach', header: 'Reach', render: (r: Campaign) => Number(r.reach_count).toLocaleString('en-IN') },
            { key: 'awareness_lift', header: 'Awareness lift', render: (r: Campaign) => pct(r.awareness_lift_pct) },
            { key: 'consideration_lift', header: 'Consider lift', render: (r: Campaign) => pct(r.consideration_lift_pct) },
            { key: 'nps_delta', header: 'NPS delta', render: (r: Campaign) => r.nps_delta },
            { key: 'signal', header: 'Signal', render: (r: Campaign) => r.signal_label },
            { key: 'verdict', header: 'Shift verdict', render: (r: Campaign) => r.shift_verdict },
            { key: 'cpr', header: 'Cost/reach', render: (r: Campaign) => inr(r.cost_per_reach) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Campaign, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Signal strength mix</h2>
          <DataTable
            rows={signals}
            columns={[
              { key: 'signal', header: 'Signal', render: (r: SignalRow) => r.signal_strength },
              { key: 'count', header: 'Segments', render: (r: SignalRow) => r.segment_count },
              { key: 'nps', header: 'Avg NPS', render: (r: SignalRow) => r.avg_nps },
              { key: 'shift', header: 'Avg shift', render: (r: SignalRow) => pct(r.avg_shift) },
            ]}
            emptyMessage="No data"
            rowKey={(r: SignalRow, i: number) => String(r.signal_strength ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Shift verdicts (cut / hold / scale / double-down)</h2>
          <DataTable
            rows={shifts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: ShiftRow) => r.shift_verdict },
              { key: 'count', header: 'Campaigns', render: (r: ShiftRow) => r.campaign_count },
              { key: 'spend', header: 'Total spend', render: (r: ShiftRow) => inr(r.total_spend) },
              { key: 'lift', header: 'Avg awareness lift', render: (r: ShiftRow) => pct(r.avg_awareness_lift) },
              { key: 'nps', header: 'Avg NPS delta', render: (r: ShiftRow) => r.avg_nps_delta },
            ]}
            emptyMessage="No data"
            rowKey={(r: ShiftRow, i: number) => String(r.shift_verdict ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NPS movers (this quarter vs prior)</h2>
        <DataTable
          rows={movers}
          columns={[
            { key: 'segment', header: 'Segment', render: (r: NpsMover) => r.segment },
            { key: 'region', header: 'Region', render: (r: NpsMover) => r.region },
            { key: 'now', header: 'NPS now', render: (r: NpsMover) => r.nps_score },
            { key: 'prior', header: 'NPS prior', render: (r: NpsMover) => r.prior_nps_score },
            { key: 'delta', header: 'Delta', render: (r: NpsMover) => r.nps_delta },
            { key: 'qoq', header: 'QoQ shift', render: (r: NpsMover) => pct(r.qoq_shift_pct) },
            { key: 'signal', header: 'Signal', render: (r: NpsMover) => r.signal_strength },
          ]}
          emptyMessage="No data"
          rowKey={(r: NpsMover, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Efficiency leaderboard (cost per awareness point)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Lower is better — spend ÷ awareness lift &gt;= 0
        </p>
        <DataTable
          rows={efficiency}
          columns={[
            { key: 'name', header: 'Campaign', render: (r: Efficiency) => r.campaign_name },
            { key: 'channel', header: 'Channel', render: (r: Efficiency) => r.channel },
            { key: 'spend', header: 'Spend', render: (r: Efficiency) => inr(r.spend_rupees) },
            { key: 'lift', header: 'Awareness lift', render: (r: Efficiency) => pct(r.awareness_lift_pct) },
            { key: 'cpap', header: 'Cost / awareness pt', render: (r: Efficiency) => inr(r.cost_per_awareness_point ?? 0) },
            { key: 'nps', header: 'NPS delta', render: (r: Efficiency) => r.nps_delta },
            { key: 'verdict', header: 'Verdict', render: (r: Efficiency) => r.shift_verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Efficiency, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
