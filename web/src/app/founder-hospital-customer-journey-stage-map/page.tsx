import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type StageRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  journey_stage: string;
  stage_entered_at: string;
  time_in_stage_days: number;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  hospital_name: string | null;
  journey_stage: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

type StalledRow = {
  id: string;
  hospital_name: string | null;
  journey_stage: string;
  time_in_stage_days: number;
  status: string;
  captured_at: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [stagesRes, actionsRes, stalledRes] = await Promise.all([
    sb.rpc('list_journey_stages_r2031'),
    sb.rpc('recent_journey_actions_r2031'),
    sb.rpc('stalled_journeys_r2031'),
  ]);

  const stages: StageRow[] = (stagesRes.data as StageRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const stalled: StalledRow[] = (stalledRes.data as StalledRow[]) ?? [];

  const stageCols: Column<StageRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'journey_stage', header: 'Stage', render: (r: any) => r.journey_stage },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'time_in_stage_days', header: 'Days in stage', render: (r: any) => String(r.time_in_stage_days ?? 0) },
    { key: 'stage_entered_at', header: 'Entered', render: (r: any) => r.stage_entered_at ? new Date(r.stage_entered_at).toLocaleDateString() : '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'journey_stage', header: 'Stage', render: (r: any) => r.journey_stage },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
  ];

  const stalledCols: Column<StalledRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'journey_stage', header: 'Stage', render: (r: any) => r.journey_stage },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'time_in_stage_days', header: 'Days stuck', render: (r: any) => String(r.time_in_stage_days ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Customer Journey Stage Map</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track hospital accounts across awareness, trial, active use, expansion, at-risk and churn stages.
        Log nurture, training, upsell, retention and win-back actions per stage.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Journey stages</h2>
        <DataTable rows={stages} columns={stageCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Stalled and regressed journeys</h2>
        <DataTable rows={stalled} columns={stalledCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions (last 30 days)</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
