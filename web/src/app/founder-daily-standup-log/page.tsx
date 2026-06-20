import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';
import {
  logStandupEntry,
  logStandupBlocker,
  resolveStandupBlocker,
  deleteStandupEntry,
} from './actions';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type KpiRow = { metric: string; value_num: number | null; value_text: string | null };

function kpiMap(rows: KpiRow[] | null | undefined): Record<string, number> {
  const m: Record<string, number> = {};
  (rows ?? []).forEach((r) => { m[r.metric] = Number(r.value_num ?? 0); });
  return m;
}

function Card({ label, value, hint, tone }: { label: string; value: string; hint?: string; tone?: 'green' | 'yellow' | 'red' | 'neutral' }) {
  const toneCls =
    tone === 'red' ? 'border-red-300 bg-red-50' :
    tone === 'yellow' ? 'border-amber-300 bg-amber-50' :
    tone === 'green' ? 'border-emerald-300 bg-emerald-50' :
    'border-slate-200 bg-white';
  return (
    <div className={`rounded-lg border ${toneCls} p-3`}>
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-900">{value}</div>
      {hint ? <div className="mt-0.5 text-xs text-slate-500">{hint}</div> : null}
    </div>
  );
}

export default async function FounderDailyStandupLogPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, entriesRes, openBlockersRes, resolvedRes, streakRes, severityRes, engagementRes] = await Promise.all([
    sb.rpc('get_standup_kpis'),
    sb.rpc('list_recent_standup_entries', { p_days: 14 }),
    sb.rpc('list_open_blockers'),
    sb.rpc('list_recently_resolved_blockers', { p_days: 30 }),
    sb.rpc('get_streak_history', { p_days: 30 }),
    sb.rpc('get_blocker_severity_breakdown'),
    sb.rpc('get_author_engagement', { p_days: 30 }),
  ]);

  const k = kpiMap(kpisRes.data as KpiRow[] | null);
  const entries = (entriesRes.data ?? []) as Array<{ id: string; standup_date: string; author_role: string; author_email: string | null; shipped_yesterday: string; intent_today: string; mood: string; hours_worked_yesterday: number | null; blocker_count: number; created_at: string }>;
  const openBlockers = (openBlockersRes.data ?? []) as Array<{ id: string; raised_on: string; age_days: number; severity: string; category: string; title: string; detail: string | null; raised_by_email: string | null; entry_id: string }>;
  const resolved = (resolvedRes.data ?? []) as Array<{ id: string; raised_on: string; resolved_at: string; ttr_days: number | null; severity: string; category: string; title: string; resolved_note: string | null }>;
  const streak = (streakRes.data ?? []) as Array<{ d: string; entry_count: number; authors: string[] | null; any_red_mood: boolean | null }>;
  const severity = (severityRes.data ?? []) as Array<{ severity: string; category: string; open_count: number; resolved_30d: number; median_age_days: number | null }>;
  const engagement = (engagementRes.data ?? []) as Array<{ author_role: string; author_email: string | null; entries_count: number; days_active: number; avg_hours_worked: number | null; blockers_raised: number; last_entry_date: string | null }>;

  const oldest = openBlockers[0];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4 md:p-6">
      <header>
        <div className="text-xs uppercase tracking-wide text-slate-500">r1448 {"·"} Executive</div>
        <h1 className="text-2xl font-semibold text-slate-900">Founder Daily Standup Log</h1>
        <p className="mt-1 text-sm text-slate-600">
          Founder + lead engineer record yesterday {"→"} today + blockers. Streak builds discipline. Oldest unresolved blocker stays loud.
        </p>
      </header>

      {/* 16 KPI cards */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Card label="Entries today" value={String(k.entries_today ?? 0)} hint="founder + lead" tone={(k.entries_today ?? 0) >= 2 ? 'green' : 'yellow'} />
        <Card label="Entries 7d" value={String(k.entries_7d ?? 0)} />
        <Card label="Entries 30d" value={String(k.entries_30d ?? 0)} />
        <Card label="Streak (days)" value={String(k.streak_days ?? 0)} hint="consecutive days w/ {>=}1 entry" tone={(k.streak_days ?? 0) >= 7 ? 'green' : 'neutral'} />
        <Card label="Open blockers" value={String(k.open_blockers ?? 0)} tone={(k.open_blockers ?? 0) > 0 ? 'yellow' : 'green'} />
        <Card label="Open P0" value={String(k.open_p0 ?? 0)} tone={(k.open_p0 ?? 0) > 0 ? 'red' : 'green'} />
        <Card label="Open P1" value={String(k.open_p1 ?? 0)} tone={(k.open_p1 ?? 0) > 0 ? 'yellow' : 'green'} />
        <Card label="Open P2" value={String(k.open_p2 ?? 0)} />
        <Card label="Open P3" value={String(k.open_p3 ?? 0)} />
        <Card label="Resolved 7d" value={String(k.blockers_resolved_7d ?? 0)} />
        <Card label="Resolved 30d" value={String(k.blockers_resolved_30d ?? 0)} />
        <Card label="Avg hrs/day 7d" value={String(k.avg_hours_yesterday_7d ?? 0)} hint="self-reported" />
        <Card label="Red mood 7d" value={String(k.red_mood_7d ?? 0)} tone={(k.red_mood_7d ?? 0) > 0 ? 'red' : 'green'} />
        <Card label="Yellow mood 7d" value={String(k.yellow_mood_7d ?? 0)} />
        <Card label="Green mood 7d" value={String(k.green_mood_7d ?? 0)} tone="green" />
        <Card label="Oldest blocker (days)" value={String(k.oldest_blocker_age_days ?? 0)} tone={(k.oldest_blocker_age_days ?? 0) >= 7 ? 'red' : (k.oldest_blocker_age_days ?? 0) >= 3 ? 'yellow' : 'green'} />
      </section>

      {/* Oldest unresolved blocker callout */}
      {oldest ? (
        <section className="rounded-lg border border-red-300 bg-red-50 p-4">
          <div className="text-xs uppercase tracking-wide text-red-700">Oldest unresolved blocker</div>
          <div className="mt-1 text-lg font-semibold text-red-900">
            [{oldest.severity.toUpperCase()}] {oldest.title}
          </div>
          <div className="mt-1 text-sm text-red-800">
            {oldest.age_days} days old {"·"} category {oldest.category} {"·"} raised by {oldest.raised_by_email ?? 'unknown'}
          </div>
          {oldest.detail ? <div className="mt-2 text-sm text-slate-700">{oldest.detail}</div> : null}
          <form action={resolveStandupBlocker} className="mt-3 flex items-center gap-2">
            <input type="hidden" name="blocker_id" value={oldest.id} />
            <input name="resolved_note" placeholder="resolution note (optional)" className="flex-1 rounded border border-slate-300 px-2 py-1 text-sm" />
            <button type="submit" className="rounded bg-red-700 px-3 py-1 text-sm font-medium text-white hover:bg-red-800">Mark resolved</button>
          </form>
        </section>
      ) : (
        <section className="rounded-lg border border-emerald-300 bg-emerald-50 p-4 text-sm text-emerald-900">
          No unresolved blockers. Ship clean.
        </section>
      )}

      {/* New entry form */}
      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <div className="text-sm font-semibold text-slate-900">Log today {"·"} new standup entry</div>
        <form action={logStandupEntry} className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2">
          <label className="text-sm">
            <span className="text-xs text-slate-600">Role</span>
            <select name="author_role" className="mt-1 block w-full rounded border border-slate-300 px-2 py-1" defaultValue="founder">
              <option value="founder">founder</option>
              <option value="lead_engineer">lead_engineer</option>
            </select>
          </label>
          <label className="text-sm">
            <span className="text-xs text-slate-600">Mood</span>
            <select name="mood" className="mt-1 block w-full rounded border border-slate-300 px-2 py-1" defaultValue="green">
              <option value="green">green</option>
              <option value="yellow">yellow</option>
              <option value="red">red</option>
            </select>
          </label>
          <label className="text-sm md:col-span-2">
            <span className="text-xs text-slate-600">Shipped yesterday</span>
            <textarea name="shipped_yesterday" rows={2} className="mt-1 block w-full rounded border border-slate-300 px-2 py-1" />
          </label>
          <label className="text-sm md:col-span-2">
            <span className="text-xs text-slate-600">Intent today</span>
            <textarea name="intent_today" rows={2} className="mt-1 block w-full rounded border border-slate-300 px-2 py-1" />
          </label>
          <label className="text-sm">
            <span className="text-xs text-slate-600">Hours worked yesterday</span>
            <input type="number" step="0.5" name="hours_worked" className="mt-1 block w-full rounded border border-slate-300 px-2 py-1" />
          </label>
          <label className="text-sm">
            <span className="text-xs text-slate-600">Notes</span>
            <input name="notes" className="mt-1 block w-full rounded border border-slate-300 px-2 py-1" />
          </label>
          <div className="md:col-span-2">
            <button type="submit" className="rounded bg-slate-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-slate-700">Save entry</button>
            <span className="ml-3 text-xs text-slate-500">Upserts today {"·"} re-submit to edit</span>
          </div>
        </form>
      </section>

      {/* Recent entries */}
      <section className="space-y-2">
        <div className="text-sm font-semibold text-slate-900">Recent standup entries (14d)</div>
        <DataTable
          rowKey={(r: typeof entries[number]) => r.id}
          columns={[
            { key: 'c1', header: 'Date', render: (r: typeof entries[number]) => r.standup_date },
            { key: 'c2', header: 'Role', render: (r: typeof entries[number]) => r.author_role },
            { key: 'c3', header: 'Author', render: (r: typeof entries[number]) => r.author_email ?? '—' },
            { key: 'c4', header: 'Mood', render: (r: typeof entries[number]) => r.mood },
            { key: 'c5', header: 'Hrs', render: (r: typeof entries[number]) => (r.hours_worked_yesterday ?? '—') },
            { key: 'c6', header: 'Shipped', render: (r: typeof entries[number]) => <span className="line-clamp-2 max-w-md text-slate-700">{r.shipped_yesterday}</span> },
            { key: 'c7', header: 'Intent', render: (r: typeof entries[number]) => <span className="line-clamp-2 max-w-md text-slate-700">{r.intent_today}</span> },
            { key: 'c8', header: 'Blockers', render: (r: typeof entries[number]) => r.blocker_count },
          ]}
          rows={(entries) as any[]}
        />
      </section>

      {/* Open blockers */}
      <section className="space-y-2">
        <div className="text-sm font-semibold text-slate-900">Open blockers</div>
        <DataTable
          rowKey={(r: typeof openBlockers[number]) => r.id}
          columns={[
            { key: 'c9', header: 'Sev', render: (r: typeof openBlockers[number]) => r.severity.toUpperCase() },
            { key: 'c10', header: 'Age (d)', render: (r: typeof openBlockers[number]) => r.age_days },
            { key: 'c11', header: 'Category', render: (r: typeof openBlockers[number]) => r.category },
            { key: 'c12', header: 'Title', render: (r: typeof openBlockers[number]) => r.title },
            { key: 'c13', header: 'Raised by', render: (r: typeof openBlockers[number]) => r.raised_by_email ?? '—' },
            { key: 'c14', header: 'Action', render: (r: typeof openBlockers[number]) => (
              <form action={resolveStandupBlocker}>
                <input type="hidden" name="blocker_id" value={r.id} />
                <button type="submit" className="rounded bg-emerald-700 px-2 py-0.5 text-xs font-medium text-white hover:bg-emerald-800">Resolve</button>
              </form>
            )},
          ]}
          rows={(openBlockers) as any[]}
        />
      </section>

      {/* Recently resolved */}
      <section className="space-y-2">
        <div className="text-sm font-semibold text-slate-900">Recently resolved blockers (30d)</div>
        <DataTable
          rowKey={(r: typeof resolved[number]) => r.id}
          columns={[
            { key: 'c15', header: 'Sev', render: (r: typeof resolved[number]) => r.severity.toUpperCase() },
            { key: 'c16', header: 'Category', render: (r: typeof resolved[number]) => r.category },
            { key: 'c17', header: 'Title', render: (r: typeof resolved[number]) => r.title },
            { key: 'c18', header: 'TTR (d)', render: (r: typeof resolved[number]) => (r.ttr_days ?? '—') },
            { key: 'c19', header: 'Resolved at', render: (r: typeof resolved[number]) => new Date(r.resolved_at).toLocaleString('en-IN') },
            { key: 'c20', header: 'Note', render: (r: typeof resolved[number]) => <span className="line-clamp-2 max-w-md text-slate-700">{r.resolved_note ?? '—'}</span> },
          ]}
          rows={(resolved) as any[]}
        />
      </section>

      {/* Streak history */}
      <section className="space-y-2">
        <div className="text-sm font-semibold text-slate-900">Streak history (30d)</div>
        <DataTable
          rowKey={(r: typeof streak[number]) => r.d}
          columns={[
            { key: 'c21', header: 'Date', render: (r: typeof streak[number]) => r.d },
            { key: 'c22', header: 'Entries', render: (r: typeof streak[number]) => r.entry_count },
            { key: 'c23', header: 'Authors', render: (r: typeof streak[number]) => (r.authors ?? []).join(', ') || '—' },
            { key: 'c24', header: 'Any red mood', render: (r: typeof streak[number]) => (r.any_red_mood ? 'yes' : 'no') },
          ]}
          rows={(streak) as any[]}
        />
      </section>

      {/* Severity breakdown */}
      <section className="space-y-2">
        <div className="text-sm font-semibold text-slate-900">Blocker severity {"×"} category</div>
        <DataTable
          rowKey={(r: typeof severity[number]) => `${r.severity}-${r.category}`}
          columns={[
            { key: 'c25', header: 'Sev', render: (r: typeof severity[number]) => r.severity.toUpperCase() },
            { key: 'c26', header: 'Category', render: (r: typeof severity[number]) => r.category },
            { key: 'c27', header: 'Open', render: (r: typeof severity[number]) => r.open_count },
            { key: 'c28', header: 'Resolved 30d', render: (r: typeof severity[number]) => r.resolved_30d },
            { key: 'c29', header: 'Median age (d)', render: (r: typeof severity[number]) => (r.median_age_days ?? 0) },
          ]}
          rows={(severity) as any[]}
        />
      </section>

      {/* Author engagement */}
      <section className="space-y-2">
        <div className="text-sm font-semibold text-slate-900">Author engagement (30d)</div>
        <DataTable
          rowKey={(r: typeof engagement[number]) => `${r.author_role}-${r.author_email}`}
          columns={[
            { key: 'c30', header: 'Role', render: (r: typeof engagement[number]) => r.author_role },
            { key: 'c31', header: 'Email', render: (r: typeof engagement[number]) => r.author_email ?? '—' },
            { key: 'c32', header: 'Entries', render: (r: typeof engagement[number]) => r.entries_count },
            { key: 'c33', header: 'Days active', render: (r: typeof engagement[number]) => r.days_active },
            { key: 'c34', header: 'Avg hrs', render: (r: typeof engagement[number]) => (r.avg_hours_worked ?? 0) },
            { key: 'c35', header: 'Blockers raised', render: (r: typeof engagement[number]) => r.blockers_raised },
            { key: 'c36', header: 'Last entry', render: (r: typeof engagement[number]) => r.last_entry_date ?? '—' },
          ]}
          rows={(engagement) as any[]}
        />
      </section>

      <footer className="pt-2 text-xs text-slate-400">
        Refresh anytime {"·"} all data founder-gated {"·"} r1448
      </footer>
    </div>
  );
}
