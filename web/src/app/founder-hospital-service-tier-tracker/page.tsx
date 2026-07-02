import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TierRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  tier: string;
  since_date: string | null;
  last_assessed_at: string | null;
  sla_minutes: number;
  discount_pct: number;
  founder_dedicated: boolean;
  status: string;
  updated_at: string;
};

type HistoryRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  old_tier: string | null;
  new_tier: string;
  change_reason: string | null;
  changed_at: string;
};

type DistRow = {
  tier: string;
  hospital_count: number;
  avg_sla_minutes: number | null;
  avg_discount_pct: number | null;
  founder_dedicated_count: number;
};

function fmtDate(s: string | null) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}

function shortId(id: string | null) {
  if (!id) return '-';
  return id.slice(0, 8);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tiersRes, distRes, upRes, downRes, histRes] = await Promise.all([
    sb.rpc('list_tiers_r1859'),
    sb.rpc('tier_distribution_r1859'),
    sb.rpc('recent_upgrades_r1859', { p_limit: 20 }),
    sb.rpc('recent_downgrades_r1859', { p_limit: 20 }),
    sb.rpc('list_history_r1859', { p_limit: 50 }),
  ]);

  const tiers: TierRow[] = (tiersRes.data as TierRow[] | null) ?? [];
  const dist: DistRow[] = (distRes.data as DistRow[] | null) ?? [];
  const ups: HistoryRow[] = (upRes.data as HistoryRow[] | null) ?? [];
  const downs: HistoryRow[] = (downRes.data as HistoryRow[] | null) ?? [];
  const hist: HistoryRow[] = (histRes.data as HistoryRow[] | null) ?? [];

  const tierCols: Column<TierRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? shortId(r.hospital_user_id)}</span> },
    { key: 'tier', header: 'Tier', render: (r: any) => <span className="uppercase font-semibold">{r.tier}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'since', header: 'Since', render: (r: any) => <span>{r.since_date ?? '-'}</span> },
    { key: 'sla', header: 'SLA (min)', render: (r: any) => <span>{r.sla_minutes}</span> },
    { key: 'discount', header: 'Discount %', render: (r: any) => <span>{Number(r.discount_pct ?? 0).toFixed(2)}</span> },
    { key: 'dedicated', header: 'Founder Dedicated', render: (r: any) => <span>{r.founder_dedicated ? 'yes' : 'no'}</span> },
    { key: 'assessed', header: 'Last Assessed', render: (r: any) => <span>{fmtDate(r.last_assessed_at)}</span> },
    { key: 'updated', header: 'Updated', render: (r: any) => <span>{fmtDate(r.updated_at)}</span> },
  ];

  const distCols: Column<DistRow>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => <span className="uppercase font-semibold">{r.tier}</span> },
    { key: 'count', header: 'Hospitals', render: (r: any) => <span>{r.hospital_count}</span> },
    { key: 'sla', header: 'Avg SLA (min)', render: (r: any) => <span>{r.avg_sla_minutes ?? '-'}</span> },
    { key: 'disc', header: 'Avg Discount %', render: (r: any) => <span>{r.avg_discount_pct ?? '-'}</span> },
    { key: 'ded', header: 'Founder Dedicated', render: (r: any) => <span>{r.founder_dedicated_count}</span> },
  ];

  const histCols: Column<HistoryRow>[] = [
    { key: 'when', header: 'When', render: (r: any) => <span>{fmtDate(r.changed_at)}</span> },
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? shortId(r.hospital_user_id)}</span> },
    { key: 'old', header: 'Old Tier', render: (r: any) => <span>{r.old_tier ?? '-'}</span> },
    { key: 'new', header: 'New Tier', render: (r: any) => <span className="font-semibold">{r.new_tier}</span> },
    { key: 'reason', header: 'Reason', render: (r: any) => <span>{r.change_reason ?? '-'}</span> },
  ];

  const totalHospitals = tiers.length;
  const platinumCount = tiers.filter((t) => t.tier === 'platinum').length;
  const goldCount = tiers.filter((t) => t.tier === 'gold').length;
  const dedicatedCount = tiers.filter((t) => t.founder_dedicated).length;

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Hospital Service Tier Tracker</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Per-hospital service tier (platinum &gt; gold &gt; silver &gt; bronze &gt; standard), SLA &amp; discount benefits, founder-dedicated flagging, and full upgrade/downgrade history.
        </p>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Total Hospitals</div>
            <div className="text-xl font-semibold">{totalHospitals}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Platinum</div>
            <div className="text-xl font-semibold">{platinumCount}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Gold</div>
            <div className="text-xl font-semibold">{goldCount}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Founder Dedicated</div>
            <div className="text-xl font-semibold">{dedicatedCount}</div>
          </div>
        </div>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Tier Distribution</h2>
        <DataTable
          rows={dist}
          columns={distCols}
          rowKey={(r: any, i: number) => String(r.tier ?? i)}
          emptyMessage="No tier data yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Hospital Tiers</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No hospitals assigned a tier yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Upgrades</h2>
        <p className="text-xs text-[var(--color-muted)]">Tier moved up (e.g. silver → gold).</p>
        <DataTable
          rows={ups}
          columns={histCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No recent upgrades."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Downgrades</h2>
        <p className="text-xs text-[var(--color-muted)]">Tier moved down (e.g. gold → silver).</p>
        <DataTable
          rows={downs}
          columns={histCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No recent downgrades."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Full Change History</h2>
        <DataTable
          rows={hist}
          columns={histCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No tier changes logged yet."
        />
      </section>
    </div>
  );
}
