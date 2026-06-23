import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerNpsFollowupConversionPage() {
  const supabase = await getSupabaseServerClient();
  const email = (await supabase.auth.getUser()).data.user?.email ?? null;

  const [summary, byIntervention, recent, winners, scoreLift, pending, playbook] = await Promise.all([
    supabase.rpc('npsfu_r2340_summary'),
    supabase.rpc('npsfu_r2340_by_intervention'),
    supabase.rpc('npsfu_r2340_recent'),
    supabase.rpc('npsfu_r2340_winners'),
    supabase.rpc('npsfu_r2340_score_lift'),
    supabase.rpc('npsfu_r2340_pending'),
    supabase.rpc('npsfu_r2340_playbook'),
  ]);

  const s = summary.data?.[0] ?? null;

  const summaryCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric },
    { key: 'value', header: 'Value', render: (r: any) => r.value },
  ];

  const summaryRows = s
    ? [
        { metric: 'Total detractors', value: s.total_detractors },
        { metric: 'Intervened', value: s.intervened },
        { metric: 'Follow-up done', value: s.followup_done },
        { metric: 'Converted to promoter', value: s.converted },
        { metric: 'Conversion rate %', value: s.conversion_rate },
        { metric: 'Avg days to follow-up', value: s.avg_days_to_followup ?? '—' },
        { metric: 'Total spend (Rs)', value: s.total_cost_rupees },
      ]
    : [];

  const byInterventionCols: Column<any>[] = [
    { key: 'playbook_label', header: 'Intervention', render: (r: any) => r.playbook_label },
    { key: 'attempts', header: 'Attempts', render: (r: any) => r.attempts },
    { key: 'converted', header: 'Converted', render: (r: any) => r.converted },
    { key: 'conversion_rate', header: 'Conv %', render: (r: any) => r.conversion_rate },
    { key: 'avg_cost_rupees', header: 'Avg cost (Rs)', render: (r: any) => r.avg_cost_rupees },
    { key: 'avg_days_to_followup', header: 'Avg days', render: (r: any) => r.avg_days_to_followup ?? '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email ?? '—' },
    { key: 'initial_score', header: 'Initial', render: (r: any) => r.initial_score },
    { key: 'followup_score', header: 'Follow-up', render: (r: any) => r.followup_score ?? '—' },
    { key: 'intervention_type', header: 'Intervention', render: (r: any) => r.intervention_type },
    { key: 'intervention_owner_email', header: 'Owner', render: (r: any) => r.intervention_owner_email ?? '—' },
    { key: 'converted_to_promoter', header: 'Converted', render: (r: any) => (r.converted_to_promoter ? 'yes' : 'no') },
    { key: 'days_to_followup', header: 'Days', render: (r: any) => r.days_to_followup ?? '—' },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r: any) => r.cost_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const winnersCols: Column<any>[] = [
    { key: 'playbook_label', header: 'Top intervention', render: (r: any) => r.playbook_label },
    { key: 'converted', header: 'Wins', render: (r: any) => r.converted },
    { key: 'conversion_rate', header: 'Conv %', render: (r: any) => r.conversion_rate },
    { key: 'cost_per_conversion', header: 'Cost / conversion (Rs)', render: (r: any) => r.cost_per_conversion },
  ];

  const scoreLiftCols: Column<any>[] = [
    { key: 'bucket', header: 'Initial bucket', render: (r: any) => r.bucket },
    { key: 'cases', header: 'Cases', render: (r: any) => r.cases },
    { key: 'avg_initial', header: 'Avg initial', render: (r: any) => r.avg_initial },
    { key: 'avg_followup', header: 'Avg follow-up', render: (r: any) => r.avg_followup ?? '—' },
    { key: 'avg_lift', header: 'Avg lift', render: (r: any) => r.avg_lift ?? '—' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email ?? '—' },
    { key: 'initial_score', header: 'Score', render: (r: any) => r.initial_score },
    { key: 'initial_reason', header: 'Reason', render: (r: any) => r.initial_reason ?? '—' },
    { key: 'initial_survey_at', header: 'Surveyed', render: (r: any) => new Date(r.initial_survey_at).toLocaleDateString() },
    { key: 'days_open', header: 'Days open', render: (r: any) => r.days_open },
  ];

  const playbookCols: Column<any>[] = [
    { key: 'playbook_label', header: 'Playbook', render: (r: any) => r.playbook_label },
    { key: 'description', header: 'Description', render: (r: any) => r.description ?? '—' },
    { key: 'recommended_sla_hours', header: 'SLA (h)', render: (r: any) => r.recommended_sla_hours },
    { key: 'avg_cost_rupees', header: 'Avg cost (Rs)', render: (r: any) => r.avg_cost_rupees },
    { key: 'is_active', header: 'Active', render: (r: any) => (r.is_active ? 'yes' : 'no') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Customer NPS follow-up conversion</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Detractors who became promoters after intervention. What worked & conversion rate. Signed in as {email ?? '—'}.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Summary</h2>
        <DataTable rows={summaryRows} emptyMessage="No data yet" rowKey={(r: any) => r.metric} columns={summaryCols} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By intervention type</h2>
        <DataTable
          rows={byIntervention.data ?? []}
          emptyMessage="No interventions yet"
          rowKey={(r: any) => r.intervention_type}
          columns={byInterventionCols}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top 5 winners (highest conversion rate)</h2>
        <DataTable
          rows={winners.data ?? []}
          emptyMessage="No conversions yet"
          rowKey={(r: any) => r.intervention_type}
          columns={winnersCols}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Score lift by detractor bucket</h2>
        <DataTable
          rows={scoreLift.data ?? []}
          emptyMessage="No score data yet"
          rowKey={(r: any) => r.bucket}
          columns={scoreLiftCols}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending detractors (awaiting intervention)</h2>
        <DataTable
          rows={pending.data ?? []}
          emptyMessage="No pending detractors"
          rowKey={(r: any) => r.id}
          columns={pendingCols}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent cases</h2>
        <DataTable
          rows={recent.data ?? []}
          emptyMessage="No cases yet"
          rowKey={(r: any) => r.id}
          columns={recentCols}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Intervention playbook</h2>
        <DataTable
          rows={playbook.data ?? []}
          emptyMessage="No playbook entries"
          rowKey={(r: any) => r.intervention_type}
          columns={playbookCols}
        />
      </section>
    </main>
  );
}
