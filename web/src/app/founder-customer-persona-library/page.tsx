import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Persona = {
  id: string;
  persona_name: string;
  persona_role: string;
  pain_points_md: string | null;
  motivators_md: string | null;
  common_objections_md: string | null;
  status: string;
  created_at: string;
  updated_at: string;
};

type RoleRow = {
  persona_role: string;
  total_count: number;
  active_count: number;
};

type ChangeRow = {
  id: string;
  persona_id: string;
  persona_name: string;
  persona_role: string;
  change_at: string;
  change_type: string;
  change_text: string;
};

function fmt(ts: string | null): string {
  if (!ts) return '-';
  try {
    return new Date(ts).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return ts;
  }
}

function clip(s: string | null, n: number): string {
  if (!s) return '-';
  const t = s.trim();
  if (t.length <= n) return t;
  return t.slice(0, n) + '...';
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [personasRes, rolesRes, changesRes] = await Promise.all([
    sb.rpc('list_personas_r1886'),
    sb.rpc('top_role_distribution_r1886'),
    sb.rpc('recent_changes_r1886'),
  ]);

  const personas: Persona[] = (personasRes.data as Persona[] | null) ?? [];
  const roles: RoleRow[] = (rolesRes.data as RoleRow[] | null) ?? [];
  const changes: ChangeRow[] = (changesRes.data as ChangeRow[] | null) ?? [];

  const totalPersonas = personas.length;
  const activePersonas = personas.filter((p) => p.status === 'active').length;
  const reviewPersonas = personas.filter((p) => p.status === 'under_review').length;
  const archivedPersonas = personas.filter((p) => p.status === 'archived').length;

  const personaCols: Column<Persona>[] = [
    { key: 'persona_name', header: 'Persona', render: (r: any) => <span className="font-medium">{r.persona_name}</span> },
    { key: 'persona_role', header: 'Role', render: (r: any) => <span className="uppercase text-xs tracking-wide">{r.persona_role}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'pain_points_md', header: 'Pain Points', render: (r: any) => <span className="text-sm text-gray-700">{clip(r.pain_points_md, 80)}</span> },
    { key: 'motivators_md', header: 'Motivators', render: (r: any) => <span className="text-sm text-gray-700">{clip(r.motivators_md, 80)}</span> },
    { key: 'common_objections_md', header: 'Objections', render: (r: any) => <span className="text-sm text-gray-700">{clip(r.common_objections_md, 80)}</span> },
    { key: 'updated_at', header: 'Updated', render: (r: any) => <span className="text-xs text-gray-500">{fmt(r.updated_at)}</span> },
  ];

  const roleCols: Column<RoleRow>[] = [
    { key: 'persona_role', header: 'Role', render: (r: any) => <span className="font-medium uppercase">{r.persona_role}</span> },
    { key: 'total_count', header: 'Total', render: (r: any) => <span>{r.total_count}</span> },
    { key: 'active_count', header: 'Active', render: (r: any) => <span>{r.active_count}</span> },
  ];

  const changeCols: Column<ChangeRow>[] = [
    { key: 'change_at', header: 'When', render: (r: any) => <span className="text-xs text-gray-500">{fmt(r.change_at)}</span> },
    { key: 'persona_name', header: 'Persona', render: (r: any) => <span className="font-medium">{r.persona_name}</span> },
    { key: 'persona_role', header: 'Role', render: (r: any) => <span className="uppercase text-xs">{r.persona_role}</span> },
    { key: 'change_type', header: 'Type', render: (r: any) => <span className="text-xs">{r.change_type}</span> },
    { key: 'change_text', header: 'Change', render: (r: any) => <span className="text-sm text-gray-700">{clip(r.change_text, 120)}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <div className="text-xs uppercase tracking-wider text-gray-500">Founder Console &gt; r1886</div>
        <h1 className="text-2xl font-semibold">Customer Persona Library</h1>
        <p className="text-sm text-gray-600">
          Decision-maker archetypes across hospital buyers & clinic owners. Track pains, motivators, objections,
          and persona evolution over time.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total</div>
          <div className="text-2xl font-semibold">{totalPersonas}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Active</div>
          <div className="text-2xl font-semibold">{activePersonas}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Under Review</div>
          <div className="text-2xl font-semibold">{reviewPersonas}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Archived</div>
          <div className="text-2xl font-semibold">{archivedPersonas}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Role Distribution</h2>
        <p className="text-sm text-gray-600">Which decision-maker roles dominate the library — sorted by total persona count.</p>
        <DataTable
          rows={roles}
          columns={roleCols}
          rowKey={(r: any, i: number) => String(r.persona_role ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Persona Library</h2>
        <p className="text-sm text-gray-600">Full set of personas. Click into evolution log for change history per persona.</p>
        <DataTable
          rows={personas}
          columns={personaCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Evolution Changes</h2>
        <p className="text-sm text-gray-600">Last 50 logged shifts in pain points, motivators, objections & role assignments.</p>
        <DataTable
          rows={changes}
          columns={changeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
