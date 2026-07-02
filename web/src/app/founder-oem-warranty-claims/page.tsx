import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-3">
      <div className="text-[11px] uppercase tracking-wide text-zinc-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-zinc-900">{value}</div>
    </div>
  );
}

export default async function FounderOemWarrantyClaimsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [overviewRes, byOemRes, byStatusRes, recentRes, staleRes, trendRes, topRes] = await Promise.all([
    supabase.rpc('founder_oem_warranty_overview_v2'),
    supabase.rpc('founder_oem_warranty_by_oem_v2'),
    supabase.rpc('founder_oem_warranty_by_status_v2'),
    supabase.rpc('founder_oem_warranty_recent_claims_v2'),
    supabase.rpc('founder_oem_warranty_stale_open_v2'),
    supabase.rpc('founder_oem_warranty_recovery_trend_v2'),
    supabase.rpc('founder_oem_warranty_top_recoveries_v2'),
  ]);

  const o: any = (overviewRes.data && overviewRes.data[0]) || {};
  const byOem: any[] = byOemRes.data || [];
  const byStatus: any[] = byStatusRes.data || [];
  const recent: any[] = recentRes.data || [];
  const stale: any[] = staleRes.data || [];
  const trend: any[] = trendRes.data || [];
  const top: any[] = topRes.data || [];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4">
      <div>
        <h1 className="text-2xl font-semibold text-zinc-900">OEM Warranty Claims Tracker</h1>
        <p className="text-sm text-zinc-600">Log claims to Siemens / GE / Philips, advance the status ladder, record recoveries, score OEMs.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total claims" value={o.total_claims ?? 0} />
        <Kpi label="Open" value={o.open_claims ?? 0} />
        <Kpi label="Closed" value={o.closed_claims ?? 0} />
        <Kpi label="Unique OEMs" value={o.unique_oems ?? 0} />
        <Kpi label="Claimed" value={formatRupees(Number(o.total_claimed_rupees ?? 0))} />
        <Kpi label="Recovered" value={formatRupees(Number(o.total_recovered_rupees ?? 0))} />
        <Kpi label="Recovery %" value={`${o.recovery_pct ?? 0}%`} />
        <Kpi label="Avg claim" value={formatRupees(Number(o.avg_claim_rupees ?? 0))} />
        <Kpi label="Approved" value={o.approved_count ?? 0} />
        <Kpi label="Rejected" value={o.rejected_count ?? 0} />
        <Kpi label="Pending review" value={o.pending_review ?? 0} />
        <Kpi label="Median days to close" value={o.median_days_to_close ?? 0} />
        <Kpi label="Recovered (30d count)" value={o.recovered_last_30d ?? 0} />
        <Kpi label="Recovered (30d amt)" value={formatRupees(Number(o.recovered_amount_30d ?? 0))} />
        <Kpi label="Largest open claim" value={formatRupees(Number(o.largest_open_claim ?? 0))} />
        <Kpi label="Oldest open (days)" value={o.oldest_open_age_days ?? 0} />
      </div>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-zinc-900">Per-OEM scorecard</h2>
        <DataTable
          rows={byOem}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? "—" },
            { key: 'total_claims', header: 'Total', render: (r: any) => r.total_claims ?? 0 },
            { key: 'open_claims', header: 'Open', render: (r: any) => r.open_claims ?? 0 },
            { key: 'approved', header: 'Approved', render: (r: any) => r.approved ?? 0 },
            { key: 'rejected', header: 'Rejected', render: (r: any) => r.rejected ?? 0 },
            { key: 'claimed_rupees', header: 'Claimed', render: (r: any) => formatRupees(Number(r.claimed_rupees ?? 0)) },
            { key: 'recovered_rupees', header: 'Recovered', render: (r: any) => formatRupees(Number(r.recovered_rupees ?? 0)) },
            { key: 'recovery_pct', header: 'Recovery %', render: (r: any) => `${r.recovery_pct ?? 0}%` },
            { key: 'score', header: 'Score', render: (r: any) => r.score ?? 0 },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-zinc-900">Status ladder breakdown</h2>
        <DataTable
          rows={byStatus}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
            { key: 'claim_count', header: 'Claims', render: (r: any) => r.claim_count ?? 0 },
            { key: 'claimed_rupees', header: 'Claimed', render: (r: any) => formatRupees(Number(r.claimed_rupees ?? 0)) },
            { key: 'recovered_rupees', header: 'Recovered', render: (r: any) => formatRupees(Number(r.recovered_rupees ?? 0)) },
            { key: 'avg_age_days', header: 'Avg age (days)', render: (r: any) => r.avg_age_days ?? 0 },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-zinc-900">Recent claims</h2>
        <DataTable
          rows={recent}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? "—" },
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
            { key: 'claimed_amount_rupees', header: 'Claimed', render: (r: any) => formatRupees(Number(r.claimed_amount_rupees ?? 0)) },
            { key: 'recovered_amount_rupees', header: 'Recovered', render: (r: any) => formatRupees(Number(r.recovered_amount_rupees ?? 0)) },
            { key: 'failure_summary', header: 'Failure', render: (r: any) => r.failure_summary ?? "—" },
            { key: 'claim_reference', header: 'Ref', render: (r: any) => r.claim_reference ?? "—" },
            { key: 'age_days', header: 'Age (d)', render: (r: any) => r.age_days ?? 0 },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-zinc-900">Stale open claims ({">"}14d)</h2>
        <DataTable
          rows={stale}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? "—" },
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
            { key: 'claimed_amount_rupees', header: 'Claimed', render: (r: any) => formatRupees(Number(r.claimed_amount_rupees ?? 0)) },
            { key: 'age_days', header: 'Age (d)', render: (r: any) => r.age_days ?? 0 },
            { key: 'last_event', header: 'Last event', render: (r: any) => r.last_event ?? "—" },
            { key: 'claim_reference', header: 'Ref', render: (r: any) => r.claim_reference ?? "—" },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-zinc-900">Recovery trend (12 weeks)</h2>
        <DataTable
          rows={trend}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ?? "—" },
            { key: 'claim_count', header: 'Claims', render: (r: any) => r.claim_count ?? 0 },
            { key: 'claimed_rupees', header: 'Claimed', render: (r: any) => formatRupees(Number(r.claimed_rupees ?? 0)) },
            { key: 'recovered_rupees', header: 'Recovered', render: (r: any) => formatRupees(Number(r.recovered_rupees ?? 0)) },
            { key: 'recovery_pct', header: 'Recovery %', render: (r: any) => `${r.recovery_pct ?? 0}%` },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold text-zinc-900">Top recoveries</h2>
        <DataTable
          rows={top}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'oem_name', header: 'OEM', render: (r: any) => r.oem_name ?? "—" },
            { key: 'recovered_amount_rupees', header: 'Recovered', render: (r: any) => formatRupees(Number(r.recovered_amount_rupees ?? 0)) },
            { key: 'claimed_amount_rupees', header: 'Claimed', render: (r: any) => formatRupees(Number(r.claimed_amount_rupees ?? 0)) },
            { key: 'recovery_pct', header: 'Recovery %', render: (r: any) => `${r.recovery_pct ?? 0}%` },
            { key: 'recovered_at', header: 'Recovered at', render: (r: any) => r.recovered_at ?? "—" },
            { key: 'failure_summary', header: 'Failure', render: (r: any) => r.failure_summary ?? "—" },
          ]}
        />
      </section>
    </div>
  );
}
