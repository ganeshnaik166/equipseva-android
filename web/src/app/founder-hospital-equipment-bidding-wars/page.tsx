import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type War = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  equipment_name: string | null;
  bid_window_start: string | null;
  bid_window_end: string | null;
  our_quote_rupees: number | null;
  competitor_count: number | null;
  won: boolean | null;
  decision_basis: string | null;
  decided_at: string | null;
  created_at: string | null;
};

type Summary = {
  total_wars: number | null;
  decided_wars: number | null;
  wins: number | null;
  losses: number | null;
  win_rate_pct: number | string | null;
  avg_competitor_count: number | string | null;
  total_our_quote_rupees: number | null;
};

type BasisRow = {
  decision_basis: string | null;
  wars: number | null;
  wins: number | null;
  losses: number | null;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [warsRes, summaryRes, basisRes] = await Promise.all([
    sb.rpc('list_bidding_wars_r1803'),
    sb.rpc('win_rate_summary_r1803'),
    sb.rpc('decision_basis_distribution_r1803'),
  ]);

  const wars: War[] = (warsRes.data as War[] | null) ?? [];
  const summaryArr = (summaryRes.data as Summary[] | null) ?? [];
  const summary: Summary | null = summaryArr.length > 0 ? summaryArr[0] : null;
  const basis: BasisRow[] = (basisRes.data as BasisRow[] | null) ?? [];

  const warsErr = warsRes.error?.message ?? null;
  const summaryErr = summaryRes.error?.message ?? null;
  const basisErr = basisRes.error?.message ?? null;

  const warColumns: Column<War>[] = [
    { key: 'equipment', header: 'Equipment', render: (r: any) => <span className="font-medium">{r.equipment_name ?? '-'}</span> },
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="text-xs">{r.hospital_email ?? r.hospital_user_id ?? '-'}</span> },
    { key: 'window', header: 'Bid Window', render: (r: any) => <span className="text-xs">{fmtDate(r.bid_window_start)} → {fmtDate(r.bid_window_end)}</span> },
    { key: 'our_quote', header: 'Our Quote', render: (r: any) => <span>{fmtRupees(r.our_quote_rupees)}</span> },
    { key: 'competitors', header: 'Competitors', render: (r: any) => <span>{r.competitor_count ?? 0}</span> },
    { key: 'won', header: 'Result', render: (r: any) => {
        if (r.won === true) return <span className="rounded bg-green-100 px-2 py-0.5 text-xs text-green-800">WON</span>;
        if (r.won === false) return <span className="rounded bg-red-100 px-2 py-0.5 text-xs text-red-800">LOST</span>;
        return <span className="text-xs text-[var(--color-muted)]">pending</span>;
      } },
    { key: 'basis', header: 'Decision Basis', render: (r: any) => <span className="text-xs">{r.decision_basis ?? '-'}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span className="text-xs">{fmtDate(r.decided_at)}</span> },
  ];

  const basisColumns: Column<BasisRow>[] = [
    { key: 'basis', header: 'Decision Basis', render: (r: any) => <span className="font-medium uppercase">{r.decision_basis ?? '-'}</span> },
    { key: 'wars', header: 'Wars', render: (r: any) => <span>{r.wars ?? 0}</span> },
    { key: 'wins', header: 'Wins', render: (r: any) => <span className="text-green-700">{r.wins ?? 0}</span> },
    { key: 'losses', header: 'Losses', render: (r: any) => <span className="text-red-700">{r.losses ?? 0}</span> },
    { key: 'rate', header: 'Win Rate', render: (r: any) => {
        const w = Number(r.wars ?? 0);
        const wn = Number(r.wins ?? 0);
        const pct = w > 0 ? Math.round((wn / w) * 1000) / 10 : 0;
        return <span>{pct}%</span>;
      } },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Hospital Equipment Bidding Wars</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track competitive bidding cycles where multiple vendors quote on the same hospital equipment replacement. Win-rate, decision basis, and competitor intel.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Win-rate summary</h2>
        {summaryErr ? (
          <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-800">Error loading summary: {summaryErr}</div>
        ) : (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs text-[var(--color-muted)]">Total wars</div>
              <div className="text-xl font-semibold">{summary?.total_wars ?? 0}</div>
            </div>
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs text-[var(--color-muted)]">Decided</div>
              <div className="text-xl font-semibold">{summary?.decided_wars ?? 0}</div>
            </div>
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs text-[var(--color-muted)]">Wins / Losses</div>
              <div className="text-xl font-semibold">
                <span className="text-green-700">{summary?.wins ?? 0}</span>
                <span className="px-1 text-[var(--color-muted)]">/</span>
                <span className="text-red-700">{summary?.losses ?? 0}</span>
              </div>
            </div>
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs text-[var(--color-muted)]">Win rate</div>
              <div className="text-xl font-semibold">{summary?.win_rate_pct ?? 0}%</div>
            </div>
            <div className="rounded border border-[var(--color-border)] bg-white p-4">
              <div className="text-xs text-[var(--color-muted)]">Avg competitors</div>
              <div className="text-xl font-semibold">{summary?.avg_competitor_count ?? 0}</div>
            </div>
            <div className="rounded border border-[var(--color-border)] bg-white p-4 md:col-span-3">
              <div className="text-xs text-[var(--color-muted)]">Total our-quote pipeline value</div>
              <div className="text-xl font-semibold">{fmtRupees(summary?.total_our_quote_rupees ?? 0)}</div>
            </div>
          </div>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Decision basis distribution</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Why hospitals decided — price vs relationship vs features vs service vs timing. Win rate by basis tells where we have edge & where we get crushed.
        </p>
        {basisErr ? (
          <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-800">Error loading basis distribution: {basisErr}</div>
        ) : (
          <DataTable<BasisRow>
            rows={basis}
            columns={basisColumns}
            rowKey={(r: any, i: number) => String(r.decision_basis ?? i)}
            emptyMessage="No decided wars yet."
          />
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All bidding wars (latest 200)</h2>
        {warsErr ? (
          <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-800">Error loading bidding wars: {warsErr}</div>
        ) : (
          <DataTable<War>
            rows={wars}
            columns={warColumns}
            rowKey={(r: any, i: number) => String(r.id ?? i)}
            emptyMessage="No bidding wars logged."
          />
        )}
      </section>
    </main>
  );
}
