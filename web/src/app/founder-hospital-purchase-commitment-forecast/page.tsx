import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Commitment = {
  id: string;
  hospital_name: string;
  commitment_type: string;
  equipment_category: string;
  expected_value_rupees: number;
  expected_close_month: string;
  confidence: string;
  probability_pct: number;
  budget_approval_status: string;
  status: string;
  next_followup_at: string | null;
  created_at: string;
};

type TopRow = {
  id: string;
  hospital_name: string;
  expected_value_rupees: number;
  confidence: string;
  probability_pct: number;
  weighted_value_rupees: number;
  expected_close_month: string;
};

type EventRow = {
  id: string;
  commitment_id: string;
  event_type: string;
  event_note: string | null;
  created_at: string;
};

type Agg = {
  total_commitments: number;
  open_commitments: number;
  won_commitments: number;
  total_pipeline_rupees: number;
  weighted_pipeline_rupees: number;
  committed_pipeline_rupees: number;
  high_confidence_rupees: number;
  next_quarter_pipeline_rupees: number;
  hospitals_count: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [listRes, topRes, eventsRes, aggRes] = await Promise.all([
    sb.rpc('list_hospital_purchase_commitments_r2223', { p_limit: 100 }),
    sb.rpc('top_hospital_purchase_commitments_r2223', { p_limit: 10 }),
    sb.rpc('recent_actions_hospital_purchase_commitments_r2223', { p_limit: 50 }),
    sb.rpc('aggregate_hospital_purchase_commitments_r2223'),
  ]);

  const list: Commitment[] = (listRes.data as Commitment[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const aggRaw = aggRes.data as Agg[] | Agg | null;
  const agg: Agg = Array.isArray(aggRaw) ? (aggRaw[0] ?? ({} as Agg)) : (aggRaw ?? ({} as Agg));

  const listCols: Column<Commitment>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'commitment_type', header: 'Type', render: (r: any) => String(r.commitment_type ?? '') },
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'expected_value_rupees', header: 'Value', render: (r: any) => rupees(r.expected_value_rupees) },
    { key: 'expected_close_month', header: 'Close month', render: (r: any) => String(r.expected_close_month ?? '').slice(0, 7) },
    { key: 'confidence', header: 'Confidence', render: (r: any) => String(r.confidence ?? '') },
    { key: 'probability_pct', header: 'Prob %', render: (r: any) => String(r.probability_pct ?? 0) + '%' },
    { key: 'budget_approval_status', header: 'Budget', render: (r: any) => String(r.budget_approval_status ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'expected_value_rupees', header: 'Gross', render: (r: any) => rupees(r.expected_value_rupees) },
    { key: 'probability_pct', header: 'Prob %', render: (r: any) => String(r.probability_pct ?? 0) + '%' },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => rupees(r.weighted_value_rupees) },
    { key: 'confidence', header: 'Confidence', render: (r: any) => String(r.confidence ?? '') },
    { key: 'expected_close_month', header: 'Close', render: (r: any) => String(r.expected_close_month ?? '').slice(0, 7) },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'event_type', header: 'Event', render: (r: any) => String(r.event_type ?? '') },
    { key: 'event_note', header: 'Note', render: (r: any) => String(r.event_note ?? '') },
    { key: 'created_at', header: 'When', render: (r: any) => String(r.created_at ?? '').slice(0, 16).replace('T', ' ') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital purchase commitment forecast
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Buyback & upgrade commitments from hospitals over the next 12 months — value, confidence, weighted pipeline.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open commitments</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.open_commitments ?? 0)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total pipeline</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(agg.total_pipeline_rupees)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Weighted (prob-adj)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(agg.weighted_pipeline_rupees)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Committed (hard)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(agg.committed_pipeline_rupees)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>High confidence</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(agg.high_confidence_rupees)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Next quarter pipeline</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(agg.next_quarter_pipeline_rupees)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Hospitals tracked</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.hospitals_count ?? 0)}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Won (closed)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{String(agg.won_commitments ?? 0)}</div>
        </div>
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>
        Top weighted opportunities — biggest probability-adjusted value
      </h2>
      <DataTable<TopRow> columns={topCols} rows={top} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>
        Full 12-month forecast — sorted by close month
      </h2>
      <DataTable<Commitment> columns={listCols} rows={list} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>
        Recent activity
      </h2>
      <DataTable<EventRow> columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />
    </div>
  );
}
