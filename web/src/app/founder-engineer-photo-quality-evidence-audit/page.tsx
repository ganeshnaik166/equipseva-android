import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerPhotoQualityEvidenceAuditPage() {
  const supabase = await getSupabaseServerClient();

  const [
    auditsRes,
    sessionsRes,
    lowQualityRes,
    topCoachingRes,
    weeklyTrendRes,
    gradeSummaryRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_audits_r2494'),
    supabase.rpc('list_coaching_sessions_r2494'),
    supabase.rpc('low_quality_audits_r2494'),
    supabase.rpc('top_coaching_engineers_r2494'),
    supabase.rpc('weekly_completeness_trend_r2494'),
    supabase.rpc('insurance_grade_summary_r2494'),
    supabase.rpc('owner_load_r2494'),
  ]);

  const audits: any[] = auditsRes.data ?? [];
  const sessions: any[] = sessionsRes.data ?? [];
  const lowQuality: any[] = lowQualityRes.data ?? [];
  const topCoaching: any[] = topCoachingRes.data ?? [];
  const weeklyTrend: any[] = weeklyTrendRes.data ?? [];
  const gradeSummary: any[] = gradeSummaryRes.data ?? [];
  const ownerLoad: any[] = ownerLoadRes.data ?? [];

  const auditCols: Column<any>[] = [
    { key: 'job_external_ref', header: 'Job Ref', render: (r: any) => r.job_external_ref },
    { key: 'audit_date', header: 'Audit Date', render: (r: any) => r.audit_date },
    { key: 'engineer_tier', header: 'Tier', render: (r: any) => r.engineer_tier ?? '-' },
    {
      key: 'photos',
      header: 'Photos',
      render: (r: any) => `${r.total_photos}/${r.required_photo_count}`,
    },
    { key: 'photo_quality_score', header: 'Quality', render: (r: any) => `${r.photo_quality_score}` },
    {
      key: 'evidence_completeness_pct',
      header: 'Complete %',
      render: (r: any) => `${r.evidence_completeness_pct}%`,
    },
    { key: 'insurance_legal_grade', header: 'Ins/Legal', render: (r: any) => r.insurance_legal_grade },
    { key: 'top_gap', header: 'Top Gap', render: (r: any) => r.top_gap ?? '-' },
    {
      key: 'coaching_required',
      header: 'Coach?',
      render: (r: any) => (r.coaching_required ? 'yes' : 'no'),
    },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const sessionCols: Column<any>[] = [
    { key: 'job_external_ref', header: 'Job Ref', render: (r: any) => r.job_external_ref ?? '-' },
    {
      key: 'session_at',
      header: 'Session At',
      render: (r: any) => (r.session_at ? new Date(r.session_at).toLocaleString() : '-'),
    },
    { key: 'coach_email', header: 'Coach', render: (r: any) => r.coach_email ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    {
      key: 'follow_up_at',
      header: 'Follow-up',
      render: (r: any) => (r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '-'),
    },
    { key: 'focus_md', header: 'Focus', render: (r: any) => r.focus_md ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const lowQualityCols: Column<any>[] = [
    { key: 'job_external_ref', header: 'Job Ref', render: (r: any) => r.job_external_ref },
    { key: 'audit_date', header: 'Audit Date', render: (r: any) => r.audit_date },
    { key: 'photo_quality_score', header: 'Quality', render: (r: any) => `${r.photo_quality_score}` },
    {
      key: 'evidence_completeness_pct',
      header: 'Complete %',
      render: (r: any) => `${r.evidence_completeness_pct}%`,
    },
    { key: 'insurance_legal_grade', header: 'Ins/Legal', render: (r: any) => r.insurance_legal_grade },
    { key: 'top_gap', header: 'Top Gap', render: (r: any) => r.top_gap ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const topCoachingCols: Column<any>[] = [
    { key: 'engineer_tier', header: 'Tier', render: (r: any) => r.engineer_tier ?? '-' },
    { key: 'audits', header: 'Audits', render: (r: any) => `${r.audits}` },
    {
      key: 'coaching_required_count',
      header: 'Coach Needed',
      render: (r: any) => `${r.coaching_required_count}`,
    },
    { key: 'avg_quality', header: 'Avg Quality', render: (r: any) => `${r.avg_quality}` },
    {
      key: 'avg_completeness',
      header: 'Avg Complete %',
      render: (r: any) => `${r.avg_completeness}%`,
    },
    { key: 'insurance_no_count', header: 'Ins No', render: (r: any) => `${r.insurance_no_count}` },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start },
    { key: 'audits', header: 'Audits', render: (r: any) => `${r.audits}` },
    { key: 'avg_quality', header: 'Avg Quality', render: (r: any) => `${r.avg_quality}` },
    {
      key: 'avg_completeness',
      header: 'Avg Complete %',
      render: (r: any) => `${r.avg_completeness}%`,
    },
    {
      key: 'insurance_yes_pct',
      header: 'Insurance Yes %',
      render: (r: any) => `${r.insurance_yes_pct ?? 0}%`,
    },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'insurance_legal_grade', header: 'Grade', render: (r: any) => r.insurance_legal_grade },
    { key: 'audits', header: 'Audits', render: (r: any) => `${r.audits}` },
    { key: 'avg_quality', header: 'Avg Quality', render: (r: any) => `${r.avg_quality}` },
    {
      key: 'avg_completeness',
      header: 'Avg Complete %',
      render: (r: any) => `${r.avg_completeness}%`,
    },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => `${r.escalated_count}` },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_audits', header: 'Open', render: (r: any) => `${r.open_audits}` },
    {
      key: 'coaching_required_count',
      header: 'Coach Needed',
      render: (r: any) => `${r.coaching_required_count}`,
    },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => `${r.escalated_count}` },
    { key: 'avg_quality', header: 'Avg Quality', render: (r: any) => `${r.avg_quality}` },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Engineer Photo Quality & Evidence Audit
        </h1>
        <p style={{ marginTop: 8, color: '#555' }}>
          Job-level photo audits, insurance/legal grade, and coaching follow-up
          (round r2494).
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>All Audits</h2>
        <DataTable
          rows={audits}
          columns={auditCols}
          emptyMessage="No audits yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Low-Quality Audits (<70 or insurance=no)</h2>
        <DataTable
          rows={lowQuality}
          columns={lowQualityCols}
          emptyMessage="No low-quality audits."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Coaching Sessions</h2>
        <DataTable
          rows={sessions}
          columns={sessionCols}
          emptyMessage="No coaching sessions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Top Engineers Needing Coaching</h2>
        <DataTable
          rows={topCoaching}
          columns={topCoachingCols}
          emptyMessage="No engineer rollups yet."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Weekly Completeness Trend</h2>
        <DataTable
          rows={weeklyTrend}
          columns={weeklyCols}
          emptyMessage="No weekly data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Insurance/Legal Grade Summary</h2>
        <DataTable
          rows={gradeSummary}
          columns={gradeCols}
          emptyMessage="No grade rollup."
          rowKey={(r: any, i: number) => String(r.insurance_legal_grade ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner load data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
