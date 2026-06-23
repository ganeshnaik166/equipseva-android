import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerRapportQualityPage() {
  const supabase = await getSupabaseServerClient();

  const [
    rapportRes,
    actionsRes,
    topEngineersRes,
    actionKindSummaryRes,
    statusDistRes,
    monthlyTrendRes,
    topHospitalsRes,
  ] = await Promise.all([
    supabase.rpc('list_rapport_r2542'),
    supabase.rpc('list_growth_actions_r2542'),
    supabase.rpc('top_rapport_engineers_r2542'),
    supabase.rpc('action_kind_summary_r2542'),
    supabase.rpc('status_distribution_r2542'),
    supabase.rpc('monthly_rapport_trend_r2542'),
    supabase.rpc('top_hospitals_by_rapport_r2542'),
  ]);

  const rapportRows = (rapportRes.data as any[]) ?? [];
  const actionRows = (actionsRes.data as any[]) ?? [];
  const topEngineerRows = (topEngineersRes.data as any[]) ?? [];
  const actionKindRows = (actionKindSummaryRes.data as any[]) ?? [];
  const statusDistRows = (statusDistRes.data as any[]) ?? [];
  const monthlyRows = (monthlyTrendRes.data as any[]) ?? [];
  const topHospitalRows = (topHospitalsRes.data as any[]) ?? [];

  const rapportCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'rapport_score', header: 'Score', render: (r: any) => String(r.rapport_score ?? '') },
    { key: 'first_name_basis', header: 'First-name', render: (r: any) => r.first_name_basis ? 'yes' : 'no' },
    { key: 'empathy_moments_count', header: 'Empathy moments', render: (r: any) => String(r.empathy_moments_count ?? 0) },
    { key: 'repeat_customer_rate_pct', header: 'Repeat %', render: (r: any) => String(r.repeat_customer_rate_pct ?? 0) },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => r.last_touch_at ? String(r.last_touch_at).slice(0, 10) : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'rapport_id', header: 'Rapport', render: (r: any) => String(r.rapport_id ?? '').slice(0, 8) },
    { key: 'action_at', header: 'Action at', render: (r: any) => r.action_at ? String(r.action_at).slice(0, 16).replace('T', ' ') : '' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const topEngineerCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospitals_covered', header: 'Hospitals', render: (r: any) => String(r.hospitals_covered ?? 0) },
    { key: 'avg_rapport_score', header: 'Avg score', render: (r: any) => String(r.avg_rapport_score ?? 0) },
    { key: 'total_empathy_moments', header: 'Empathy total', render: (r: any) => String(r.total_empathy_moments ?? 0) },
    { key: 'avg_repeat_rate_pct', header: 'Avg repeat %', render: (r: any) => String(r.avg_repeat_rate_pct ?? 0) },
    { key: 'champion_count', header: 'Champion pairs', render: (r: any) => String(r.champion_count ?? 0) },
  ];

  const actionKindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Kind', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'total_actions', header: 'Total', render: (r: any) => String(r.total_actions ?? 0) },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => String(r.positive_outcomes ?? 0) },
    { key: 'pending_actions', header: 'Pending', render: (r: any) => String(r.pending_actions ?? 0) },
    { key: 'positive_rate_pct', header: 'Positive %', render: (r: any) => String(r.positive_rate_pct ?? 0) },
  ];

  const statusDistCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'rapport_count', header: 'Pairs', render: (r: any) => String(r.rapport_count ?? 0) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => String(r.avg_score ?? 0) },
    { key: 'pct_of_total', header: '% of total', render: (r: any) => String(r.pct_of_total ?? 0) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '') },
    { key: 'rapport_added', header: 'Rapport added', render: (r: any) => String(r.rapport_added ?? 0) },
    { key: 'actions_taken', header: 'Actions taken', render: (r: any) => String(r.actions_taken ?? 0) },
    { key: 'positive_actions', header: 'Positive', render: (r: any) => String(r.positive_actions ?? 0) },
  ];

  const topHospitalCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'engineers_assigned', header: 'Engineers', render: (r: any) => String(r.engineers_assigned ?? 0) },
    { key: 'avg_rapport_score', header: 'Avg score', render: (r: any) => String(r.avg_rapport_score ?? 0) },
    { key: 'avg_repeat_rate_pct', header: 'Avg repeat %', render: (r: any) => String(r.avg_repeat_rate_pct ?? 0) },
    { key: 'first_name_basis_count', header: 'First-name pairs', render: (r: any) => String(r.first_name_basis_count ?? 0) },
    { key: 'total_empathy_moments', header: 'Empathy total', render: (r: any) => String(r.total_empathy_moments ?? 0) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer & Customer Rapport Quality</h1>
      <p style={{ color: '#666', marginBottom: 24, fontSize: 14 }}>
        Per-engineer × hospital rapport scores. Small-talk topics, first-name basis, empathy moments & repeat-customer rate => long-term stickiness.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Rapport pairs</h2>
        <DataTable
          rows={rapportRows}
          columns={rapportCols}
          emptyMessage="No rapport pairs yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Growth actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No growth actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top rapport engineers</h2>
        <DataTable
          rows={topEngineerRows}
          columns={topEngineerCols}
          emptyMessage="No engineer rollup"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Action kind summary</h2>
        <DataTable
          rows={actionKindRows}
          columns={actionKindCols}
          emptyMessage="No action summary"
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status distribution</h2>
        <DataTable
          rows={statusDistRows}
          columns={statusDistCols}
          emptyMessage="No status distribution"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly rapport trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly trend"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top hospitals by rapport</h2>
        <DataTable
          rows={topHospitalRows}
          columns={topHospitalCols}
          emptyMessage="No hospital rollup"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>
    </div>
  );
}
