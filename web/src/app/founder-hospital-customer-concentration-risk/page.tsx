import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Snapshot = {
  id: string;
  snapshot_date: string;
  top_1_revenue_pct: number;
  top_3_revenue_pct: number;
  top_5_revenue_pct: number;
  top_10_revenue_pct: number;
  total_arr_rupees: number;
  status: string;
  created_at: string;
};

type AtRisk = {
  hospital_user_id: string;
  hospital_email: string | null;
  arr_pct: number;
  revenue_share_class: string;
};

type Trend = {
  snapshot_date: string;
  top_5_revenue_pct: number;
  total_arr_rupees: number;
};

type Summary = {
  total_snapshots: number;
  current_top_1: number;
  current_top_5: number;
  current_top_10: number;
  current_arr_rupees: number;
  critical_count: number;
  high_count: number;
  medium_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [snapsRes, topRes, trendRes, sumRes] = await Promise.all([
    sb.rpc('list_snapshots_r1847'),
    sb.rpc('top_concentrated_r1847'),
    sb.rpc('trend_top_5_r1847'),
    sb.rpc('risk_summary_r1847'),
  ]);

  const snapshots: Snapshot[] = (snapsRes.data ?? []) as Snapshot[];
  const topRisks: AtRisk[] = (topRes.data ?? []) as AtRisk[];
  const trend: Trend[] = (trendRes.data ?? []) as Trend[];
  const summary: Summary | null = ((sumRes.data ?? [])[0] ?? null) as Summary | null;

  const snapshotCols: Column<Snapshot>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'top_1_revenue_pct', header: 'Top 1 %', render: (r: any) => `${Number(r.top_1_revenue_pct ?? 0).toFixed(2)}%` },
    { key: 'top_3_revenue_pct', header: 'Top 3 %', render: (r: any) => `${Number(r.top_3_revenue_pct ?? 0).toFixed(2)}%` },
    { key: 'top_5_revenue_pct', header: 'Top 5 %', render: (r: any) => `${Number(r.top_5_revenue_pct ?? 0).toFixed(2)}%` },
    { key: 'top_10_revenue_pct', header: 'Top 10 %', render: (r: any) => `${Number(r.top_10_revenue_pct ?? 0).toFixed(2)}%` },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => `₹${Number(r.total_arr_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const topCols: Column<AtRisk>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '') },
    { key: 'arr_pct', header: 'ARR Share', render: (r: any) => `${Number(r.arr_pct ?? 0).toFixed(2)}%` },
    { key: 'revenue_share_class', header: 'Class', render: (r: any) => String(r.revenue_share_class ?? '') },
  ];

  const trendCols: Column<Trend>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'top_5_revenue_pct', header: 'Top 5 %', render: (r: any) => `${Number(r.top_5_revenue_pct ?? 0).toFixed(2)}%` },
    { key: 'total_arr_rupees', header: 'ARR', render: (r: any) => `₹${Number(r.total_arr_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Customer Concentration Risk
      </h1>
      <p style={{ color: '#555', marginBottom: 24, fontSize: 14 }}>
        Track top-N customer concentration — revenue at risk if a top hospital leaves. Watch top-5 &gt; 50% as critical signal.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Current Snapshot Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12 }}>
          <Stat label="Snapshots" value={String(summary?.total_snapshots ?? 0)} />
          <Stat label="Top 1 %" value={`${Number(summary?.current_top_1 ?? 0).toFixed(2)}%`} />
          <Stat label="Top 5 %" value={`${Number(summary?.current_top_5 ?? 0).toFixed(2)}%`} />
          <Stat label="Top 10 %" value={`${Number(summary?.current_top_10 ?? 0).toFixed(2)}%`} />
          <Stat label="ARR" value={`₹${Number(summary?.current_arr_rupees ?? 0).toLocaleString('en-IN')}`} />
          <Stat label="Critical" value={String(summary?.critical_count ?? 0)} />
          <Stat label="High" value={String(summary?.high_count ?? 0)} />
          <Stat label="Medium" value={String(summary?.medium_count ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Concentrated Hospitals (current)</h2>
        <DataTable
          rows={topRisks}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top-5 Trend (last 24 snapshots)</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          rowKey={(r: any, i: number) => String(r.snapshot_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Snapshot History</h2>
        <DataTable
          rows={snapshots}
          columns={snapshotCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
