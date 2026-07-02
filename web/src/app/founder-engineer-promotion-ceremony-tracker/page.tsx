import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerPromotionCeremonyTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    ceremoniesRes,
    outcomesRes,
    celebrationRes,
    kindRes,
    retentionRes,
    monthlyRes,
    bonusRes,
  ] = await Promise.all([
    supabase.rpc('list_ceremonies_r2546'),
    supabase.rpc('list_followup_outcomes_r2546'),
    supabase.rpc('top_celebration_count_r2546'),
    supabase.rpc('ceremony_kind_breakdown_r2546'),
    supabase.rpc('retention_correlation_r2546'),
    supabase.rpc('monthly_ceremony_trend_r2546'),
    supabase.rpc('total_bonus_summary_r2546'),
  ]);

  const ceremonies = (ceremoniesRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const celebration = (celebrationRes.data ?? []) as any[];
  const kindBreak = (kindRes.data ?? []) as any[];
  const retention = (retentionRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];
  const bonusSum = (bonusRes.data ?? []) as any[];

  const ceremonyCols: Column<any>[] = [
    { key: 'promoted_at', header: 'Promoted At', render: (r: any) => r.promoted_at ? new Date(r.promoted_at).toLocaleDateString() : '-' },
    { key: 'from_tier', header: 'From', render: (r: any) => r.from_tier },
    { key: 'to_tier', header: 'To', render: (r: any) => r.to_tier },
    { key: 'ceremony_kind', header: 'Ceremony', render: (r: any) => r.ceremony_kind },
    { key: 'bonus_rupees', header: 'Bonus', render: (r: any) => `Rs ${r.bonus_rupees.toLocaleString()}` },
    { key: 'team_celebration', header: 'Team Celebration', render: (r: any) => r.team_celebration ? 'yes' : 'no' },
    { key: 'engineer_pride_score', header: 'Pride', render: (r: any) => `${r.engineer_pride_score}/10` },
    { key: 'retention_boost_expected_months', header: 'Retention Boost (mo)', render: (r: any) => r.retention_boost_expected_months },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'ceremony_id', header: 'Ceremony', render: (r: any) => String(r.ceremony_id).slice(0, 8) },
    { key: 'observed_at', header: 'Observed', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleDateString() : '-' },
    { key: 'retention_status', header: 'Retention', render: (r: any) => r.retention_status },
    { key: 'nps_lift_delta', header: 'NPS Lift', render: (r: any) => `+${r.nps_lift_delta}` },
    { key: 'performance_lift_pct', header: 'Perf Lift %', render: (r: any) => `${r.performance_lift_pct}%` },
    { key: 'lessons_md', header: 'Lessons', render: (r: any) => r.lessons_md ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const celebrationCols: Column<any>[] = [
    { key: 'team_celebration', header: 'Team Celebration', render: (r: any) => r.team_celebration ? 'yes' : 'no' },
    { key: 'ceremonies_count', header: 'Count', render: (r: any) => r.ceremonies_count },
    { key: 'avg_pride', header: 'Avg Pride', render: (r: any) => `${r.avg_pride}/10` },
    { key: 'avg_retention_boost', header: 'Avg Retention Boost (mo)', render: (r: any) => r.avg_retention_boost },
  ];

  const kindCols: Column<any>[] = [
    { key: 'ceremony_kind', header: 'Ceremony Kind', render: (r: any) => r.ceremony_kind },
    { key: 'ceremonies_count', header: 'Count', render: (r: any) => r.ceremonies_count },
    { key: 'avg_bonus_rupees', header: 'Avg Bonus', render: (r: any) => `Rs ${Number(r.avg_bonus_rupees).toLocaleString()}` },
    { key: 'avg_pride', header: 'Avg Pride', render: (r: any) => `${r.avg_pride}/10` },
  ];

  const retentionCols: Column<any>[] = [
    { key: 'retention_status', header: 'Retention Status', render: (r: any) => r.retention_status },
    { key: 'outcomes_count', header: 'Count', render: (r: any) => r.outcomes_count },
    { key: 'avg_nps_lift', header: 'Avg NPS Lift', render: (r: any) => `+${r.avg_nps_lift}` },
    { key: 'avg_perf_lift_pct', header: 'Avg Perf Lift %', render: (r: any) => `${r.avg_perf_lift_pct}%` },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => r.month_bucket },
    { key: 'ceremonies_count', header: 'Count', render: (r: any) => r.ceremonies_count },
    { key: 'total_bonus_rupees', header: 'Total Bonus', render: (r: any) => `Rs ${Number(r.total_bonus_rupees).toLocaleString()}` },
    { key: 'avg_pride', header: 'Avg Pride', render: (r: any) => `${r.avg_pride}/10` },
  ];

  const bonusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'ceremonies_count', header: 'Count', render: (r: any) => r.ceremonies_count },
    { key: 'total_bonus_rupees', header: 'Total Bonus', render: (r: any) => `Rs ${Number(r.total_bonus_rupees).toLocaleString()}` },
    { key: 'avg_retention_boost', header: 'Avg Retention Boost (mo)', render: (r: any) => r.avg_retention_boost },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', marginBottom: '8px' }}>Engineer Promotion Ceremony Tracker</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Promotion => ceremony => bonus => team celebration => engineer pride => retention boost. Round r2546.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Ceremonies</h2>
        <DataTable
          rows={ceremonies}
          columns={ceremonyCols}
          emptyMessage="No ceremonies recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Followup Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No followup outcomes yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Team Celebration Lift</h2>
        <DataTable
          rows={celebration}
          columns={celebrationCols}
          emptyMessage="No celebration data."
          rowKey={(r: any, i: number) => String(r.team_celebration ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Ceremony Kind Breakdown</h2>
        <DataTable
          rows={kindBreak}
          columns={kindCols}
          emptyMessage="No kind breakdown."
          rowKey={(r: any, i: number) => String(r.ceremony_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Retention Correlation</h2>
        <DataTable
          rows={retention}
          columns={retentionCols}
          emptyMessage="No retention data."
          rowKey={(r: any, i: number) => String(r.retention_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Monthly Ceremony Trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly trend."
          rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', marginBottom: '12px' }}>Total Bonus Summary</h2>
        <DataTable
          rows={bonusSum}
          columns={bonusCols}
          emptyMessage="No bonus summary."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </main>
  );
}
