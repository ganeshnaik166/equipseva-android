import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

const CURRENT_QUARTER = '2026-Q3';

export default async function FounderOkrCascadeIntegrityPage() {
  const supabase = await getSupabaseServerClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return (
      <main style={{ padding: 24 }}>
        <h1>OKR Cascade Integrity</h1>
        <p>Sign in required.</p>
      </main>
    );
  }

  const [summaryRes, companyRes, orphansRes, misalignedRes, staleRes, findingsRes, teamRes] = await Promise.all([
    supabase.rpc('founder_okr_cascade_summary_r2345', { p_quarter: CURRENT_QUARTER }),
    supabase.rpc('founder_okr_company_rollup_r2345', { p_quarter: CURRENT_QUARTER }),
    supabase.rpc('founder_okr_orphans_r2345', { p_quarter: CURRENT_QUARTER }),
    supabase.rpc('founder_okr_misaligned_r2345', { p_quarter: CURRENT_QUARTER, p_threshold: 25 }),
    supabase.rpc('founder_okr_stale_checkins_r2345', { p_quarter: CURRENT_QUARTER, p_days: 14 }),
    supabase.rpc('founder_okr_open_findings_r2345', { p_quarter: CURRENT_QUARTER }),
    supabase.rpc('founder_okr_team_health_r2345', { p_quarter: CURRENT_QUARTER }),
  ]);

  const anyError = summaryRes.error || companyRes.error || orphansRes.error
    || misalignedRes.error || staleRes.error || findingsRes.error || teamRes.error;

  if (anyError) {
    return (
      <main style={{ padding: 24 }}>
        <h1>OKR Cascade Integrity</h1>
        <p style={{ color: 'crimson' }}>
          Founder access only. {anyError?.message ?? ''}
        </p>
      </main>
    );
  }

  const summary = (summaryRes.data ?? []) as Array<Record<string, unknown>>;
  const company = (companyRes.data ?? []) as Array<Record<string, unknown>>;
  const orphans = (orphansRes.data ?? []) as Array<Record<string, unknown>>;
  const misaligned = (misalignedRes.data ?? []) as Array<Record<string, unknown>>;
  const stale = (staleRes.data ?? []) as Array<Record<string, unknown>>;
  const findings = (findingsRes.data ?? []) as Array<Record<string, unknown>>;
  const teams = (teamRes.data ?? []) as Array<Record<string, unknown>>;

  const summaryCols: Column<any>[] = [
    { key: 'level', header: 'Level', render: (r) => String(r.level ?? '') },
    { key: 'okr_count', header: 'OKRs', render: (r) => String(r.okr_count ?? 0) },
    { key: 'avg_progress', header: 'Avg progress %', render: (r) => String(r.avg_progress ?? 0) },
    { key: 'avg_alignment', header: 'Avg alignment %', render: (r) => String(r.avg_alignment ?? 0) },
    { key: 'on_track_count', header: 'On track', render: (r) => String(r.on_track_count ?? 0) },
    { key: 'at_risk_count', header: 'At risk', render: (r) => String(r.at_risk_count ?? 0) },
    { key: 'off_track_count', header: 'Off track', render: (r) => String(r.off_track_count ?? 0) },
    { key: 'done_count', header: 'Done', render: (r) => String(r.done_count ?? 0) },
  ];

  const companyCols: Column<any>[] = [
    { key: 'objective', header: 'Company objective', render: (r) => String(r.objective ?? '') },
    { key: 'progress_pct', header: 'Progress %', render: (r) => String(r.progress_pct ?? 0) },
    { key: 'alignment_pct', header: 'Alignment %', render: (r) => String(r.alignment_pct ?? 0) },
    { key: 'confidence', header: 'Confidence', render: (r) => String(r.confidence ?? '') },
    { key: 'child_count', header: 'Children', render: (r) => String(r.child_count ?? 0) },
    { key: 'child_avg_progress', header: 'Child avg %', render: (r) => String(r.child_avg_progress ?? 0) },
    { key: 'rollup_drift', header: 'Drift', render: (r) => String(r.rollup_drift ?? 0) },
    { key: 'last_check_in_at', header: 'Last check-in', render: (r) => r.last_check_in_at ? new Date(String(r.last_check_in_at)).toLocaleDateString() : '—' },
  ];

  const orphanCols: Column<any>[] = [
    { key: 'level', header: 'Level', render: (r) => String(r.level ?? '') },
    { key: 'objective', header: 'Objective', render: (r) => String(r.objective ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r) => String(r.owner_email ?? '—') },
    { key: 'team_name', header: 'Team', render: (r) => String(r.team_name ?? '—') },
    { key: 'progress_pct', header: 'Progress %', render: (r) => String(r.progress_pct ?? 0) },
    { key: 'confidence', header: 'Confidence', render: (r) => String(r.confidence ?? '') },
  ];

  const misalignedCols: Column<any>[] = [
    { key: 'child_level', header: 'Child level', render: (r) => String(r.child_level ?? '') },
    { key: 'child_objective', header: 'Child objective', render: (r) => String(r.child_objective ?? '') },
    { key: 'child_progress', header: 'Child %', render: (r) => String(r.child_progress ?? 0) },
    { key: 'parent_objective', header: 'Parent objective', render: (r) => String(r.parent_objective ?? '') },
    { key: 'parent_progress', header: 'Parent %', render: (r) => String(r.parent_progress ?? 0) },
    { key: 'delta', header: 'Delta', render: (r) => String(r.delta ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r) => String(r.owner_email ?? '—') },
  ];

  const staleCols: Column<any>[] = [
    { key: 'level', header: 'Level', render: (r) => String(r.level ?? '') },
    { key: 'objective', header: 'Objective', render: (r) => String(r.objective ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r) => String(r.owner_email ?? '—') },
    { key: 'team_name', header: 'Team', render: (r) => String(r.team_name ?? '—') },
    { key: 'last_check_in_at', header: 'Last check-in', render: (r) => r.last_check_in_at ? new Date(String(r.last_check_in_at)).toLocaleDateString() : 'never' },
    { key: 'days_stale', header: 'Days stale', render: (r) => String(r.days_stale ?? 0) },
    { key: 'progress_pct', header: 'Progress %', render: (r) => String(r.progress_pct ?? 0) },
  ];

  const findingCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r) => String(r.severity ?? '') },
    { key: 'finding_type', header: 'Type', render: (r) => String(r.finding_type ?? '') },
    { key: 'okr_level', header: 'Level', render: (r) => String(r.okr_level ?? '—') },
    { key: 'okr_objective', header: 'Objective', render: (r) => String(r.okr_objective ?? '—') },
    { key: 'detail', header: 'Detail', render: (r) => String(r.detail ?? '') },
    { key: 'detected_at', header: 'Detected', render: (r) => r.detected_at ? new Date(String(r.detected_at)).toLocaleString() : '' },
  ];

  const teamCols: Column<any>[] = [
    { key: 'team_name', header: 'Team', render: (r) => String(r.team_name ?? '(unassigned)') },
    { key: 'team_okr_count', header: 'Team OKRs', render: (r) => String(r.team_okr_count ?? 0) },
    { key: 'individual_okr_count', header: 'Indiv OKRs', render: (r) => String(r.individual_okr_count ?? 0) },
    { key: 'avg_progress', header: 'Avg %', render: (r) => String(r.avg_progress ?? 0) },
    { key: 'off_track_count', header: 'Off track', render: (r) => String(r.off_track_count ?? 0) },
    { key: 'open_finding_count', header: 'Open findings', render: (r) => String(r.open_finding_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ margin: 0 }}>OKR Cascade Integrity</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Quarter {CURRENT_QUARTER} · company =&gt; team =&gt; individual rollups, orphan &amp; drift checks.
        </p>
      </header>

      <section>
        <h2>Cascade summary by level</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No OKRs defined for this quarter."
          rowKey={(r) => String(r.level)}
        />
      </section>

      <section>
        <h2>Company OKRs &amp; child rollup</h2>
        <DataTable
          rows={company}
          columns={companyCols}
          emptyMessage="No company-level OKRs."
          rowKey={(r) => String(r.okr_id)}
        />
      </section>

      <section>
        <h2>Orphan OKRs (no parent)</h2>
        <DataTable
          rows={orphans}
          columns={orphanCols}
          emptyMessage="All team/individual OKRs are linked to a parent."
          rowKey={(r) => String(r.okr_id)}
        />
      </section>

      <section>
        <h2>Misaligned children (parent - child &gt;= 25%)</h2>
        <DataTable
          rows={misaligned}
          columns={misalignedCols}
          emptyMessage="No misaligned children detected."
          rowKey={(r) => String(r.child_okr_id)}
        />
      </section>

      <section>
        <h2>Stale check-ins (&gt;= 14 days)</h2>
        <DataTable
          rows={stale}
          columns={staleCols}
          emptyMessage="All active OKRs have recent check-ins."
          rowKey={(r) => String(r.okr_id)}
        />
      </section>

      <section>
        <h2>Open integrity findings</h2>
        <DataTable
          rows={findings}
          columns={findingCols}
          emptyMessage="No open findings."
          rowKey={(r) => String(r.finding_id)}
        />
      </section>

      <section>
        <h2>Team health roster</h2>
        <DataTable
          rows={teams}
          columns={teamCols}
          emptyMessage="No team OKRs."
          rowKey={(r) => String(r.team_name)}
        />
      </section>
    </main>
  );
}
