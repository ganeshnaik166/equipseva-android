import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Candidate = {
  hospital_user_id: string;
  hospital_name: string | null;
  state: string | null;
  active_amcs: number | null;
  current_tier: string | null;
  current_categories: string[] | null;
  ltm_repair_spend_rupees: number | null;
  jobs_ltm: number | null;
  avg_rating: number | null;
  upgrade_signal_score: number | null;
};

type Play = {
  id: string;
  hospital_user_id: string;
  hospital_name: string | null;
  play_kind: string;
  current_tier: string | null;
  target_tier: string | null;
  monthly_uplift_rupees: number | null;
  confidence_score: number | null;
  status: string;
  created_at: string;
};

type ActionRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string | null;
  action_kind: string;
  due_date: string;
  priority: number;
  done: boolean;
  notes: string | null;
  created_at: string;
};

type Summary = {
  candidate_hospitals: number | null;
  open_plays: number | null;
  pipeline_monthly_uplift_rupees: number | null;
  won_monthly_uplift_rupees: number | null;
  open_actions: number | null;
  overdue_actions: number | null;
};

function money(v: number | null | undefined): string {
  const n = v ?? 0;
  return 'Rs ' + Math.round(n).toLocaleString('en-IN');
}

export default async function FounderHospitalExpansionExistingPage() {
  const sb = await getSupabaseServerClient();

  const candRes = await sb.rpc('founder_hospital_expansion_existing_candidates');
  const playsRes = await sb.rpc('founder_hospital_expansion_existing_plays_list');
  const queueRes = await sb.rpc('founder_hospital_expansion_existing_action_queue');
  const summaryRes = await sb.rpc('founder_hospital_expansion_existing_summary');

  const candidates: Candidate[] = (candRes.data as Candidate[] | null) ?? [];
  const plays: Play[] = (playsRes.data as Play[] | null) ?? [];
  const queue: ActionRow[] = (queueRes.data as ActionRow[] | null) ?? [];
  const summary: Summary = ((summaryRes.data as Summary[] | null)?.[0]) ?? {
    candidate_hospitals: 0,
    open_plays: 0,
    pipeline_monthly_uplift_rupees: 0,
    won_monthly_uplift_rupees: 0,
    open_actions: 0,
    overdue_actions: 0,
  };

  const candCols: Column<Candidate>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'state', header: 'State', render: (r) => r.state ?? '—' },
    { key: 'active_amcs', header: 'Active AMCs', render: (r) => String(r.active_amcs ?? 0) },
    { key: 'current_tier', header: 'Tier', render: (r) => r.current_tier ?? '—' },
    { key: 'current_categories', header: 'Categories', render: (r) => (r.current_categories ?? []).join(', ') || '—' },
    { key: 'ltm_repair_spend_rupees', header: 'LTM repair spend', render: (r) => money(r.ltm_repair_spend_rupees) },
    { key: 'jobs_ltm', header: 'Jobs LTM', render: (r) => String(r.jobs_ltm ?? 0) },
    { key: 'avg_rating', header: 'Avg rating', render: (r) => (r.avg_rating ?? 0).toFixed(2) },
    { key: 'upgrade_signal_score', header: 'Signal score', render: (r) => (r.upgrade_signal_score ?? 0).toFixed(1) },
  ];

  const playCols: Column<Play>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'play_kind', header: 'Play', render: (r) => r.play_kind },
    { key: 'current_tier', header: 'From', render: (r) => r.current_tier ?? '—' },
    { key: 'target_tier', header: 'To', render: (r) => r.target_tier ?? '—' },
    { key: 'monthly_uplift_rupees', header: 'Monthly uplift', render: (r) => money(r.monthly_uplift_rupees) },
    { key: 'confidence_score', header: 'Confidence', render: (r) => (r.confidence_score ?? 0).toFixed(0) + '%' },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'created_at', header: 'Created', render: (r) => new Date(r.created_at).toLocaleDateString('en-IN') },
  ];

  const queueCols: Column<ActionRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'action_kind', header: 'Action', render: (r) => r.action_kind },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date },
    { key: 'priority', header: 'Priority', render: (r) => 'P' + String(r.priority) },
    { key: 'done', header: 'Status', render: (r) => (r.done ? 'done' : 'open') },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Expansion (Existing AMC base)</h1>
        <p className="text-sm text-gray-600">
          Upsell candidates from current AMC base, per-hospital playbook, founder action queue.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Candidate hospitals</div>
          <div className="text-xl font-semibold">{summary.candidate_hospitals ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open plays</div>
          <div className="text-xl font-semibold">{summary.open_plays ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Pipeline uplift / mo</div>
          <div className="text-xl font-semibold">{money(summary.pipeline_monthly_uplift_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Won uplift / mo</div>
          <div className="text-xl font-semibold">{money(summary.won_monthly_uplift_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open actions</div>
          <div className="text-xl font-semibold">{summary.open_actions ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Overdue</div>
          <div className="text-xl font-semibold">{summary.overdue_actions ?? 0}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Upsell candidates</h2>
        <DataTable<Candidate>
          rowKey={(r) => r.hospital_user_id}
          columns={candCols}
          rows={candidates}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Active expansion plays</h2>
        <DataTable<Play>
          rowKey={(r) => r.id}
          columns={playCols}
          rows={plays}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Founder action queue</h2>
        <DataTable<ActionRow>
          rowKey={(r) => r.id}
          columns={queueCols}
          rows={queue}
        />
      </section>
    </div>
  );
}
