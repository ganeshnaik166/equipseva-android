import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_pitches: number;
  won_pitches: number;
  lost_pitches: number;
  open_pitches: number;
  pipeline_rupees: number;
  realized_rupees: number;
};

type PitchRow = {
  pitch_code: string;
  customer_name: string;
  customer_segment: string;
  equipment_model: string;
  warranty_expiry_date: string;
  extension_months: number;
  extension_price_rupees: number;
  close_status: string;
  upsell_amc_offered: boolean;
};

type SegmentRow = {
  customer_segment: string;
  pitch_count: number;
  won_count: number;
  total_value_rupees: number;
};

type OutcomeRow = {
  pitch_code: string;
  outcome_stage: string;
  outcome_result: string;
  realized_revenue_rupees: number;
  upsell_amc_value_rupees: number;
  next_step: string;
};

type UpsellRow = {
  upsell_offered_count: number;
  amc_realized_rupees: number;
  attach_rate_pct: number;
};

type ExpiringRow = {
  pitch_code: string;
  customer_name: string;
  equipment_model: string;
  warranty_expiry_date: string;
  days_until_expiry: number;
  close_status: string;
};

type FunnelRow = {
  outcome_stage: string;
  stage_count: number;
  won_count: number;
  lost_count: number;
};

type CategoryRow = {
  equipment_category: string;
  pitch_count: number;
  realized_rupees: number;
  pipeline_rupees: number;
};

