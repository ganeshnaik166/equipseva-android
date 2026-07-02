import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [snapsRes, trendRes, topRes, founderTrendRes] = await Promise.all([
    sb.rpc('list_quarterly_snapshots_r1685'),
    sb.rpc('dilution_trend_r1685'),
    sb.rpc('top_shareholders_latest_r1685'),
    sb.rpc('founder_dilution_trend_r1685'),
  ]);

  const snaps: any[] = Array.isArray(snapsRes.data) ? snapsRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const founderTrend: any[] = Array.isArray(founderTrendRes.data) ? founderTrendRes.data : [];

  const totalSnaps = snaps.length;
  const latest = snaps[0];
  const latestFounderPct = latest ? Number(latest.fully_diluted_pct_founder) : 0;
  const latestInvestorPct = latest ? Number(latest.fully_diluted_pct_investors) : 0;

  const snapsColumns: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter },
    { key: 'snapshot_taken_at', header: 'Taken', render: (r: any) => r.snapshot_taken_at ? new Date(r.snapshot_taken_at).toLocaleDateString() : '—' },
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => Number(r.total_shares).toLocaleString() },
    { key: 'total_diluted', header: 'Diluted', render: (r: any) => Number(r.total_diluted).toLocaleString() },
    { key: 'fully_diluted_pct_founder', header: 'Founder %', render: (r: any) => `${Number(r.fully_diluted_pct_founder).toFixed(2)}%` },
    { key: 'fully_diluted_pct_employees', header: 'Emp %', render: (r: any) => `${Number(r.fully_diluted_pct_employees).toFixed(2)}%` },
    { key: 'fully_diluted_pct_investors', header: 'Inv %', render: (r: any) => `${Number(r.fully_diluted_pct_investors).toFixed(2)}%` },
  ];

  const topColumns: Column<any>[] = [
    { key: 'shareholder_name', header: 'Shareholder', render: (r: any) => r.shareholder_name },
    { key: 'shareholder_type', header: 'Type', render: (r: any) => r.shareholder_type },
    { key: 'shares', header: 'Shares', render: (r: any) => Number(r.shares).toLocaleString() },
    { key: 'pct', header: 'Fully Diluted %', render: (r: any) => `${Number(r.pct).toFixed(2)}%` },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter },
    { key: 'snapshot_taken_at', header: 'Taken', render: (r: any) => r.snapshot_taken_at ? new Date(r.snapshot_taken_at).toLocaleDateString() : '—' },
    { key: 'pct_founder', header: 'Founder %', render: (r: any) => `${Number(r.pct_founder).toFixed(2)}%` },
    { key: 'delta_pct', header: 'Δ vs Prior', render: (r: any) => r.delta_pct == null ? '—' : `${Number(r.delta_pct).toFixed(2)}pp` },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Quarterly Cap Table Snapshots</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Round 1685 — quarterly snapshots for investor reporting & dilution tracking.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Snapshots Taken</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalSnaps}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Latest Quarter</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{latest?.quarter ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Founder Diluted %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{latestFounderPct.toFixed(2)}%</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Investor Diluted %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{latestInvestorPct.toFixed(2)}%</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarterly Snapshots</h2>
        <DataTable rows={snaps} columns={snapsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Shareholders (Latest Snapshot)</h2>
        <DataTable rows={top} columns={topColumns} rowKey={(r: any, i: number) => String(r.shareholder_name ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Founder Dilution Trend (Action Queue if &gt;5pp Drop)</h2>
        <DataTable rows={founderTrend} columns={trendColumns} rowKey={(r: any, i: number) => String(r.quarter ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Dilution Trend (All Stakeholders)</h2>
        <DataTable
          rows={trend}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter },
            { key: 'pct_founder', header: 'Founder %', render: (r: any) => `${Number(r.pct_founder).toFixed(2)}%` },
            { key: 'pct_employees', header: 'Emp %', render: (r: any) => `${Number(r.pct_employees).toFixed(2)}%` },
            { key: 'pct_investors', header: 'Inv %', render: (r: any) => `${Number(r.pct_investors).toFixed(2)}%` },
          ]}
          rowKey={(r: any, i: number) => String(r.quarter ?? i)}
        />
      </section>
    </main>
  );
}
