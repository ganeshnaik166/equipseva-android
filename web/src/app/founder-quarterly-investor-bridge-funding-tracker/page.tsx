import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_asks: number;
  total_ask_amount_rupees: number;
  total_committed_rupees: number;
  total_wired_rupees: number;
  active_pipeline: number;
  closed_wins: number;
};

type AskRow = {
  id: string;
  investor_name: string;
  investor_type: string;
  ask_amount_rupees: number;
  term_sheet_valuation_rupees: number;
  instrument: string;
  discount_pct: number;
  cap_rupees: number | null;
  status: string;
  ask_opened_on: string;
  last_touch_on: string;
  quarter_tag: string;
  notes: string | null;
};

type WireRow = {
  id: string;
  investor_name: string;
  commitment_amount_rupees: number;
  wired_amount_rupees: number;
  committed_on: string;
  wire_expected_on: string | null;
  wire_received_on: string | null;
  wire_status: string;
  outcome: string;
  bank_ref: string | null;
  outcome_notes: string | null;
};

type StatusRow = {
  status: string;
  ask_count: number;
  total_ask_rupees: number;
  avg_valuation_rupees: number;
};

type InstrumentRow = {
  instrument: string;
  ask_count: number;
  total_ask_rupees: number;
  avg_discount_pct: number;
};

type PipelineRow = {
  wire_status: string;
  wire_count: number;
  committed_rupees: number;
  wired_rupees: number;
  gap_rupees: number;
};

type TopRow = {
  investor_name: string;
  investor_type: string;
  commitment_amount_rupees: number;
  wired_amount_rupees: number;
  fill_pct: number;
  outcome: string;
};

type QuarterRow = {
  quarter_tag: string;
  ask_count: number;
  total_ask_rupees: number;
  committed_rupees: number;
  wired_rupees: number;
  conversion_pct: number;
};

