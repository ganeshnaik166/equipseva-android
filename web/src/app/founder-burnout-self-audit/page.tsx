import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderBurnoutSelfAuditPage() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, interventionsRes, summaryRes, lowEnergyRes, burnoutRes] = await Promise.all([
    sb.rpc('list_audits_r1762', { p_limit: 60 }),
    sb.rpc('list_interventions_r1762', { p_limit: 60 }),
    sb.rpc('audit_summary_r1762'),
    sb.rpc('recent_low_energy_days_r1762', { p_limit: 30 }),
    sb.rpc('recent_high_burnout_signals_r1762', { p_limit: 30 }),
  ]);

  const audits = (auditsRes.data ?? []) as any[];
  const interventions = (interventionsRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? null) as any;
  const lowEnergy = (lowEnergyRes.data ?? []) as any[];
  const burnout = (burnoutRes.data ?? []) as any[];

  const auditColumns: Column<any>[] = [
    { key: 'audit_date', header: 'Date', render: (r: any) => String(r.audit_date ?? '') },
    { key: 'sleep_hours', header: 'Sleep (h)', render: (r: any) => r.sleep_hours == null ? '—' : String(r.sleep_hours) },
    { key: 'mood_score', header: 'Mood (1–10)', render: (r: any) => r.mood_score == null ? '—' : String(r.mood_score) },
    { key: 'energy_score', header: 'Energy (1–10)', render: (r: any) => r.energy_score == null ? '—' : String(r.energy_score) },
    { key: 'hours_worked', header: 'Worked (h)', render: (r: any) => r.hours_worked == null ? '—' : String(r.hours_worked) },
    { key: 'drank_water', header: 'Water', render: (r: any) => r.drank_water ? 'Yes' : 'No' },
    { key: 'exercised', header: 'Exercise', render: (r: any) => r.exercised ? 'Yes' : 'No' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs text-[var(--color-muted)]">{r.notes_md ?? ''}</span> },
  ];

  const interventionColumns: Column<any>[] = [
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleString() : '—' },
    { key: 'audit_date', header: 'Audit Date', render: (r: any) => String(r.audit_date ?? '—') },
    { key: 'intervention_type', header: 'Type', render: (r: any) => String(r.intervention_type ?? '') },
    { key: 'effective', header: 'Effective', render: (r: any) => r.effective == null ? '—' : (r.effective ? 'Yes' : 'No') },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs text-[var(--color-muted)]">{r.note ?? ''}</span> },
  ];

  const lowEnergyColumns: Column<any>[] = [
    { key: 'audit_date', header: 'Date', render: (r: any) => String(r.audit_date ?? '') },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score ?? '') },
    { key: 'sleep_hours', header: 'Sleep (h)', render: (r: any) => r.sleep_hours == null ? '—' : String(r.sleep_hours) },
    { key: 'hours_worked', header: 'Worked (h)', render: (r: any) => r.hours_worked == null ? '—' : String(r.hours_worked) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs text-[var(--color-muted)]">{r.notes_md ?? ''}</span> },
  ];

  const burnoutColumns: Column<any>[] = [
    { key: 'audit_date', header: 'Date', render: (r: any) => String(r.audit_date ?? '') },
    { key: 'signal_count', header: 'Signals', render: (r: any) => String(r.signal_count ?? 0) },
    { key: 'sleep_hours', header: 'Sleep (h)', render: (r: any) => r.sleep_hours == null ? '—' : String(r.sleep_hours) },
    { key: 'mood_score', header: 'Mood', render: (r: any) => r.mood_score == null ? '—' : String(r.mood_score) },
    { key: 'energy_score', header: 'Energy', render: (r: any) => r.energy_score == null ? '—' : String(r.energy_score) },
    { key: 'hours_worked', header: 'Worked (h)', render: (r: any) => r.hours_worked == null ? '—' : String(r.hours_worked) },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder Burnout Self-Audit</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Daily self-check on sleep, mood, energy, and hours worked. Burnout signals flag days where sleep &lt; 6h, mood &lt;= 4, energy &lt;= 4, or worked &gt; 12h.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">30-day summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Days logged</div>
            <div className="text-xl font-semibold">{summary?.total_days ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg sleep (h)</div>
            <div className="text-xl font-semibold">{summary?.avg_sleep ?? '—'}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg mood</div>
            <div className="text-xl font-semibold">{summary?.avg_mood ?? '—'}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg energy</div>
            <div className="text-xl font-semibold">{summary?.avg_energy ?? '—'}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg hours worked</div>
            <div className="text-xl font-semibold">{summary?.avg_hours_worked ?? '—'}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Water days</div>
            <div className="text-xl font-semibold">{summary?.water_days ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Exercise days</div>
            <div className="text-xl font-semibold">{summary?.exercise_days ?? 0}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Low-energy days (&lt;=4)</div>
            <div className="text-xl font-semibold">{summary?.low_energy_days ?? 0}</div>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">High burnout signal days</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Days where one or more red-flag thresholds were crossed (sleep &lt; 6h, mood &lt;= 4, energy &lt;= 4, worked &gt; 12h).
        </p>
        <DataTable
          rows={burnout}
          columns={burnoutColumns}
          rowKey={(r: any, i: number) => String(r.audit_date ?? i)}
          emptyMessage="No burnout-signal days flagged."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent low-energy days</h2>
        <DataTable
          rows={lowEnergy}
          columns={lowEnergyColumns}
          rowKey={(r: any, i: number) => String(r.audit_date ?? i)}
          emptyMessage="No low-energy days logged."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Interventions log</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Vacation, reduced hours, founder buddy, therapy, meditation — track what helped.
        </p>
        <DataTable
          rows={interventions}
          columns={interventionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No interventions logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Audit history</h2>
        <DataTable
          rows={audits}
          columns={auditColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No self-audits recorded yet."
        />
      </section>
    </div>
  );
}
