import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { quarter: string; total_letters: number; published: number; in_recovery: number; restored: number; total_restitution: number; avg_sentiment: number | null };
type ByAudience = { audience: string; letter_count: number; avg_reach: number; total_restitution: number; restored_pct: number | null };
type Severity = { severity: string; total: number; drafted: number; published: number; restored: number; escalated: number };
type OpenLetter = { incident_code: string; incident_title: string; severity: string; audience: string; letter_status: string; drafted_at: string; days_open: number };
type ActionSummary = { action_type: string; total: number; completed: number; in_flight: number; total_cost: number; avg_trust_delta: number };
type Owner = { owner_role: string; action_count: number; completed: number; queued: number; blocked: number; total_hours: number };
type TopRestitution = { incident_code: string; incident_title: string; audience: string; restitution_rupees: number; reach_count: number; recovery_state: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, audienceRes, severityRes, openRes, actionsRes, ownerRes, topRes] = await Promise.all([
    supabase.rpc('qstr_letters_overview_r3065'),
    supabase.rpc('qstr_letters_by_audience_r3065'),
    supabase.rpc('qstr_severity_funnel_r3065'),
    supabase.rpc('qstr_open_letters_r3065'),
    supabase.rpc('qstr_recovery_actions_summary_r3065'),
    supabase.rpc('qstr_owner_workload_r3065'),
    supabase.rpc('qstr_top_restitution_r3065'),
  ]);

  const overview = (overviewRes.data ?? []) as Overview[];
  const byAudience = (audienceRes.data ?? []) as ByAudience[];
  const severity = (severityRes.data ?? []) as Severity[];
  const openLetters = (openRes.data ?? []) as OpenLetter[];
  const actions = (actionsRes.data ?? []) as ActionSummary[];
  const owners = (ownerRes.data ?? []) as Owner[];
  const topRestitution = (topRes.data ?? []) as TopRestitution[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Letters', accessor: (r) => r.total_letters },
    { header: 'Published', accessor: (r) => r.published },
    { header: 'In Recovery', accessor: (r) => r.in_recovery },
    { header: 'Restored', accessor: (r) => r.restored },
    { header: 'Restitution (Rs)', accessor: (r) => r.total_restitution.toLocaleString('en-IN') },
    { header: 'Avg Sentiment', accessor: (r) => r.avg_sentiment ?? '—' },
  ];

  const audienceCols: Column<ByAudience>[] = [
    { header: 'Audience', accessor: (r) => r.audience },
    { header: 'Letters', accessor: (r) => r.letter_count },
    { header: 'Avg Reach', accessor: (r) => r.avg_reach },
    { header: 'Restitution (Rs)', accessor: (r) => r.total_restitution.toLocaleString('en-IN') },
    { header: 'Restored %', accessor: (r) => (r.restored_pct ?? 0) + '%' },
  ];

  const severityCols: Column<Severity>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Drafted', accessor: (r) => r.drafted },
    { header: 'Published', accessor: (r) => r.published },
    { header: 'Restored', accessor: (r) => r.restored },
    { header: 'Escalated', accessor: (r) => r.escalated },
  ];

  const openCols: Column<OpenLetter>[] = [
    { header: 'Code', accessor: (r) => r.incident_code },
    { header: 'Title', accessor: (r) => r.incident_title },
    { header: 'Sev', accessor: (r) => r.severity },
    { header: 'Audience', accessor: (r) => r.audience },
    { header: 'Status', accessor: (r) => r.letter_status },
    { header: 'Days Open', accessor: (r) => r.days_open },
  ];

  const actionCols: Column<ActionSummary>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Done', accessor: (r) => r.completed },
    { header: 'In Flight', accessor: (r) => r.in_flight },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost.toLocaleString('en-IN') },
    { header: 'Avg Trust Δ', accessor: (r) => r.avg_trust_delta },
  ];

  const ownerCols: Column<Owner>[] = [
    { header: 'Owner', accessor: (r) => r.owner_role },
    { header: 'Actions', accessor: (r) => r.action_count },
    { header: 'Done', accessor: (r) => r.completed },
    { header: 'Queued', accessor: (r) => r.queued },
    { header: 'Blocked', accessor: (r) => r.blocked },
    { header: 'Hours', accessor: (r) => r.total_hours },
  ];

  const topCols: Column<TopRestitution>[] = [
    { header: 'Code', accessor: (r) => r.incident_code },
    { header: 'Title', accessor: (r) => r.incident_title },
    { header: 'Audience', accessor: (r) => r.audience },
    { header: 'Restitution (Rs)', accessor: (r) => r.restitution_rupees.toLocaleString('en-IN') },
    { header: 'Reach', accessor: (r) => r.reach_count.toLocaleString('en-IN') },
    { header: 'Recovery', accessor: (r) => r.recovery_state },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Quarterly Strategic Engineer-Founder Public-Apology Letter Tracking &amp; Recovery Audit</h1>
        <p className="text-sm text-gray-600 mt-1">Round r3065 — Batch 440 milestone. Track every founder apology letter from draft &gt;= legal review =&gt; published, paired with measurable recovery actions and trust delta.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Quarterly Overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No quarters yet" rowKey={(r, i) => String((r as Overview).quarter ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">By Audience</h2>
        <DataTable rows={byAudience} columns={audienceCols} emptyMessage="No audiences" rowKey={(r, i) => String((r as ByAudience).audience ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Severity Funnel</h2>
        <DataTable rows={severity} columns={severityCols} emptyMessage="No severities" rowKey={(r, i) => String((r as Severity).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open Letters (drafted &amp; under review)</h2>
        <DataTable rows={openLetters} columns={openCols} emptyMessage="All letters published" rowKey={(r, i) => String((r as OpenLetter).incident_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recovery Action Summary</h2>
        <DataTable rows={actions} columns={actionCols} emptyMessage="No actions" rowKey={(r, i) => String((r as ActionSummary).action_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Owner Workload</h2>
        <DataTable rows={owners} columns={ownerCols} emptyMessage="No owners" rowKey={(r, i) => String((r as Owner).owner_role ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top Restitution (&gt;= Rs 0)</h2>
        <DataTable rows={topRestitution} columns={topCols} emptyMessage="No restitution paid" rowKey={(r, i) => String((r as TopRestitution).incident_code ?? i)} />
      </section>
    </main>
  );
}
