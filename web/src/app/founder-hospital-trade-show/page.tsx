import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ShowRow = {
  show_id: string;
  show_name: string;
  city: string;
  state: string | null;
  start_date: string;
  end_date: string;
  total_spend_rupees: number;
  lead_count: number;
  hot_count: number;
  won_count: number;
  pipeline_rupees: number;
};

type FollowupRow = {
  lead_id: string;
  show_name: string;
  hospital_name: string;
  contact_name: string;
  contact_phone: string | null;
  intent: string;
  stage: string;
  source: string;
  estimated_amc_rupees: number;
  next_follow_up_date: string;
  days_until: number;
};

type StageRow = {
  stage: string;
  lead_count: number;
  pipeline_rupees: number;
  avg_amc_rupees: number;
};

type RoiRow = {
  show_id: string;
  show_name: string;
  start_date: string;
  total_spend_rupees: number;
  leads_captured: number;
  amc_won_count: number;
  realized_amc_rupees: number;
  roi_multiple: number;
};

type HotRow = {
  lead_id: string;
  show_name: string;
  hospital_name: string;
  contact_name: string;
  contact_phone: string | null;
  contact_email: string | null;
  city: string | null;
  state: string | null;
  bed_count: number | null;
  equipment_interest: string[] | null;
  estimated_amc_rupees: number;
  stage: string;
  next_follow_up_date: string | null;
  last_contact_at: string | null;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function FounderHospitalTradeShowPage() {
  const sb = await getSupabaseServerClient();

  let shows: ShowRow[] = [];
  let followups: FollowupRow[] = [];
  let stages: StageRow[] = [];
  let roi: RoiRow[] = [];
  let hot: HotRow[] = [];
  let errMsg: string | null = null;

  try {
    const r1 = await sb.rpc('list_trade_shows');
    if (r1.error) throw r1.error;
    shows = (r1.data ?? []) as ShowRow[];

    const r2 = await sb.rpc('list_followup_due_leads');
    if (r2.error) throw r2.error;
    followups = (r2.data ?? []) as FollowupRow[];

    const r3 = await sb.rpc('trade_show_pipeline_by_stage');
    if (r3.error) throw r3.error;
    stages = (r3.data ?? []) as StageRow[];

    const r4 = await sb.rpc('trade_show_roi');
    if (r4.error) throw r4.error;
    roi = (r4.data ?? []) as RoiRow[];

    const r5 = await sb.rpc('list_hot_leads');
    if (r5.error) throw r5.error;
    hot = (r5.data ?? []) as HotRow[];
  } catch (e) {
    errMsg = e instanceof Error ? e.message : 'Failed to load trade-show pipeline';
  }

  const totalSpend = shows.reduce((a, b) => a + (b.total_spend_rupees ?? 0), 0);
  const totalLeads = shows.reduce((a, b) => a + (b.lead_count ?? 0), 0);
  const totalHot = shows.reduce((a, b) => a + (b.hot_count ?? 0), 0);
  const totalPipeline = shows.reduce((a, b) => a + (b.pipeline_rupees ?? 0), 0);
  const realized = roi.reduce((a, b) => a + (b.realized_amc_rupees ?? 0), 0);
  const roiMultiple = totalSpend > 0 ? (realized / totalSpend).toFixed(2) : '0.00';

  const showCols: Column<ShowRow>[] = [
    { key: 'show_name', header: 'Show', render: (r) => r.show_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'start_date', header: 'Start', render: (r) => r.start_date },
    { key: 'total_spend_rupees', header: 'Spend', render: (r) => inr(r.total_spend_rupees) },
    { key: 'lead_count', header: 'Leads', render: (r) => String(r.lead_count ?? 0) },
    { key: 'hot_count', header: 'Hot', render: (r) => String(r.hot_count ?? 0) },
    { key: 'won_count', header: 'Won', render: (r) => String(r.won_count ?? 0) },
    { key: 'pipeline_rupees', header: 'Pipeline', render: (r) => inr(r.pipeline_rupees) },
  ];

  const followupCols: Column<FollowupRow>[] = [
    { key: 'next_follow_up_date', header: 'Due', render: (r) => r.next_follow_up_date ?? '—' },
    { key: 'days_until', header: 'Days', render: (r) => String(r.days_until ?? 0) },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'contact_phone', header: 'Phone', render: (r) => r.contact_phone ?? '—' },
    { key: 'intent', header: 'Intent', render: (r) => r.intent },
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'source', header: 'Source', render: (r) => r.source },
    { key: 'estimated_amc_rupees', header: 'Est. AMC', render: (r) => inr(r.estimated_amc_rupees) },
    { key: 'show_name', header: 'Show', render: (r) => r.show_name },
  ];

  const stageCols: Column<StageRow>[] = [
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'lead_count', header: 'Leads', render: (r) => String(r.lead_count ?? 0) },
    { key: 'pipeline_rupees', header: 'Pipeline', render: (r) => inr(r.pipeline_rupees) },
    { key: 'avg_amc_rupees', header: 'Avg AMC', render: (r) => inr(r.avg_amc_rupees) },
  ];

  const roiCols: Column<RoiRow>[] = [
    { key: 'show_name', header: 'Show', render: (r) => r.show_name },
    { key: 'start_date', header: 'Start', render: (r) => r.start_date },
    { key: 'total_spend_rupees', header: 'Spend', render: (r) => inr(r.total_spend_rupees) },
    { key: 'leads_captured', header: 'Leads', render: (r) => String(r.leads_captured ?? 0) },
    { key: 'amc_won_count', header: 'AMC Won', render: (r) => String(r.amc_won_count ?? 0) },
    { key: 'realized_amc_rupees', header: 'Realized', render: (r) => inr(r.realized_amc_rupees) },
    { key: 'roi_multiple', header: 'ROI x', render: (r) => String(r.roi_multiple ?? 0) },
  ];

  const hotCols: Column<HotRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'contact_phone', header: 'Phone', render: (r) => r.contact_phone ?? '—' },
    { key: 'city', header: 'City', render: (r) => r.city ?? '—' },
    { key: 'bed_count', header: 'Beds', render: (r) => (r.bed_count !== null && r.bed_count !== undefined ? String(r.bed_count) : '—') },
    { key: 'estimated_amc_rupees', header: 'Est. AMC', render: (r) => inr(r.estimated_amc_rupees) },
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'next_follow_up_date', header: 'Next', render: (r) => r.next_follow_up_date ?? '—' },
    { key: 'show_name', header: 'Show', render: (r) => r.show_name },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-semibold">Hospital Trade-Show Pipeline</h1>
        <p className="text-sm text-gray-600 mt-1">
          Biomedical trade-show leads · intent · follow-up cadence · AMC conversion ROI.
        </p>
      </div>

      {errMsg ? (
        <div className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">
          {errMsg}
        </div>
      ) : null}

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total Spend</div>
          <div className="text-lg font-semibold">{inr(totalSpend)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Leads Captured</div>
          <div className="text-lg font-semibold">{totalLeads}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Hot Leads</div>
          <div className="text-lg font-semibold">{totalHot}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open Pipeline</div>
          <div className="text-lg font-semibold">{inr(totalPipeline)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">ROI Multiple</div>
          <div className="text-lg font-semibold">{roiMultiple}x</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-ups due (next 3 days)</h2>
        <DataTable rows={followups} columns={followupCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hot leads</h2>
        <DataTable rows={hot} columns={hotCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pipeline by stage</h2>
        <DataTable rows={stages} columns={stageCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Trade shows</h2>
        <DataTable rows={shows} columns={showCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">ROI by show</h2>
        <DataTable rows={roi} columns={roiCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