function fmtINR(rupees: number | null | undefined): string {
  if (rupees === null || rupees === undefined) return '-';
  if (rupees >= 10000000) return `₹${(rupees / 10000000).toFixed(2)} Cr`;
  if (rupees >= 100000) return `₹${(rupees / 100000).toFixed(2)} L`;
  return `₹${rupees.toLocaleString('en-IN')}`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, asksRes, wiresRes, statusRes, instrumentRes, pipelineRes, topRes, quarterRes] = await Promise.all([
    supabase.rpc('get_bridge_funding_overview_r2725'),
    supabase.rpc('list_bridge_funding_asks_r2725'),
    supabase.rpc('list_bridge_funding_wires_r2725'),
    supabase.rpc('get_bridge_funding_by_status_r2725'),
    supabase.rpc('get_bridge_funding_by_instrument_r2725'),
    supabase.rpc('get_bridge_funding_wire_pipeline_r2725'),
    supabase.rpc('get_bridge_funding_top_commitments_r2725'),
    supabase.rpc('get_bridge_funding_quarter_summary_r2725'),
  ]);

  const overview: OverviewRow | null = (overviewRes.data?.[0] as OverviewRow) ?? null;
  const asks: AskRow[] = (asksRes.data as AskRow[]) ?? [];
  const wires: WireRow[] = (wiresRes.data as WireRow[]) ?? [];
  const byStatus: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const byInstrument: InstrumentRow[] = (instrumentRes.data as InstrumentRow[]) ?? [];
  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Investor Bridge Funding Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Investor × bridge ask × terms × status × commitment × wire × outcome
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500">Total Asks</div>
          <div className="text-xl font-semibold">{overview?.total_asks ?? 0}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500">Total Ask</div>
          <div className="text-xl font-semibold">{fmtINR(overview?.total_ask_amount_rupees ?? 0)}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500">Committed</div>
          <div className="text-xl font-semibold">{fmtINR(overview?.total_committed_rupees ?? 0)}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500">Wired</div>
          <div className="text-xl font-semibold text-emerald-700">{fmtINR(overview?.total_wired_rupees ?? 0)}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500">Active Pipeline</div>
          <div className="text-xl font-semibold">{overview?.active_pipeline ?? 0}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500">Closed Wins</div>
          <div className="text-xl font-semibold text-emerald-700">{overview?.closed_wins ?? 0}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Status</h2>
        <DataTable
          rows={byStatus}
          columns={[
            { key: 'status', header: 'Status', render: (r: StatusRow) => <span className="font-medium">{r.status}</span> },
            { key: 'ask_count', header: 'Asks', render: (r: StatusRow) => r.ask_count },
            { key: 'total_ask_rupees', header: 'Total Ask', render: (r: StatusRow) => fmtINR(r.total_ask_rupees) },
            { key: 'avg_valuation_rupees', header: 'Avg Valuation', render: (r: StatusRow) => fmtINR(r.avg_valuation_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: StatusRow, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Instrument</h2>
        <DataTable
          rows={byInstrument}
          columns={[
            { key: 'instrument', header: 'Instrument', render: (r: InstrumentRow) => <span className="font-medium">{r.instrument}</span> },
            { key: 'ask_count', header: 'Asks', render: (r: InstrumentRow) => r.ask_count },
            { key: 'total_ask_rupees', header: 'Total Ask', render: (r: InstrumentRow) => fmtINR(r.total_ask_rupees) },
            { key: 'avg_discount_pct', header: 'Avg Discount %', render: (r: InstrumentRow) => `${Number(r.avg_discount_pct ?? 0).toFixed(2)}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: InstrumentRow, i: number) => String(r.instrument ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wire Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={[
            { key: 'wire_status', header: 'Wire Status', render: (r: PipelineRow) => <span className="font-medium">{r.wire_status}</span> },
            { key: 'wire_count', header: 'Count', render: (r: PipelineRow) => r.wire_count },
            { key: 'committed_rupees', header: 'Committed', render: (r: PipelineRow) => fmtINR(r.committed_rupees) },
            { key: 'wired_rupees', header: 'Wired', render: (r: PipelineRow) => fmtINR(r.wired_rupees) },
            { key: 'gap_rupees', header: 'Gap', render: (r: PipelineRow) => <span className="text-amber-700">{fmtINR(r.gap_rupees)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: PipelineRow, i: number) => String(r.wire_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Summary</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter_tag', header: 'Quarter', render: (r: QuarterRow) => <span className="font-medium">{r.quarter_tag}</span> },
            { key: 'ask_count', header: 'Asks', render: (r: QuarterRow) => r.ask_count },
            { key: 'total_ask_rupees', header: 'Total Ask', render: (r: QuarterRow) => fmtINR(r.total_ask_rupees) },
            { key: 'committed_rupees', header: 'Committed', render: (r: QuarterRow) => fmtINR(r.committed_rupees) },
            { key: 'wired_rupees', header: 'Wired', render: (r: QuarterRow) => fmtINR(r.wired_rupees) },
            { key: 'conversion_pct', header: 'Conversion %', render: (r: QuarterRow) => `${Number(r.conversion_pct ?? 0).toFixed(2)}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(r.quarter_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Commitments</h2>
        <DataTable
          rows={top}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: TopRow) => <span className="font-medium">{r.investor_name}</span> },
            { key: 'investor_type', header: 'Type', render: (r: TopRow) => r.investor_type },
            { key: 'commitment_amount_rupees', header: 'Committed', render: (r: TopRow) => fmtINR(r.commitment_amount_rupees) },
            { key: 'wired_amount_rupees', header: 'Wired', render: (r: TopRow) => fmtINR(r.wired_amount_rupees) },
            { key: 'fill_pct', header: 'Fill %', render: (r: TopRow) => `${Number(r.fill_pct ?? 0).toFixed(2)}%` },
            { key: 'outcome', header: 'Outcome', render: (r: TopRow) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopRow, i: number) => `${r.investor_name}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Bridge Asks</h2>
        <DataTable
          rows={asks}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: AskRow) => <span className="font-medium">{r.investor_name}</span> },
            { key: 'investor_type', header: 'Type', render: (r: AskRow) => r.investor_type },
            { key: 'ask_amount_rupees', header: 'Ask', render: (r: AskRow) => fmtINR(r.ask_amount_rupees) },
            { key: 'term_sheet_valuation_rupees', header: 'Valuation', render: (r: AskRow) => fmtINR(r.term_sheet_valuation_rupees) },
            { key: 'instrument', header: 'Instrument', render: (r: AskRow) => r.instrument },
            { key: 'discount_pct', header: 'Discount', render: (r: AskRow) => `${Number(r.discount_pct ?? 0).toFixed(2)}%` },
            { key: 'cap_rupees', header: 'Cap', render: (r: AskRow) => fmtINR(r.cap_rupees) },
            { key: 'status', header: 'Status', render: (r: AskRow) => r.status },
            { key: 'quarter_tag', header: 'Qtr', render: (r: AskRow) => r.quarter_tag },
            { key: 'last_touch_on', header: 'Last Touch', render: (r: AskRow) => r.last_touch_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: AskRow) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Wires & Outcomes</h2>
        <DataTable
          rows={wires}
          columns={[
            { key: 'investor_name', header: 'Investor', render: (r: WireRow) => <span className="font-medium">{r.investor_name}</span> },
            { key: 'commitment_amount_rupees', header: 'Committed', render: (r: WireRow) => fmtINR(r.commitment_amount_rupees) },
            { key: 'wired_amount_rupees', header: 'Wired', render: (r: WireRow) => fmtINR(r.wired_amount_rupees) },
            { key: 'committed_on', header: 'Committed On', render: (r: WireRow) => r.committed_on },
            { key: 'wire_expected_on', header: 'Wire Expected', render: (r: WireRow) => r.wire_expected_on ?? '-' },
            { key: 'wire_received_on', header: 'Wire Received', render: (r: WireRow) => r.wire_received_on ?? '-' },
            { key: 'wire_status', header: 'Wire Status', render: (r: WireRow) => r.wire_status },
            { key: 'outcome', header: 'Outcome', render: (r: WireRow) => r.outcome },
            { key: 'bank_ref', header: 'Bank Ref', render: (r: WireRow) => r.bank_ref ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: WireRow) => r.id}
        />
      </section>
    </div>
  );
}
