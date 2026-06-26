import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_invoices: number;
  total_invoiced_rupees: number;
  total_cleared_rupees: number;
  clearance_rate: number | null;
  disputed_count: number;
  avg_days: number | null;
};

type MethodRow = {
  payment_method: string;
  invoice_count: number;
  total_rupees: number;
  avg_days: number | null;
  clearance_rate: number | null;
};

type LeaderboardRow = {
  engineer_code: string;
  engineer_name: string;
  tier: string;
  invoices_issued: number;
  total_cleared_rupees: number;
  conversion_pct: number | null;
  avg_collection_days: number | null;
  tenure_months: number;
};

type OutcomeRow = {
  outcome: string;
  invoice_count: number;
  rupees_at_stake: number;
  rupees_recovered: number;
};

type BucketRow = {
  bucket: string;
  invoice_count: number;
  total_rupees: number;
};

type DisputeRow = {
  invoice_number: string;
  engineer_name: string;
  customer_org: string;
  invoice_amount_rupees: number;
  collection_days: number;
  outcome: string;
  notes: string | null;
};

type TierRow = {
  tier: string;
  engineer_count: number;
  total_cleared_rupees: number;
  avg_tenure_months: number | null;
  avg_days: number | null;
};

type RecentRow = {
  invoice_number: string;
  engineer_name: string;
  customer_org: string;
  invoice_amount_rupees: number;
  cleared_amount_rupees: number;
  payment_method: string;
  collection_days: number;
  outcome: string;
  issued_at: string;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, methodRes, leaderRes, outcomeRes, bucketRes, disputeRes, tierRes, recentRes] = await Promise.all([
    supabase.rpc('r2844_collection_summary'),
    supabase.rpc('r2844_by_payment_method'),
    supabase.rpc('r2844_engineer_leaderboard'),
    supabase.rpc('r2844_dispute_outcomes'),
    supabase.rpc('r2844_collection_days_buckets'),
    supabase.rpc('r2844_open_disputes'),
    supabase.rpc('r2844_tier_breakdown'),
    supabase.rpc('r2844_recent_invoices'),
  ]);

  const summary: SummaryRow | null = (summaryRes.data as SummaryRow[] | null)?.[0] ?? null;
  const methods: MethodRow[] = (methodRes.data as MethodRow[] | null) ?? [];
  const leaders: LeaderboardRow[] = (leaderRes.data as LeaderboardRow[] | null) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[] | null) ?? [];
  const buckets: BucketRow[] = (bucketRes.data as BucketRow[] | null) ?? [];
  const disputes: DisputeRow[] = (disputeRes.data as DisputeRow[] | null) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[] | null) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[] | null) ?? [];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Customer Monthly Engineer Payment Collection Conversion</h1>
        <p className="text-sm text-neutral-600">
          Engineer-led invoice collection across method, days outstanding, disputes &amp; cleared outcomes. Lower days &amp;
          higher cleared rupees =&gt; stronger collection conversion.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-neutral-500">Total invoices</div>
          <div className="mt-1 text-2xl font-semibold">{summary?.total_invoices ?? 0}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-neutral-500">Invoiced (rupees)</div>
          <div className="mt-1 text-2xl font-semibold">{rupees(summary?.total_invoiced_rupees)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-neutral-500">Cleared (rupees)</div>
          <div className="mt-1 text-2xl font-semibold">{rupees(summary?.total_cleared_rupees)}</div>
          <div className="mt-1 text-xs text-neutral-500">Clearance {pct(summary?.clearance_rate)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-neutral-500">Disputes / avg days</div>
          <div className="mt-1 text-2xl font-semibold">
            {summary?.disputed_count ?? 0} / {summary?.avg_days ?? '-'}
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">By payment method</h2>
        <DataTable
          rows={methods}
          columns={[
            { key: 'payment_method', header: 'Method', render: (r: MethodRow) => r.payment_method },
            { key: 'invoice_count', header: 'Invoices', render: (r: MethodRow) => r.invoice_count },
            { key: 'total_rupees', header: 'Total', render: (r: MethodRow) => rupees(r.total_rupees) },
            { key: 'avg_days', header: 'Avg days', render: (r: MethodRow) => r.avg_days ?? '-' },
            { key: 'clearance_rate', header: 'Clearance', render: (r: MethodRow) => pct(r.clearance_rate) },
          ]}
          emptyMessage="No data"
          rowKey={(r: MethodRow, i: number) => String(r.payment_method ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Engineer leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: LeaderboardRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: LeaderboardRow) => r.engineer_name },
            { key: 'tier', header: 'Tier', render: (r: LeaderboardRow) => r.tier },
            { key: 'invoices_issued', header: 'Issued', render: (r: LeaderboardRow) => r.invoices_issued },
            { key: 'total_cleared_rupees', header: 'Cleared', render: (r: LeaderboardRow) => rupees(r.total_cleared_rupees) },
            { key: 'conversion_pct', header: 'Conv %', render: (r: LeaderboardRow) => pct(r.conversion_pct) },
            { key: 'avg_collection_days', header: 'Avg days', render: (r: LeaderboardRow) => r.avg_collection_days ?? '-' },
            { key: 'tenure_months', header: 'Tenure (mo)', render: (r: LeaderboardRow) => r.tenure_months },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderboardRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Outcome mix</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'invoice_count', header: 'Invoices', render: (r: OutcomeRow) => r.invoice_count },
              { key: 'rupees_at_stake', header: 'At stake', render: (r: OutcomeRow) => rupees(r.rupees_at_stake) },
              { key: 'rupees_recovered', header: 'Recovered', render: (r: OutcomeRow) => rupees(r.rupees_recovered) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Collection days buckets</h2>
          <DataTable
            rows={buckets}
            columns={[
              { key: 'bucket', header: 'Bucket', render: (r: BucketRow) => r.bucket },
              { key: 'invoice_count', header: 'Invoices', render: (r: BucketRow) => r.invoice_count },
              { key: 'total_rupees', header: 'Total', render: (r: BucketRow) => rupees(r.total_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: BucketRow, i: number) => String(r.bucket ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open disputes</h2>
        <p className="text-sm text-neutral-600">
          Invoices flagged for dispute — recover &gt;= 50% target before write-off.
        </p>
        <DataTable
          rows={disputes}
          columns={[
            { key: 'invoice_number', header: 'Invoice', render: (r: DisputeRow) => r.invoice_number },
            { key: 'engineer_name', header: 'Engineer', render: (r: DisputeRow) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: DisputeRow) => r.customer_org },
            { key: 'invoice_amount_rupees', header: 'Amount', render: (r: DisputeRow) => rupees(r.invoice_amount_rupees) },
            { key: 'collection_days', header: 'Days', render: (r: DisputeRow) => r.collection_days },
            { key: 'outcome', header: 'Outcome', render: (r: DisputeRow) => r.outcome },
            { key: 'notes', header: 'Notes', render: (r: DisputeRow) => r.notes ?? '-' },
          ]}
          emptyMessage="No open disputes"
          rowKey={(r: DisputeRow, i: number) => String(r.invoice_number ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Tier breakdown</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: TierRow) => r.tier },
            { key: 'engineer_count', header: 'Engineers', render: (r: TierRow) => r.engineer_count },
            { key: 'total_cleared_rupees', header: 'Cleared', render: (r: TierRow) => rupees(r.total_cleared_rupees) },
            { key: 'avg_tenure_months', header: 'Avg tenure', render: (r: TierRow) => r.avg_tenure_months ?? '-' },
            { key: 'avg_days', header: 'Avg days', render: (r: TierRow) => r.avg_days ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.tier ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent invoices</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'invoice_number', header: 'Invoice', render: (r: RecentRow) => r.invoice_number },
            { key: 'engineer_name', header: 'Engineer', render: (r: RecentRow) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: RecentRow) => r.customer_org },
            { key: 'invoice_amount_rupees', header: 'Amount', render: (r: RecentRow) => rupees(r.invoice_amount_rupees) },
            { key: 'cleared_amount_rupees', header: 'Cleared', render: (r: RecentRow) => rupees(r.cleared_amount_rupees) },
            { key: 'payment_method', header: 'Method', render: (r: RecentRow) => r.payment_method },
            { key: 'collection_days', header: 'Days', render: (r: RecentRow) => r.collection_days },
            { key: 'outcome', header: 'Outcome', render: (r: RecentRow) => r.outcome },
            { key: 'issued_at', header: 'Issued', render: (r: RecentRow) => r.issued_at },
          ]}
          emptyMessage="No invoices"
          rowKey={(r: RecentRow, i: number) => String(r.invoice_number ?? i)}
        />
      </section>
    </main>
  );
}
