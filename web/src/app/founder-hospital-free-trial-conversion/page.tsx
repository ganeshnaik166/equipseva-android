import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TrialRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  trial_start: string;
  trial_end: string;
  trial_type: string;
  trial_value_rupees: number;
  status: string;
  converted_at: string | null;
  efforts_count: number;
};

type SummaryRow = {
  trial_type: string;
  total_trials: number;
  converted: number;
  expired: number;
  active: number;
  lost: number;
  conversion_pct: number;
  total_value_rupees: number;
};

type ExpiringRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  trial_end: string;
  days_remaining: number;
  trial_type: string;
  trial_value_rupees: number;
  status: string;
};

function fmtDate(s: string | null): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [trialsRes, summaryRes, expiringRes] = await Promise.all([
    sb.rpc('list_trials_r1787'),
    sb.rpc('conversion_rate_summary_r1787'),
    sb.rpc('expiring_trials_r1787', { p_days_ahead: 7 }),
  ]);

  const trials: TrialRow[] = (trialsRes.data as TrialRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[] | null) ?? [];

  const trialColumns: Column<TrialRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? r.hospital_user_id.slice(0, 8)}</span> },
    { key: 'type', header: 'Trial Type', render: (r: any) => <span>{r.trial_type}</span> },
    { key: 'start', header: 'Start', render: (r: any) => <span>{fmtDate(r.trial_start)}</span> },
    { key: 'end', header: 'End', render: (r: any) => <span>{fmtDate(r.trial_end)}</span> },
    { key: 'value', header: 'Value', render: (r: any) => <span>{fmtRupees(r.trial_value_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'efforts', header: 'Efforts', render: (r: any) => <span>{r.efforts_count}</span> },
    { key: 'converted', header: 'Converted At', render: (r: any) => <span>{fmtDate(r.converted_at)}</span> },
  ];

  const summaryColumns: Column<SummaryRow>[] = [
    { key: 'type', header: 'Trial Type', render: (r: any) => <span className="font-medium">{r.trial_type}</span> },
    { key: 'total', header: 'Total', render: (r: any) => <span>{r.total_trials}</span> },
    { key: 'converted', header: 'Converted', render: (r: any) => <span className="text-green-700">{r.converted}</span> },
    { key: 'active', header: 'Active', render: (r: any) => <span>{r.active}</span> },
    { key: 'expired', header: 'Expired', render: (r: any) => <span>{r.expired}</span> },
    { key: 'lost', header: 'Lost', render: (r: any) => <span className="text-red-700">{r.lost}</span> },
    { key: 'pct', header: 'Conv %', render: (r: any) => <span className="font-semibold">{Number(r.conversion_pct).toFixed(2)}%</span> },
    { key: 'value', header: 'Total Value', render: (r: any) => <span>{fmtRupees(r.total_value_rupees)}</span> },
  ];

  const expiringColumns: Column<ExpiringRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? r.hospital_user_id.slice(0, 8)}</span> },
    { key: 'type', header: 'Trial Type', render: (r: any) => <span>{r.trial_type}</span> },
    { key: 'end', header: 'Ends', render: (r: any) => <span>{fmtDate(r.trial_end)}</span> },
    { key: 'days', header: 'Days Left', render: (r: any) => <span className={r.days_remaining <= 2 ? 'font-bold text-red-700' : 'font-medium'}>{r.days_remaining}</span> },
    { key: 'value', header: 'Value', render: (r: any) => <span>{fmtRupees(r.trial_value_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
  ];

  const totalTrials = summary.reduce((s, x) => s + Number(x.total_trials ?? 0), 0);
  const totalConverted = summary.reduce((s, x) => s + Number(x.converted ?? 0), 0);
  const totalValue = summary.reduce((s, x) => s + Number(x.total_value_rupees ?? 0), 0);
  const overallPct = totalTrials > 0 ? ((totalConverted / totalTrials) * 100).toFixed(2) : '0.00';

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Free Trial Conversion</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Track hospitals on free trial and conversion efforts. Founder-only console.
        </p>
      </header>

      <section>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase text-[var(--color-muted)]">Total Trials</div>
            <div className="mt-1 text-2xl font-bold">{totalTrials}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase text-[var(--color-muted)]">Converted</div>
            <div className="mt-1 text-2xl font-bold text-green-700">{totalConverted}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase text-[var(--color-muted)]">Overall Conv %</div>
            <div className="mt-1 text-2xl font-bold">{overallPct}%</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs uppercase text-[var(--color-muted)]">Trial Value Sum</div>
            <div className="mt-1 text-2xl font-bold">{fmtRupees(totalValue)}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Conversion Rate by Trial Type</h2>
        <DataTable<SummaryRow>
          rows={summary}
          columns={summaryColumns}
          rowKey={(r: any, i) => String(r.trial_type ?? i)}
          emptyMessage="No trial summary yet."
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Expiring in Next 7 Days</h2>
        <p className="mb-2 text-sm text-[var(--color-muted)]">
          Active trials ending soon. Prioritize founder calls for high-value rows.
        </p>
        <DataTable<ExpiringRow>
          rows={expiring}
          columns={expiringColumns}
          rowKey={(r: any, i) => String(r.id ?? i)}
          emptyMessage="No expiring trials in the next week."
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">All Trials</h2>
        <DataTable<TrialRow>
          rows={trials}
          columns={trialColumns}
          rowKey={(r: any, i) => String(r.id ?? i)}
          emptyMessage="No trials logged yet."
        />
      </section>
    </div>
  );
}
