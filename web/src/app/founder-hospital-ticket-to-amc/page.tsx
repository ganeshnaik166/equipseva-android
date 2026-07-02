import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_open_targets: number;
  total_contacted: number;
  total_won: number;
  total_lost: number;
  pipeline_monthly_fee_rupees: number;
  median_likelihood: number;
  high_likelihood_count: number;
};

type TargetRow = {
  id: string;
  hospital_org_id: string;
  hospital_name: string | null;
  hospital_state: string | null;
  repair_ticket_count: number;
  repair_spend_rupees: number;
  distinct_equipment_categories: number;
  avg_hospital_rating: number | null;
  likelihood_score: number;
  proposed_amc_tier: string | null;
  proposed_monthly_fee_rupees: number | null;
  status: string;
  founder_note: string | null;
  created_at: string;
};

type TierRow = {
  proposed_amc_tier: string;
  target_count: number;
  open_count: number;
  contacted_count: number;
  won_count: number;
  monthly_fee_pipeline_rupees: number;
};

type OutreachRow = {
  id: string;
  target_id: string;
  hospital_name: string | null;
  channel: string;
  outcome: string;
  notes: string | null;
  created_at: string;
};

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function FounderHospitalTicketToAmcPage() {
  const sb = await getSupabaseServerClient();

  const kpisRes = await sb.rpc('founder_hospital_t2a_kpis');
  const targetsRes = await sb.rpc('founder_hospital_t2a_list_targets', { p_limit: 100 });
  const tierRes = await sb.rpc('founder_hospital_t2a_tier_breakdown');
  const outreachRes = await sb.rpc('founder_hospital_t2a_outreach_history', { p_limit: 50 });

  const kpis: Kpis | null = (kpisRes.data as Kpis[] | null)?.[0] ?? null;
  const targets: TargetRow[] = (targetsRes.data as TargetRow[] | null) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[] | null) ?? [];
  const outreach: OutreachRow[] = (outreachRes.data as OutreachRow[] | null) ?? [];

  const targetCols: Column<TargetRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'hospital_state', header: 'State', render: (r) => r.hospital_state ?? '—' },
    { key: 'repair_ticket_count', header: 'Tickets (90d)', render: (r) => String(r.repair_ticket_count ?? 0) },
    { key: 'repair_spend_rupees', header: 'Spend (90d)', render: (r) => rupees(r.repair_spend_rupees) },
    { key: 'distinct_equipment_categories', header: 'Categories', render: (r) => String(r.distinct_equipment_categories ?? 0) },
    { key: 'avg_hospital_rating', header: 'Avg rating', render: (r) => r.avg_hospital_rating !== null && r.avg_hospital_rating !== undefined ? Number(r.avg_hospital_rating).toFixed(2) : '—' },
    { key: 'likelihood_score', header: 'Likelihood', render: (r) => (r.likelihood_score ?? 0) + ' / 100' },
    { key: 'proposed_amc_tier', header: 'Tier', render: (r) => r.proposed_amc_tier ?? '—' },
    { key: 'proposed_monthly_fee_rupees', header: 'Proposed AMC fee/mo', render: (r) => rupees(r.proposed_monthly_fee_rupees) },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'founder_note', header: 'Note', render: (r) => r.founder_note ?? '—' },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'proposed_amc_tier', header: 'Tier', render: (r) => r.proposed_amc_tier ?? '—' },
    { key: 'target_count', header: 'Targets', render: (r) => String(r.target_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count ?? 0) },
    { key: 'contacted_count', header: 'Contacted', render: (r) => String(r.contacted_count ?? 0) },
    { key: 'won_count', header: 'Won', render: (r) => String(r.won_count ?? 0) },
    { key: 'monthly_fee_pipeline_rupees', header: 'Pipeline fee/mo', render: (r) => rupees(r.monthly_fee_pipeline_rupees) },
  ];

  const outreachCols: Column<OutreachRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'channel', header: 'Channel', render: (r) => r.channel ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
    { key: 'created_at', header: 'At', render: (r) => r.created_at ? new Date(r.created_at).toLocaleString() : '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-wider text-neutral-500">Revenue · r1644</p>
        <h1 className="text-2xl font-semibold">Hospital Ticket-to-AMC Funnel</h1>
        <p className="text-sm text-neutral-600 max-w-2xl">
          Hospitals burning cash on one-off repair tickets that would be cheaper served by AMC. Each row is scored on volume,
          spend, category breadth and rating. Work the high-likelihood rows first.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-neutral-500">Open targets</div>
          <div className="text-xl font-semibold">{kpis?.total_open_targets ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-neutral-500">Contacted</div>
          <div className="text-xl font-semibold">{kpis?.total_contacted ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-neutral-500">Won / Lost</div>
          <div className="text-xl font-semibold">{(kpis?.total_won ?? 0)} / {(kpis?.total_lost ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-neutral-500">Pipeline fee/mo</div>
          <div className="text-xl font-semibold">{rupees(kpis?.pipeline_monthly_fee_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-neutral-500">Median likelihood</div>
          <div className="text-xl font-semibold">{kpis?.median_likelihood ?? 0}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-neutral-500">High-likelihood (≥70)</div>
          <div className="text-xl font-semibold">{kpis?.high_likelihood_count ?? 0}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pipeline by proposed tier</h2>
        <DataTable<TierRow>
          rows={tiers}
          columns={tierCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Conversion targets</h2>
        <p className="text-sm text-neutral-600">
          Call <code className="px-1 bg-neutral-100 rounded">founder_hospital_t2a_rebuild</code> to refresh from the last 90 days of repair_jobs.
          Use <code className="px-1 bg-neutral-100 rounded">founder_hospital_t2a_log_outreach</code> to record calls and roll status forward.
        </p>
        <DataTable<TargetRow>
          rows={targets}
          columns={targetCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent outreach</h2>
        <DataTable<OutreachRow>
          rows={outreach}
          columns={outreachCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
