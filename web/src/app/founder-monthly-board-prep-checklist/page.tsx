import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_items: number;
  board_ready_items: number;
  blocked_items: number;
  overdue_items: number;
  avg_completion_pct: number;
  p0_open: number;
  evidence_submitted: number;
  evidence_approved: number;
};

type Item = {
  id: string;
  item_code: string;
  item_title: string;
  category: string;
  owner_role: string;
  status: string;
  priority: string;
  due_date: string;
  completion_pct: number;
  depends_on_code: string | null;
  is_board_ready: boolean;
  notes: string | null;
};

type CategoryRow = { category: string; total: number; ready: number; blocked: number; avg_pct: number };
type OwnerRow = { owner_role: string; total: number; open_items: number; p0_open: number; avg_pct: number };
type DepRow = { blocker_code: string; blocker_status: string; blocker_pct: number; blocked_code: string; blocked_status: string };
type EvidenceRow = { item_code: string; evidence_type: string; evidence_label: string; submitted_by: string; submitted_at: string; approved: boolean; review_notes: string | null };
type OverdueRow = { item_code: string; item_title: string; owner_role: string; due_date: string; days_overdue: number; status: string; priority: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, itemsRes, catRes, ownerRes, depRes, evRes, overdueRes] = await Promise.all([
    supabase.rpc('fn_r2749_board_prep_kpis'),
    supabase.rpc('fn_r2749_list_items'),
    supabase.rpc('fn_r2749_category_breakdown'),
    supabase.rpc('fn_r2749_owner_load'),
    supabase.rpc('fn_r2749_dependency_chain'),
    supabase.rpc('fn_r2749_evidence_log'),
    supabase.rpc('fn_r2749_overdue_items'),
  ]);

  const kpis: Kpis | null = (kpisRes.data as Kpis[] | null)?.[0] ?? null;
  const items: Item[] = (itemsRes.data as Item[] | null) ?? [];
  const cats: CategoryRow[] = (catRes.data as CategoryRow[] | null) ?? [];
  const owners: OwnerRow[] = (ownerRes.data as OwnerRow[] | null) ?? [];
  const deps: DepRow[] = (depRes.data as DepRow[] | null) ?? [];
  const evidence: EvidenceRow[] = (evRes.data as EvidenceRow[] | null) ?? [];
  const overdue: OverdueRow[] = (overdueRes.data as OverdueRow[] | null) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Founder Monthly Board Prep Checklist</h1>
        <p className="text-sm text-gray-600">
          Round r2749 · item × owner × status × evidence × dependency × completion × board ready
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total items" value={kpis?.total_items ?? 0} />
        <KpiCard label="Board ready" value={kpis?.board_ready_items ?? 0} tone="good" />
        <KpiCard label="Blocked" value={kpis?.blocked_items ?? 0} tone="warn" />
        <KpiCard label="Overdue" value={kpis?.overdue_items ?? 0} tone="bad" />
        <KpiCard label="Avg completion %" value={kpis?.avg_completion_pct ?? 0} />
        <KpiCard label="P0 still open" value={kpis?.p0_open ?? 0} tone="warn" />
        <KpiCard label="Evidence submitted" value={kpis?.evidence_submitted ?? 0} />
        <KpiCard label="Evidence approved" value={kpis?.evidence_approved ?? 0} tone="good" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Checklist items</h2>
        <DataTable<Item>
          rows={items}
          columns={[
            { key: 'item_code', header: 'Code', render: (r) => <span className="font-mono">{r.item_code}</span> },
            { key: 'item_title', header: 'Title', render: (r) => <span>{r.item_title}</span> },
            { key: 'category', header: 'Category', render: (r) => <span>{r.category}</span> },
            { key: 'owner_role', header: 'Owner', render: (r) => <span>{r.owner_role}</span> },
            { key: 'priority', header: 'Priority', render: (r) => <span className="uppercase">{r.priority}</span> },
            { key: 'status', header: 'Status', render: (r) => <span>{r.status}</span> },
            { key: 'completion_pct', header: 'Done %', render: (r) => <span>{r.completion_pct}%</span> },
            { key: 'due_date', header: 'Due', render: (r) => <span>{r.due_date}</span> },
            { key: 'depends_on_code', header: 'Depends on', render: (r) => <span>{r.depends_on_code ?? '—'}</span> },
            { key: 'is_board_ready', header: 'Ready', render: (r) => <span>{r.is_board_ready ? 'yes' : 'no'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Category breakdown</h2>
          <DataTable<CategoryRow>
            rows={cats}
            columns={[
              { key: 'category', header: 'Category', render: (r) => <span>{r.category}</span> },
              { key: 'total', header: 'Total', render: (r) => <span>{r.total}</span> },
              { key: 'ready', header: 'Ready', render: (r) => <span>{r.ready}</span> },
              { key: 'blocked', header: 'Blocked', render: (r) => <span>{r.blocked}</span> },
              { key: 'avg_pct', header: 'Avg %', render: (r) => <span>{r.avg_pct}%</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.category ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Owner load</h2>
          <DataTable<OwnerRow>
            rows={owners}
            columns={[
              { key: 'owner_role', header: 'Owner', render: (r) => <span>{r.owner_role}</span> },
              { key: 'total', header: 'Total', render: (r) => <span>{r.total}</span> },
              { key: 'open_items', header: 'Open', render: (r) => <span>{r.open_items}</span> },
              { key: 'p0_open', header: 'P0 open', render: (r) => <span>{r.p0_open}</span> },
              { key: 'avg_pct', header: 'Avg %', render: (r) => <span>{r.avg_pct}%</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.owner_role ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dependency chain (blockers → blocked)</h2>
        <DataTable<DepRow>
          rows={deps}
          columns={[
            { key: 'blocker_code', header: 'Blocker', render: (r) => <span className="font-mono">{r.blocker_code}</span> },
            { key: 'blocker_status', header: 'Blocker status', render: (r) => <span>{r.blocker_status}</span> },
            { key: 'blocker_pct', header: 'Blocker %', render: (r) => <span>{r.blocker_pct}%</span> },
            { key: 'blocked_code', header: 'Blocked', render: (r) => <span className="font-mono">{r.blocked_code}</span> },
            { key: 'blocked_status', header: 'Blocked status', render: (r) => <span>{r.blocked_status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => `${r.blocker_code}-${r.blocked_code}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue items (due &lt; today &amp; not approved)</h2>
        <DataTable<OverdueRow>
          rows={overdue}
          columns={[
            { key: 'item_code', header: 'Code', render: (r) => <span className="font-mono">{r.item_code}</span> },
            { key: 'item_title', header: 'Title', render: (r) => <span>{r.item_title}</span> },
            { key: 'owner_role', header: 'Owner', render: (r) => <span>{r.owner_role}</span> },
            { key: 'priority', header: 'Priority', render: (r) => <span>{r.priority}</span> },
            { key: 'due_date', header: 'Due', render: (r) => <span>{r.due_date}</span> },
            { key: 'days_overdue', header: 'Days overdue', render: (r) => <span>{r.days_overdue}</span> },
            { key: 'status', header: 'Status', render: (r) => <span>{r.status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => `${r.item_code}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Evidence log</h2>
        <DataTable<EvidenceRow>
          rows={evidence}
          columns={[
            { key: 'item_code', header: 'Item', render: (r) => <span className="font-mono">{r.item_code}</span> },
            { key: 'evidence_type', header: 'Type', render: (r) => <span>{r.evidence_type}</span> },
            { key: 'evidence_label', header: 'Label', render: (r) => <span>{r.evidence_label}</span> },
            { key: 'submitted_by', header: 'Submitted by', render: (r) => <span>{r.submitted_by}</span> },
            { key: 'submitted_at', header: 'Submitted at', render: (r) => <span>{new Date(r.submitted_at).toLocaleString()}</span> },
            { key: 'approved', header: 'Approved', render: (r) => <span>{r.approved ? 'yes' : 'no'}</span> },
            { key: 'review_notes', header: 'Notes', render: (r) => <span>{r.review_notes ?? '—'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => `${r.item_code}-${r.evidence_label}-${i}`}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: number | string; tone?: 'good' | 'warn' | 'bad' }) {
  const toneClass =
    tone === 'good' ? 'border-green-500 text-green-700'
    : tone === 'warn' ? 'border-amber-500 text-amber-700'
    : tone === 'bad' ? 'border-red-500 text-red-700'
    : 'border-gray-300 text-gray-800';
  return (
    <div className={`border-2 rounded-lg p-4 bg-white ${toneClass}`}>
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}
