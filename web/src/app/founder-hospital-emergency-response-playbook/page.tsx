import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PlaybookRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  playbook_label: string;
  scenario_text: string | null;
  primary_contact_email: string | null;
  escalation_chain: string[] | null;
  response_minutes: number;
  status: string;
  last_drilled_at: string | null;
  drill_count: number;
  created_at: string;
};

type DrillRow = {
  id: string;
  playbook_id: string;
  playbook_label: string;
  hospital_email: string | null;
  drilled_at: string;
  drilled_by_email: string | null;
  scenario_run: string | null;
  response_time_actual_min: number | null;
  target_response_minutes: number | null;
  gaps_md: string | null;
  status: string;
};

type StaleRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  playbook_label: string;
  status: string;
  response_minutes: number;
  last_drilled_at: string | null;
  days_since_drill: number | null;
  created_at: string;
};

type PassRateRow = {
  total_drills: number;
  passed_count: number;
  needs_improvement_count: number;
  failed_count: number;
  pass_rate_pct: number;
  avg_response_time_min: number;
  total_playbooks: number;
  active_playbooks: number;
  under_review_playbooks: number;
  archived_playbooks: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [playbooksRes, drillsRes, staleRes, passRateRes] = await Promise.all([
    sb.rpc('r1867_list_playbooks'),
    sb.rpc('r1867_list_drills'),
    sb.rpc('r1867_stale_playbooks', { p_days: 90 }),
    sb.rpc('r1867_drill_pass_rate'),
  ]);

  const playbooks: PlaybookRow[] = (playbooksRes.data as PlaybookRow[] | null) ?? [];
  const drills: DrillRow[] = (drillsRes.data as DrillRow[] | null) ?? [];
  const stale: StaleRow[] = (staleRes.data as StaleRow[] | null) ?? [];
  const passRateRows: PassRateRow[] = (passRateRes.data as PassRateRow[] | null) ?? [];
  const summary: PassRateRow | null = passRateRows.length > 0 ? passRateRows[0] : null;

  const playbookCols: Column<PlaybookRow>[] = [
    { key: 'playbook_label', header: 'Playbook', render: (r: any) => r.playbook_label },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? String(r.hospital_user_id).slice(0, 8) },
    { key: 'primary_contact_email', header: 'Primary contact', render: (r: any) => r.primary_contact_email ?? '—' },
    { key: 'response_minutes', header: 'Target (min)', render: (r: any) => r.response_minutes },
    { key: 'escalation_chain', header: 'Escalation', render: (r: any) => Array.isArray(r.escalation_chain) ? r.escalation_chain.join(' → ') : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_drilled_at', header: 'Last drilled', render: (r: any) => r.last_drilled_at ? new Date(r.last_drilled_at).toLocaleString() : '—' },
    { key: 'drill_count', header: 'Drills', render: (r: any) => r.drill_count },
  ];

  const drillCols: Column<DrillRow>[] = [
    { key: 'playbook_label', header: 'Playbook', render: (r: any) => r.playbook_label },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'drilled_at', header: 'Drilled at', render: (r: any) => r.drilled_at ? new Date(r.drilled_at).toLocaleString() : '—' },
    { key: 'drilled_by_email', header: 'Drilled by', render: (r: any) => r.drilled_by_email ?? '—' },
    { key: 'response_time_actual_min', header: 'Actual (min)', render: (r: any) => r.response_time_actual_min ?? '—' },
    { key: 'target_response_minutes', header: 'Target (min)', render: (r: any) => r.target_response_minutes ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'gaps_md', header: 'Gaps', render: (r: any) => r.gaps_md ? String(r.gaps_md).slice(0, 80) : '—' },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: 'playbook_label', header: 'Playbook', render: (r: any) => r.playbook_label },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? String(r.hospital_user_id).slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'response_minutes', header: 'Target (min)', render: (r: any) => r.response_minutes },
    { key: 'last_drilled_at', header: 'Last drilled', render: (r: any) => r.last_drilled_at ? new Date(r.last_drilled_at).toLocaleString() : 'Never' },
    { key: 'days_since_drill', header: 'Days since', render: (r: any) => r.days_since_drill ?? '∞' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Emergency Response Playbook</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-hospital emergency response playbooks for critical equipment-down scenarios. Track playbook coverage, drill cadence, and response-time performance.
      </p>

      {summary && (
        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Drill pass-rate summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total drills</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_drills}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Passed</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#16a34a' }}>{summary.passed_count}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Needs improvement</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#ca8a04' }}>{summary.needs_improvement_count}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Failed</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>{summary.failed_count}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Pass rate</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.pass_rate_pct}%</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Avg response (min)</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.avg_response_time_min}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total playbooks</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_playbooks}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 6, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Active / Review / Archived</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>
                {summary.active_playbooks} / {summary.under_review_playbooks} / {summary.archived_playbooks}
              </div>
            </div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All playbooks ({playbooks.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Hospital-specific emergency response playbooks. Status ∈ active / under_review / archived.
        </p>
        <DataTable
          rows={playbooks}
          columns={playbookCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stale playbooks ({stale.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Active or under-review playbooks not drilled in &gt; 90 days (or never drilled). Schedule a drill to refresh readiness.
        </p>
        <DataTable
          rows={stale}
          columns={staleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Drill history ({drills.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Each row is one logged drill. Actual response-time compared vs target. Flagged when actual &gt; target.
        </p>
        <DataTable
          rows={drills}
          columns={drillCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
