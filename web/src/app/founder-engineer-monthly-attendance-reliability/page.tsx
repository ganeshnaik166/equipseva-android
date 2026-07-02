import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Attendance = {
  id: string;
  engineer_name: string;
  engineer_code: string;
  month_label: string;
  scheduled_jobs: number;
  completed_jobs: number;
  no_show_jobs: number;
  late_jobs: number;
  reliability_pct: number;
  reliability_tier: string;
  primary_reason: string;
  status: string;
};

type Consequence = {
  id: string;
  engineer_code: string;
  month_label: string;
  consequence_type: string;
  amount_rupees: number;
  notes: string;
  status: string;
  applied_at: string;
};

type Kpi = {
  total_engineers: number;
  total_scheduled: number;
  total_completed: number;
  total_no_shows: number;
  avg_reliability: number;
  watchlist_count: number;
};

type TierRow = { reliability_tier: string; engineer_count: number; avg_pct: number };
type ReasonRow = { primary_reason: string; occurrence_count: number };
type BonusRow = { consequence_type: string; count_rows: number; total_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [att, cons, kpi, tiers, reasons, bonus, watchlist] = await Promise.all([
    supabase.rpc('founder_attendance_list_r2678'),
    supabase.rpc('founder_attendance_consequences_r2678'),
    supabase.rpc('founder_attendance_kpis_r2678'),
    supabase.rpc('founder_attendance_tier_breakdown_r2678'),
    supabase.rpc('founder_attendance_reason_breakdown_r2678'),
    supabase.rpc('founder_attendance_bonus_total_r2678'),
    supabase.rpc('founder_attendance_watchlist_r2678'),
  ]);

  const attendance = (att.data ?? []) as Attendance[];
  const consequences = (cons.data ?? []) as Consequence[];
  const kpis = (Array.isArray(kpi.data) ? kpi.data[0] : kpi.data) as Kpi | undefined;
  const tierRows = (tiers.data ?? []) as TierRow[];
  const reasonRows = (reasons.data ?? []) as ReasonRow[];
  const bonusRows = (bonus.data ?? []) as BonusRow[];
  const watchRows = (watchlist.data ?? []) as Attendance[];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Engineer Monthly Attendance Reliability
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Engineer scheduled vs completed vs no-show with reason and consequence ledger. Watchlist engineers flagged at reliability under 80 percent.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Engineers" value={String(kpis?.total_engineers ?? 0)} />
        <KpiCard label="Scheduled" value={String(kpis?.total_scheduled ?? 0)} />
        <KpiCard label="Completed" value={String(kpis?.total_completed ?? 0)} />
        <KpiCard label="No-shows" value={String(kpis?.total_no_shows ?? 0)} />
        <KpiCard label="Avg Reliability %" value={String(kpis?.avg_reliability ?? 0)} />
        <KpiCard label="Watchlist" value={String(kpis?.watchlist_count ?? 0)} />
      </section>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>Monthly attendance</h2>
      <DataTable<Attendance>
        rows={attendance}
        columns={[
          { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
          { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
          { key: 'month_label', header: 'Month', render: (r) => r.month_label },
          { key: 'scheduled_jobs', header: 'Scheduled', render: (r) => String(r.scheduled_jobs) },
          { key: 'completed_jobs', header: 'Completed', render: (r) => String(r.completed_jobs) },
          { key: 'no_show_jobs', header: 'No-shows', render: (r) => String(r.no_show_jobs) },
          { key: 'reliability_pct', header: 'Reliability %', render: (r) => String(r.reliability_pct) },
          { key: 'reliability_tier', header: 'Tier', render: (r) => r.reliability_tier },
          { key: 'primary_reason', header: 'Reason', render: (r) => r.primary_reason },
          { key: 'status', header: 'Status', render: (r) => r.status },
        ]}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Tier breakdown</h2>
      <DataTable<TierRow>
        rows={tierRows}
        columns={[
          { key: 'reliability_tier', header: 'Tier', render: (r) => r.reliability_tier },
          { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count) },
          { key: 'avg_pct', header: 'Avg %', render: (r) => String(r.avg_pct) },
        ]}
        emptyMessage="No data"
        rowKey={(r, i) => String(i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Reason breakdown</h2>
      <DataTable<ReasonRow>
        rows={reasonRows}
        columns={[
          { key: 'primary_reason', header: 'Reason', render: (r) => r.primary_reason },
          { key: 'occurrence_count', header: 'Engineers', render: (r) => String(r.occurrence_count) },
        ]}
        emptyMessage="No data"
        rowKey={(r, i) => String(i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Consequence ledger</h2>
      <DataTable<Consequence>
        rows={consequences}
        columns={[
          { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
          { key: 'month_label', header: 'Month', render: (r) => r.month_label },
          { key: 'consequence_type', header: 'Type', render: (r) => r.consequence_type },
          { key: 'amount_rupees', header: 'Amount', render: (r) => String(r.amount_rupees) },
          { key: 'notes', header: 'Notes', render: (r) => r.notes },
          { key: 'status', header: 'Status', render: (r) => r.status },
        ]}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Consequence totals</h2>
      <DataTable<BonusRow>
        rows={bonusRows}
        columns={[
          { key: 'consequence_type', header: 'Type', render: (r) => r.consequence_type },
          { key: 'count_rows', header: 'Count', render: (r) => String(r.count_rows) },
          { key: 'total_rupees', header: 'Total rupees', render: (r) => String(r.total_rupees) },
        ]}
        emptyMessage="No data"
        rowKey={(r, i) => String(i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Watchlist</h2>
      <DataTable<Attendance>
        rows={watchRows}
        columns={[
          { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
          { key: 'reliability_pct', header: 'Reliability %', render: (r) => String(r.reliability_pct) },
          { key: 'no_show_jobs', header: 'No-shows', render: (r) => String(r.no_show_jobs) },
          { key: 'primary_reason', header: 'Reason', render: (r) => r.primary_reason },
          { key: 'status', header: 'Status', render: (r) => r.status },
        ]}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.id ?? i)}
      />
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
