import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalDecisionMakerMapPage() {
  const sb = await getSupabaseServerClient();

  const [decisionMakers, relationships, warm, blockers, budgetHolders] = await Promise.all([
    sb.rpc('list_decision_makers_r1811'),
    sb.rpc('list_relationships_r1811'),
    sb.rpc('top_warm_relationships_r1811'),
    sb.rpc('blockers_per_hospital_r1811'),
    sb.rpc('budget_holders_r1811'),
  ]);

  const dmRows: any[] = Array.isArray(decisionMakers.data) ? decisionMakers.data : [];
  const relRows: any[] = Array.isArray(relationships.data) ? relationships.data : [];
  const warmRows: any[] = Array.isArray(warm.data) ? warm.data : [];
  const blockerRows: any[] = Array.isArray(blockers.data) ? blockers.data : [];
  const budgetRows: any[] = Array.isArray(budgetHolders.data) ? budgetHolders.data : [];

  const dmColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span className="font-medium">{r.hospital_name ?? '—'}</span> },
    { key: 'person_name', header: 'Person', render: (r: any) => <span>{r.person_name ?? '—'}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs uppercase">{r.person_role ?? '—'}</span> },
    { key: 'person_email', header: 'Email', render: (r: any) => <span className="text-xs">{r.person_email ?? '—'}</span> },
    { key: 'has_budget_authority', header: 'Budget?', render: (r: any) => <span>{r.has_budget_authority ? 'Yes' : 'No'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status ?? '—'}</span> },
    { key: 'created_at', header: 'Added', render: (r: any) => <span className="text-xs">{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span> },
  ];

  const relColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name ?? '—'}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs uppercase">{r.person_role ?? '—'}</span> },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.relationship_strength ?? '—'}</span> },
    { key: 'last_engaged_at', header: 'Last Engaged', render: (r: any) => <span className="text-xs">{r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : '—'}</span> },
    { key: 'founder_note', header: 'Note', render: (r: any) => <span className="text-xs">{r.founder_note ?? '—'}</span> },
  ];

  const warmColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name ?? '—'}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs uppercase">{r.person_role ?? '—'}</span> },
    { key: 'last_engaged_at', header: 'Last Engaged', render: (r: any) => <span className="text-xs">{r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : '—'}</span> },
    { key: 'founder_note', header: 'Note', render: (r: any) => <span className="text-xs">{r.founder_note ?? '—'}</span> },
  ];

  const blockerColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span className="font-medium">{r.hospital_name ?? '—'}</span> },
    { key: 'blocker_count', header: 'Blockers', render: (r: any) => <span className="rounded bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">{r.blocker_count ?? 0}</span> },
    { key: 'blocker_names', header: 'Names', render: (r: any) => <span className="text-xs">{r.blocker_names ?? '—'}</span> },
  ];

  const budgetColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name ?? '—'}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs uppercase">{r.person_role ?? '—'}</span> },
    { key: 'person_email', header: 'Email', render: (r: any) => <span className="text-xs">{r.person_email ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status ?? '—'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Hospital Decision Maker Map</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Per-hospital decision-maker org chart — who owns budget, who blocks deals, who is warm. Round r1811.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-5">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Decision Makers</div>
          <div className="mt-1 text-2xl font-semibold">{dmRows.length}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Relationship Touches</div>
          <div className="mt-1 text-2xl font-semibold">{relRows.length}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Warm Contacts</div>
          <div className="mt-1 text-2xl font-semibold">{warmRows.length}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Hospitals w/ Blockers</div>
          <div className="mt-1 text-2xl font-semibold">{blockerRows.length}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Budget Holders</div>
          <div className="mt-1 text-2xl font-semibold">{budgetRows.length}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Decision Makers</h2>
        <p className="text-xs text-[var(--color-muted)]">Every named contact across hospitals — role + status + budget authority.</p>
        <DataTable
          rows={dmRows}
          columns={dmColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No decision makers logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Relationship Touch History</h2>
        <p className="text-xs text-[var(--color-muted)]">Most recent engagement per contact with strength & founder notes.</p>
        <DataTable
          rows={relRows}
          columns={relColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No relationships tracked yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Warm Relationships</h2>
        <p className="text-xs text-[var(--color-muted)]">Contacts with strength = warm — prioritise outreach here.</p>
        <DataTable
          rows={warmRows}
          columns={warmColumns}
          rowKey={(r: any, i: number) => String(r.decision_maker_id ?? i)}
          emptyMessage="No warm relationships yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Blockers Per Hospital</h2>
        <p className="text-xs text-[var(--color-muted)]">Hospitals where a named person is actively blocking procurement.</p>
        <DataTable
          rows={blockerRows}
          columns={blockerColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
          emptyMessage="No blockers flagged."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Budget Holders</h2>
        <p className="text-xs text-[var(--color-muted)]">Everyone with budget authority — primary targets for commercial conversation.</p>
        <DataTable
          rows={budgetRows}
          columns={budgetColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No budget holders logged."
        />
      </section>
    </main>
  );
}
