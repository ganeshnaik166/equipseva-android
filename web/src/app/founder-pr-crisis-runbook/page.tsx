import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_playbooks: number | null;
  p0_playbooks: number | null;
  p1_playbooks: number | null;
  legal_review_required_count: number | null;
  active_invocations: number | null;
  contained_invocations_30d: number | null;
  resolved_invocations_30d: number | null;
  last_invocation_at: string | null;
  playbooks_never_dry_run: number | null;
};

type PlaybookRow = {
  id: string;
  crisis_code: string | null;
  crisis_title: string | null;
  crisis_kind: string | null;
  severity_tier: string | null;
  first_60_min_action: string | null;
  legal_review_required: boolean | null;
  invocation_count: number | null;
  last_invoked_at: string | null;
  last_dry_run_at: string | null;
  step_count: number | null;
  contact_count: number | null;
};

type ActiveRow = {
  invocation_id: string;
  crisis_title: string | null;
  severity_tier: string | null;
  invocation_status: string | null;
  trigger_summary: string | null;
  reach_estimate: number | null;
  current_step_index: number | null;
  total_steps: number | null;
  opened_at: string | null;
  hours_open: number | null;
  opened_by_email: string | null;
};

type HistoryRow = {
  invocation_id: string;
  crisis_title: string | null;
  severity_tier: string | null;
  invocation_status: string | null;
  trigger_summary: string | null;
  opened_at: string | null;
  resolved_at: string | null;
  hours_to_resolve: number | null;
  postmortem_url: string | null;
};

type KindRow = {
  crisis_kind: string | null;
  playbook_count: number | null;
  p0_count: number | null;
  p1_count: number | null;
  p2_p3_count: number | null;
  legal_review_count: number | null;
  ever_invoked_count: number | null;
  total_invocations: number | null;
};

function fmtDate(v: string | null | undefined) {
  if (!v) return '—';
  try { return new Date(v).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }); } catch { return '—'; }
}

function sevBadge(tier: string | null | undefined) {
  const t = (tier ?? '').toLowerCase();
  if (t === 'p0') return 'P0 EXISTENTIAL';
  if (t === 'p1') return 'P1 SEVERE';
  if (t === 'p2') return 'P2 ELEVATED';
  if (t === 'p3') return 'P3 ROUTINE';
  return tier ?? '—';
}