function fmtINR(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, pitchesRes, segmentRes, outcomesRes, upsellRes, expiringRes, funnelRes, categoryRes] =
    await Promise.all([
      supabase.rpc('r2744_pitch_summary'),
      supabase.rpc('r2744_pitches_list'),
      supabase.rpc('r2744_by_segment'),
      supabase.rpc('r2744_outcomes_list'),
      supabase.rpc('r2744_upsell_summary'),
      supabase.rpc('r2744_expiring_soon'),
      supabase.rpc('r2744_close_funnel'),
      supabase.rpc('r2744_category_revenue'),
    ]);

  const summary: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    total_pitches: 0,
    won_pitches: 0,
    lost_pitches: 0,
    open_pitches: 0,
    pipeline_rupees: 0,
    realized_rupees: 0,
  };
  const pitches: PitchRow[] = (pitchesRes.data as PitchRow[]) ?? [];
  const segments: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomesRes.data as OutcomeRow[]) ?? [];
  const upsell: UpsellRow = (upsellRes.data?.[0] as UpsellRow) ?? {
    upsell_offered_count: 0,
    amc_realized_rupees: 0,
    attach_rate_pct: 0,
  };
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[]) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Quarterly Warranty Extension Pitch</h1>
        <p className="text-sm text-gray-600">
          Round r2744 · equipment × warranty expiry × extension price × close × upsell × outcome
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total Pitches</div>
          <div className="text-2xl font-semibold">{summary.total_pitches}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Won</div>
          <div className="text-2xl font-semibold text-green-700">{summary.won_pitches}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Open Pipeline</div>
          <div className="text-2xl font-semibold">{fmtINR(summary.pipeline_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Realized</div>
          <div className="text-2xl font-semibold">{fmtINR(summary.realized_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">AMC Upsell Offered</div>
          <div className="text-2xl font-semibold">{upsell.upsell_offered_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">AMC Realized</div>
          <div className="text-2xl font-semibold">{fmtINR(upsell.amc_realized_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Attach Rate</div>
          <div className="text-2xl font-semibold">{Number(upsell.attach_rate_pct ?? 0)}%</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Lost</div>
          <div className="text-2xl font-semibold text-red-700">{summary.lost_pitches}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Pitches</h2>
        <DataTable
          rows={pitches}
          columns={[
            { key: 'pitch_code', header: 'Pitch', render: (r: PitchRow) => r.pitch_code },
            { key: 'customer_name', header: 'Customer', render: (r: PitchRow) => r.customer_name },
            { key: 'customer_segment', header: 'Segment', render: (r: PitchRow) => r.customer_segment },
            { key: 'equipment_model', header: 'Equipment', render: (r: PitchRow) => r.equipment_model },
            { key: 'warranty_expiry_date', header: 'Warranty Expires', render: (r: PitchRow) => r.warranty_expiry_date },
            { key: 'extension_months', header: 'Months', render: (r: PitchRow) => String(r.extension_months) },
            { key: 'extension_price_rupees', header: 'Price', render: (r: PitchRow) => fmtINR(r.extension_price_rupees) },
            { key: 'close_status', header: 'Status', render: (r: PitchRow) => r.close_status },
            { key: 'upsell_amc_offered', header: 'AMC Upsell', render: (r: PitchRow) => (r.upsell_amc_offered ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: PitchRow, i: number) => String(r.pitch_code ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Expiring Soon (open pitches)</h2>
        <DataTable
          rows={expiring}
          columns={[
            { key: 'pitch_code', header: 'Pitch', render: (r: ExpiringRow) => r.pitch_code },
            { key: 'customer_name', header: 'Customer', render: (r: ExpiringRow) => r.customer_name },
            { key: 'equipment_model', header: 'Equipment', render: (r: ExpiringRow) => r.equipment_model },
            { key: 'warranty_expiry_date', header: 'Expires', render: (r: ExpiringRow) => r.warranty_expiry_date },
            { key: 'days_until_expiry', header: 'Days Left', render: (r: ExpiringRow) => String(r.days_until_expiry) },
            { key: 'close_status', header: 'Status', render: (r: ExpiringRow) => r.close_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: ExpiringRow, i: number) => String(r.pitch_code ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">By Segment</h2>
          <DataTable
            rows={segments}
            columns={[
              { key: 'customer_segment', header: 'Segment', render: (r: SegmentRow) => r.customer_segment },
              { key: 'pitch_count', header: 'Pitches', render: (r: SegmentRow) => String(r.pitch_count) },
              { key: 'won_count', header: 'Won', render: (r: SegmentRow) => String(r.won_count) },
              { key: 'total_value_rupees', header: 'Value', render: (r: SegmentRow) => fmtINR(r.total_value_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: SegmentRow, i: number) => String(r.customer_segment ?? i)}
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">By Equipment Category</h2>
          <DataTable
            rows={categories}
            columns={[
              { key: 'equipment_category', header: 'Category', render: (r: CategoryRow) => r.equipment_category },
              { key: 'pitch_count', header: 'Pitches', render: (r: CategoryRow) => String(r.pitch_count) },
              { key: 'realized_rupees', header: 'Realized', render: (r: CategoryRow) => fmtINR(r.realized_rupees) },
              { key: 'pipeline_rupees', header: 'Pipeline', render: (r: CategoryRow) => fmtINR(r.pipeline_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: CategoryRow, i: number) => String(r.equipment_category ?? i)}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Close Funnel</h2>
        <DataTable
          rows={funnel}
          columns={[
            { key: 'outcome_stage', header: 'Stage', render: (r: FunnelRow) => r.outcome_stage },
            { key: 'stage_count', header: 'Count', render: (r: FunnelRow) => String(r.stage_count) },
            { key: 'won_count', header: 'Won', render: (r: FunnelRow) => String(r.won_count) },
            { key: 'lost_count', header: 'Lost', render: (r: FunnelRow) => String(r.lost_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: FunnelRow, i: number) => String(r.outcome_stage ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Outcome Log</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'pitch_code', header: 'Pitch', render: (r: OutcomeRow) => r.pitch_code },
            { key: 'outcome_stage', header: 'Stage', render: (r: OutcomeRow) => r.outcome_stage },
            { key: 'outcome_result', header: 'Result', render: (r: OutcomeRow) => r.outcome_result },
            { key: 'realized_revenue_rupees', header: 'Realized', render: (r: OutcomeRow) => fmtINR(r.realized_revenue_rupees) },
            { key: 'upsell_amc_value_rupees', header: 'AMC Upsell', render: (r: OutcomeRow) => fmtINR(r.upsell_amc_value_rupees) },
            { key: 'next_step', header: 'Next Step', render: (r: OutcomeRow) => r.next_step },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.pitch_code + '-' + i)}
        />
      </section>
    </main>
  );
}
