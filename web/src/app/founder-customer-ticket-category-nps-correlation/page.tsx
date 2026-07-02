import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MatrixRow = {
  ticket_category: string;
  hospital_tier: string;
  sample_count: number;
  avg_nps_delta: number;
  avg_nps_before: number;
  avg_nps_after: number;
  total_tickets: number;
};

type WorstCatRow = {
  ticket_category: string;
  sample_count: number;
  avg_nps_delta: number;
  worst_tier: string | null;
  worst_tier_delta: number | null;
};

type TierRow = {
  hospital_tier: string;
  sample_count: number;
  avg_nps_delta: number;
  total_tickets: number;
  hospitals_sampled: number;
};

type SampleRow = {
  id: string;
  hospital_email: string | null;
  hospital_tier: string;
  ticket_category: string;
  ticket_count_30d: number;
  nps_before: number | null;
  nps_after: number | null;
  nps_delta: number;
  sampled_at: string;
  notes: string | null;
};

type ActionRow = {
  id: string;
  ticket_category: string;
  hospital_tier: string | null;
  action_title: string;
  action_owner: string;
  status: string;
  expected_nps_lift: number | null;
  notes: string | null;
  created_at: string;
};

type BottomQuartileRow = {
  ticket_category: string;
  hospital_tier: string;
  hospital_email: string | null;
  ticket_count_30d: number;
  nps_delta: number;
  sampled_at: string;
};