export default async function FounderPrCrisisRunbookPage() {
  const sb = await getSupabaseServerClient();

  const overviewRes = await sb.rpc('founder_pr_runbook_overview');
  const playbooksRes = await sb.rpc('founder_pr_list_playbooks');
  const activeRes = await sb.rpc('founder_pr_active_invocations');
  const historyRes = await sb.rpc('founder_pr_invocation_history');
  const kindRes = await sb.rpc('founder_pr_kind_breakdown');

  const overview: OverviewRow | null = Array.isArray(overviewRes.data) && overviewRes.data.length > 0 ? (overviewRes.data[0] as OverviewRow) : null;
  const playbooks: PlaybookRow[] = Array.isArray(playbooksRes.data) ? (playbooksRes.data as PlaybookRow[]) : [];
  const active: ActiveRow[] = Array.isArray(activeRes.data) ? (activeRes.data as ActiveRow[]) : [];
  const history: HistoryRow[] = Array.isArray(historyRes.data) ? (historyRes.data as HistoryRow[]) : [];
  const kinds: KindRow[] = Array.isArray(kindRes.data) ? (kindRes.data as KindRow[]) : [];

  const anyErr = overviewRes.error?.message ?? playbooksRes.error?.message ?? activeRes.error?.message ?? historyRes.error?.message ?? kindRes.error?.message ?? null;

  const playbookCols: Column<PlaybookRow>[] = [
    { key: 'crisis_title', header: 'Playbook', render: (r) => (
        <div>
          <div style={{ fontWeight: 600 }}>{r.crisis_title ?? '—'}</div>
          <div style={{ fontSize: 11, color: '#666' }}>{r.crisis_code ?? '—'}</div>
        </div>
    ) },
    { key: 'crisis_kind', header: 'Kind', render: (r) => r.crisis_kind ?? '—' },
    { key: 'severity_tier', header: 'Severity', render: (r) => (
        <span style={{ fontWeight: 600, color: r.severity_tier === 'p0' ? '#b91c1c' : r.severity_tier === 'p1' ? '#c2410c' : '#374151' }}>
          {sevBadge(r.severity_tier)}
        </span>
    ) },
    { key: 'first_60_min_action', header: 'First 60 min', render: (r) => (
        <div style={{ maxWidth: 360, fontSize: 12 }}>{r.first_60_min_action ?? '—'}</div>
    ) },
    { key: 'step_count', header: 'Steps', render: (r) => String(r.step_count ?? 0) },
    { key: 'contact_count', header: 'Contacts', render: (r) => String(r.contact_count ?? 0) },
    { key: 'legal_review_required', header: 'Legal?', render: (r) => r.legal_review_required ? 'Yes' : 'No' },
    { key: 'invocation_count', header: 'Invoked', render: (r) => String(r.invocation_count ?? 0) },
    { key: 'last_invoked_at', header: 'Last invoked', render: (r) => fmtDate(r.last_invoked_at) },
    { key: 'last_dry_run_at', header: 'Last dry-run', render: (r) => r.last_dry_run_at ? fmtDate(r.last_dry_run_at) : 'NEVER' },
  ];

  const activeCols: Column<ActiveRow>[] = [
    { key: 'crisis_title', header: 'Crisis', render: (r) => r.crisis_title ?? '—' },
    { key: 'severity_tier', header: 'Severity', render: (r) => (
        <span style={{ fontWeight: 600, color: r.severity_tier === 'p0' ? '#b91c1c' : r.severity_tier === 'p1' ? '#c2410c' : '#374151' }}>
          {sevBadge(r.severity_tier)}
        </span>
    ) },
    { key: 'invocation_status', header: 'Status', render: (r) => r.invocation_status ?? '—' },
    { key: 'trigger_summary', header: 'Trigger', render: (r) => (
        <div style={{ maxWidth: 320, fontSize: 12 }}>{r.trigger_summary ?? '—'}</div>
    ) },
    { key: 'reach_estimate', header: 'Reach', render: (r) => r.reach_estimate != null ? r.reach_estimate.toLocaleString('en-IN') : '—' },
    { key: 'current_step_index', header: 'Step', render: (r) => `${r.current_step_index ?? 0} / ${r.total_steps ?? 0}` },
    { key: 'opened_at', header: 'Opened', render: (r) => fmtDate(r.opened_at) },
    { key: 'hours_open', header: 'Hours open', render: (r) => r.hours_open != null ? String(r.hours_open) : '—' },
    { key: 'opened_by_email', header: 'Opened by', render: (r) => r.opened_by_email ?? '—' },
  ];

  const historyCols: Column<HistoryRow>[] = [
    { key: 'crisis_title', header: 'Crisis', render: (r) => r.crisis_title ?? '—' },
    { key: 'severity_tier', header: 'Severity', render: (r) => sevBadge(r.severity_tier) },
    { key: 'invocation_status', header: 'Status', render: (r) => r.invocation_status ?? '—' },
    { key: 'trigger_summary', header: 'Trigger', render: (r) => (
        <div style={{ maxWidth: 320, fontSize: 12 }}>{r.trigger_summary ?? '—'}</div>
    ) },
    { key: 'opened_at', header: 'Opened', render: (r) => fmtDate(r.opened_at) },
    { key: 'resolved_at', header: 'Resolved', render: (r) => fmtDate(r.resolved_at) },
    { key: 'hours_to_resolve', header: 'Hours to resolve', render: (r) => r.hours_to_resolve != null ? String(r.hours_to_resolve) : '—' },
    { key: 'postmortem_url', header: 'Postmortem', render: (r) => r.postmortem_url ?? '—' },
  ];

  const kindCols: Column<KindRow>[] = [
    { key: 'crisis_kind', header: 'Crisis kind', render: (r) => r.crisis_kind ?? '—' },
    { key: 'playbook_count', header: 'Playbooks', render: (r) => String(r.playbook_count ?? 0) },
    { key: 'p0_count', header: 'P0', render: (r) => String(r.p0_count ?? 0) },
    { key: 'p1_count', header: 'P1', render: (r) => String(r.p1_count ?? 0) },
    { key: 'p2_p3_count', header: 'P2/P3', render: (r) => String(r.p2_p3_count ?? 0) },
    { key: 'legal_review_count', header: 'Legal req', render: (r) => String(r.legal_review_count ?? 0) },
    { key: 'ever_invoked_count', header: 'Ever invoked', render: (r) => String(r.ever_invoked_count ?? 0) },
    { key: 'total_invocations', header: 'Total invocations', render: (r) => String(r.total_invocations ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <div style={{ marginBottom: 8 }}>
        <a href="/ops-index" style={{ fontSize: 12, color: '#2563eb', textDecoration: 'none' }}>← Ops index</a>
      </div>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>PR Crisis Runbook</h1>
      <p style={{ color: '#555', marginBottom: 20, fontSize: 13 }}>
        Pre-built playbooks for PR crises: negative press, viral complaints, founder controversy, regulatory blowback, data breach. Per-step actions, do-say / do-not-say, escalation contacts. Founder-only.
      </p>

      {anyErr ? (
        <div style={{ padding: 12, background: '#fee2e2', color: '#991b1b', borderRadius: 6, marginBottom: 16, fontSize: 13 }}>
          Error loading: {anyErr}
        </div>
      ) : null}

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <Stat label="Playbooks" value={overview?.total_playbooks ?? 0} />
        <Stat label="P0 playbooks" value={overview?.p0_playbooks ?? 0} accent="#b91c1c" />
        <Stat label="P1 playbooks" value={overview?.p1_playbooks ?? 0} accent="#c2410c" />
        <Stat label="Legal review req" value={overview?.legal_review_required_count ?? 0} />
        <Stat label="Active crises NOW" value={overview?.active_invocations ?? 0} accent={overview && (overview.active_invocations ?? 0) > 0 ? '#b91c1c' : '#374151'} />
        <Stat label="Contained 30d" value={overview?.contained_invocations_30d ?? 0} />
        <Stat label="Resolved 30d" value={overview?.resolved_invocations_30d ?? 0} />
        <Stat label="Never dry-run" value={overview?.playbooks_never_dry_run ?? 0} accent={overview && (overview.playbooks_never_dry_run ?? 0) > 0 ? '#c2410c' : '#374151'} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active & containing crises</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 8 }}>Live invocations — sorted by severity then most recent.</p>
        <DataTable
          columns={activeCols}
          rows={active}
          rowKey={(r: any, i: number) => String(r.invocation_id ?? r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Playbook directory</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 8 }}>All canonical PR crisis playbooks. Click into each for full step-by-step + escalation contacts.</p>
        <DataTable
          columns={playbookCols}
          rows={playbooks}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Crisis kind breakdown</h2>
        <DataTable
          columns={kindCols}
          rows={kinds}
          rowKey={(r: any, i: number) => String(r.crisis_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Invocation history (90d)</h2>
        <DataTable
          columns={historyCols}
          rows={history}
          rowKey={(r: any, i: number) => String(r.invocation_id ?? r.id ?? i)}
        />
      </section>

      <section style={{ marginTop: 24, padding: 16, background: '#fef9c3', borderRadius: 8, fontSize: 12, color: '#713f12' }}>
        <strong>Golden rules:</strong> 1) Acknowledge fast, decide slow. 2) Do not engage individual threads. 3) Legal review before any p0/p1 statement. 4) Brief team internally before they read it on Twitter. 5) Address substance, not the leak.
      </section>
    </main>
  );
}

function Stat({ label, value, accent }: { label: string; value: number | string; accent?: string }) {
  return (
    <div style={{ padding: 14, background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8 }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent ?? '#111827', marginTop: 4 }}>{value}</div>
    </div>
  );
}
