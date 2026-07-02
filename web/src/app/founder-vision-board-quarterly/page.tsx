import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderVisionBoardQuarterlyPage() {
  const sb = await getSupabaseServerClient();

  const [boardsRes, currentRes, themesRes] = await Promise.all([
    sb.rpc('list_vision_boards_r1862'),
    sb.rpc('current_vision_board_r1862'),
    sb.rpc('vision_board_theme_evolution_r1862'),
  ]);

  const boards: any[] = Array.isArray(boardsRes.data) ? boardsRes.data : [];
  const currentArr: any[] = Array.isArray(currentRes.data) ? currentRes.data : [];
  const current = currentArr[0] ?? null;
  const themes: any[] = Array.isArray(themesRes.data) ? themesRes.data : [];

  let actions: any[] = [];
  if (current?.id) {
    const actionsRes = await sb.rpc('list_vision_board_actions_r1862', { p_board_id: current.id });
    actions = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  }

  const totalBoards = boards.length;
  const activeBoard = current?.quarter ?? '—';
  const openActions = current?.open_actions ?? 0;
  const doneActions = current?.done_actions ?? 0;
  const uniqueThemes = new Set(themes.map((t) => t.theme)).size;

  const boardCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono text-xs">{r.quarter}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
        <span className={`rounded px-2 py-0.5 text-xs ${
          r.status === 'active' ? 'bg-green-100 text-green-800'
          : r.status === 'superseded' ? 'bg-gray-200 text-gray-700'
          : 'bg-yellow-100 text-yellow-800'
        }`}>{r.status}</span>
      ) },
    { key: 'themes', header: 'Key Themes', render: (r: any) => (
        <div className="flex flex-wrap gap-1">
          {(r.key_themes ?? []).slice(0, 6).map((t: string, i: number) => (
            <span key={i} className="rounded bg-indigo-50 px-1.5 py-0.5 text-xs text-indigo-700">{t}</span>
          ))}
        </div>
      ) },
    { key: 'actions', header: 'Actions', render: (r: any) => (
        <span className="text-xs">
          {r.open_count ?? 0} open · {r.action_count ?? 0} total
        </span>
      ) },
    { key: 'locked_at', header: 'Locked', render: (r: any) => (
        <span className="text-xs text-[var(--color-muted)]">
          {r.locked_at ? new Date(r.locked_at).toLocaleDateString() : '—'}
        </span>
      ) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_text', header: 'Action', render: (r: any) => <span className="text-sm">{r.action_text}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
        <span className={`rounded px-2 py-0.5 text-xs ${
          r.status === 'done' ? 'bg-green-100 text-green-800'
          : r.status === 'dropped' ? 'bg-gray-200 text-gray-700'
          : 'bg-yellow-100 text-yellow-800'
        }`}>{r.status}</span>
      ) },
    { key: 'due_date', header: 'Due', render: (r: any) => (
        <span className="text-xs">{r.due_date ?? '—'}</span>
      ) },
    { key: 'completed_at', header: 'Completed', render: (r: any) => (
        <span className="text-xs text-[var(--color-muted)]">
          {r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—'}
        </span>
      ) },
  ];

  const themeCols: Column<any>[] = [
    { key: 'theme', header: 'Theme', render: (r: any) => <span className="text-sm font-medium">{r.theme}</span> },
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono text-xs">{r.quarter}</span> },
    { key: 'status', header: 'Board Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'first_appearance', header: 'First Time?', render: (r: any) => (
        <span className={`text-xs ${r.first_appearance ? 'font-semibold text-emerald-700' : 'text-[var(--color-muted)]'}`}>
          {r.first_appearance ? 'NEW' : 'recurring'}
        </span>
      ) },
  ];

  return (
    <div className="space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Vision Board — Quarterly</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Where do we want to be in 5y &gt; locked each quarter. Themes evolve, non-negotiables hold.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Boards</div>
          <div className="mt-1 text-2xl font-semibold">{totalBoards}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Active Quarter</div>
          <div className="mt-1 text-2xl font-semibold">{activeBoard}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Open Actions</div>
          <div className="mt-1 text-2xl font-semibold">{openActions}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Done Actions</div>
          <div className="mt-1 text-2xl font-semibold">{doneActions}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Unique Themes</div>
          <div className="mt-1 text-2xl font-semibold">{uniqueThemes}</div>
        </div>
      </section>

      {current ? (
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Current Board — {current.quarter}</h2>
          <div className="grid gap-3 md:grid-cols-2">
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
                Where in 5y &gt;
              </div>
              <pre className="mt-2 whitespace-pre-wrap text-sm">{current.where_in_5y_md || '—'}</pre>
            </div>
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">
                Non-negotiables
              </div>
              <pre className="mt-2 whitespace-pre-wrap text-sm">{current.non_negotiables_md || '—'}</pre>
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-muted)]">Key Themes</div>
            <div className="mt-2 flex flex-wrap gap-2">
              {(current.key_themes ?? []).map((t: string, i: number) => (
                <span key={i} className="rounded bg-indigo-50 px-2 py-1 text-xs text-indigo-700">{t}</span>
              ))}
              {(current.key_themes ?? []).length === 0 ? <span className="text-sm text-[var(--color-muted)]">none</span> : null}
            </div>
          </div>
        </section>
      ) : (
        <section className="rounded border border-dashed border-[var(--color-border)] bg-white p-6 text-sm text-[var(--color-muted)]">
          No active board yet. Save & lock a quarter to set the vision.
        </section>
      )}

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Current Quarter Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No actions logged for the active board."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Quarterly Boards</h2>
        <DataTable
          rows={boards}
          columns={boardCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No vision boards saved yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Theme Evolution — what changed quarter-over-quarter</h2>
        <DataTable
          rows={themes}
          columns={themeCols}
          rowKey={(r: any, i: number) => `${r.quarter}-${r.theme}-${i}`}
          emptyMessage="No themes tracked yet."
        />
      </section>
    </div>
  );
}