type HeadlineRow = {
  total_samples: number;
  total_hospitals: number;
  avg_nps_delta: number;
  worst_category: string | null;
  worst_category_delta: number | null;
  worst_tier: string | null;
  worst_tier_delta: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    headlineRes,
    matrixRes,
    worstCatRes,
    tierRes,
    samplesRes,
    actionsRes,
    bottomRes,
  ] = await Promise.all([
    supabase.rpc('founder_ticket_nps_headline_r2384'),
    supabase.rpc('founder_ticket_nps_matrix_r2384'),
    supabase.rpc('founder_ticket_nps_worst_categories_r2384'),
    supabase.rpc('founder_ticket_nps_tier_breakdown_r2384'),
    supabase.rpc('founder_ticket_nps_recent_samples_r2384', { p_limit: 50 }),
    supabase.rpc('founder_ticket_nps_actions_r2384'),
    supabase.rpc('founder_ticket_nps_bottom_quartile_r2384'),
  ]);

  const headline: HeadlineRow | null = (headlineRes.data as HeadlineRow[] | null)?.[0] ?? null;
  const matrix: MatrixRow[] = (matrixRes.data as MatrixRow[] | null) ?? [];
  const worstCats: WorstCatRow[] = (worstCatRes.data as WorstCatRow[] | null) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[] | null) ?? [];
  const samples: SampleRow[] = (samplesRes.data as SampleRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const bottom: BottomQuartileRow[] = (bottomRes.data as BottomQuartileRow[] | null) ?? [];

  const matrixColumns: Column<any>[] = [
    { key: 'ticket_category', header: 'Category', render: (r: MatrixRow) => r.ticket_category },
    { key: 'hospital_tier', header: 'Tier', render: (r: MatrixRow) => r.hospital_tier },
    { key: 'sample_count', header: 'Samples', render: (r: MatrixRow) => String(r.sample_count) },
    { key: 'avg_nps_delta', header: 'Avg NPS Δ', render: (r: MatrixRow) => String(r.avg_nps_delta) },
    { key: 'avg_nps_before', header: 'Before', render: (r: MatrixRow) => String(r.avg_nps_before) },
    { key: 'avg_nps_after', header: 'After', render: (r: MatrixRow) => String(r.avg_nps_after) },
    { key: 'total_tickets', header: 'Tickets 30d', render: (r: MatrixRow) => String(r.total_tickets) },
  ];

  const worstCatColumns: Column<any>[] = [
    { key: 'ticket_category', header: 'Category', render: (r: WorstCatRow) => r.ticket_category },
    { key: 'sample_count', header: 'Samples', render: (r: WorstCatRow) => String(r.sample_count) },
    { key: 'avg_nps_delta', header: 'Avg NPS Δ', render: (r: WorstCatRow) => String(r.avg_nps_delta) },
    { key: 'worst_tier', header: 'Worst tier', render: (r: WorstCatRow) => r.worst_tier ?? '-' },
    { key: 'worst_tier_delta', header: 'Worst tier Δ', render: (r: WorstCatRow) => r.worst_tier_delta == null ? '-' : String(r.worst_tier_delta) },
  ];

  const tierColumns: Column<any>[] = [
    { key: 'hospital_tier', header: 'Tier', render: (r: TierRow) => r.hospital_tier },
    { key: 'sample_count', header: 'Samples', render: (r: TierRow) => String(r.sample_count) },
    { key: 'avg_nps_delta', header: 'Avg NPS Δ', render: (r: TierRow) => String(r.avg_nps_delta) },
    { key: 'total_tickets', header: 'Tickets 30d', render: (r: TierRow) => String(r.total_tickets) },
    { key: 'hospitals_sampled', header: 'Hospitals', render: (r: TierRow) => String(r.hospitals_sampled) },
  ];

  const sampleColumns: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: SampleRow) => r.hospital_email ?? '-' },
    { key: 'hospital_tier', header: 'Tier', render: (r: SampleRow) => r.hospital_tier },
    { key: 'ticket_category', header: 'Category', render: (r: SampleRow) => r.ticket_category },
    { key: 'ticket_count_30d', header: 'Tickets 30d', render: (r: SampleRow) => String(r.ticket_count_30d) },
    { key: 'nps_before', header: 'NPS before', render: (r: SampleRow) => r.nps_before == null ? '-' : String(r.nps_before) },
    { key: 'nps_after', header: 'NPS after', render: (r: SampleRow) => r.nps_after == null ? '-' : String(r.nps_after) },
    { key: 'nps_delta', header: 'NPS Δ', render: (r: SampleRow) => String(r.nps_delta) },
    { key: 'sampled_at', header: 'Sampled', render: (r: SampleRow) => new Date(r.sampled_at).toLocaleDateString() },
    { key: 'notes', header: 'Notes', render: (r: SampleRow) => r.notes ?? '-' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'ticket_category', header: 'Category', render: (r: ActionRow) => r.ticket_category },
    { key: 'hospital_tier', header: 'Tier', render: (r: ActionRow) => r.hospital_tier ?? 'all' },
    { key: 'action_title', header: 'Action', render: (r: ActionRow) => r.action_title },
    { key: 'action_owner', header: 'Owner', render: (r: ActionRow) => r.action_owner },
    { key: 'status', header: 'Status', render: (r: ActionRow) => r.status },
    { key: 'expected_nps_lift', header: 'Expected lift', render: (r: ActionRow) => r.expected_nps_lift == null ? '-' : `+${r.expected_nps_lift}` },
    { key: 'notes', header: 'Notes', render: (r: ActionRow) => r.notes ?? '-' },
    { key: 'created_at', header: 'Created', render: (r: ActionRow) => new Date(r.created_at).toLocaleDateString() },
  ];

  const bottomColumns: Column<any>[] = [
    { key: 'ticket_category', header: 'Category', render: (r: BottomQuartileRow) => r.ticket_category },
    { key: 'hospital_tier', header: 'Tier', render: (r: BottomQuartileRow) => r.hospital_tier },
    { key: 'hospital_email', header: 'Hospital', render: (r: BottomQuartileRow) => r.hospital_email ?? '-' },
    { key: 'ticket_count_30d', header: 'Tickets 30d', render: (r: BottomQuartileRow) => String(r.ticket_count_30d) },
    { key: 'nps_delta', header: 'NPS Δ', render: (r: BottomQuartileRow) => String(r.nps_delta) },
    { key: 'sampled_at', header: 'Sampled', render: (r: BottomQuartileRow) => new Date(r.sampled_at).toLocaleDateString() },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Ticket category vs NPS correlation</h1>
        <p className="text-sm text-gray-600">
          Does ticket category (delay / quality / billing) correlate with NPS drop — broken down by hospital tier.
        </p>
      </header>

      {headline && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Samples</div>
            <div className="text-xl font-semibold">{headline.total_samples}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Hospitals</div>
            <div className="text-xl font-semibold">{headline.total_hospitals}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Avg NPS Δ</div>
            <div className="text-xl font-semibold">{headline.avg_nps_delta}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Worst category</div>
            <div className="text-xl font-semibold">{headline.worst_category ?? '-'}</div>
            <div className="text-xs text-gray-500">
              {headline.worst_category_delta == null ? '' : `${headline.worst_category_delta} avg`}
            </div>
          </div>
        </section>
      )}

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Correlation matrix — category × tier</h2>
        <DataTable
          rows={matrix}
          columns={matrixColumns}
          emptyMessage="No correlation samples yet."
          rowKey={(r: MatrixRow) => `${r.ticket_category}-${r.hospital_tier}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Worst categories ranked</h2>
        <DataTable
          rows={worstCats}
          columns={worstCatColumns}
          emptyMessage="No category data."
          rowKey={(r: WorstCatRow) => r.ticket_category}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Tier breakdown</h2>
        <DataTable
          rows={tiers}
          columns={tierColumns}
          emptyMessage="No tier data."
          rowKey={(r: TierRow) => r.hospital_tier}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Bottom-quartile hospitals (per category)</h2>
        <p className="text-sm text-gray-600">Hospitals where NPS Δ is worst within each category — the ones pulling averages down.</p>
        <DataTable
          rows={bottom}
          columns={bottomColumns}
          emptyMessage="No bottom-quartile rows."
          rowKey={(r: BottomQuartileRow) => `${r.ticket_category}-${r.hospital_email}-${r.sampled_at}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent samples</h2>
        <DataTable
          rows={samples}
          columns={sampleColumns}
          emptyMessage="No samples yet."
          rowKey={(r: SampleRow) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Remediation actions</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No actions queued."
          rowKey={(r: ActionRow) => r.id}
        />
      </section>
    </div>
  );
}
