import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section className="mt-6">
      <div className="mb-2">
        <h2 className="text-base font-semibold text-neutral-900">{title}</h2>
        {subtitle ? <p className="text-xs text-neutral-500">{subtitle}</p> : null}
      </div>
      {children}
    </section>
  );
}

function Pill({ tone, children }: { tone: 'green' | 'amber' | 'red' | 'gray'; children: React.ReactNode }) {
  const map: Record<string, string> = {
    green: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    amber: 'bg-amber-50 text-amber-700 border-amber-200',
    red: 'bg-red-50 text-red-700 border-red-200',
    gray: 'bg-neutral-100 text-neutral-700 border-neutral-200',
  };
  return <span className={`inline-flex items-center rounded border px-1.5 py-0.5 text-xs ${map[tone]}`}>{children}</span>;
}

function fmtPct(v: any) { return v == null ? '—' : `${Number(v).toFixed(1)}%`; }
function fmtNum(v: any) { return v == null ? '—' : Number(v).toLocaleString('en-IN'); }
function fmtR(v: any)  { return v == null ? '—' : formatRupees(Number(v)); }

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, breakdownRes, trendRes, overrunsRes, cplRes, recentRes, topCampRes] = await Promise.all([
    supabase.rpc('founder_marketing_budget_kpis'),
    supabase.rpc('founder_marketing_channel_breakdown'),
    supabase.rpc('founder_marketing_monthly_trend'),
    supabase.rpc('founder_marketing_overruns'),
    supabase.rpc('founder_marketing_cpl_by_channel'),
    supabase.rpc('founder_marketing_recent_spend'),
    supabase.rpc('founder_marketing_top_campaigns'),
  ]);

  const k: any = (kpisRes.data ?? [])[0] ?? {};
  const breakdown: any[] = breakdownRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const overruns: any[] = overrunsRes.data ?? [];
  const cpl: any[] = cplRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];
  const topCamp: any[] = topCampRes.data ?? [];

  return (
    <main className="mx-auto max-w-6xl px-4 py-6">
      <header className="mb-4">
        <div className="text-xs text-neutral-500">Growth · r1463</div>
        <h1 className="text-xl font-semibold text-neutral-900">Marketing Budget Tracker</h1>
        <p className="text-sm text-neutral-600">Monthly budget vs actual by channel; overrun flags; CPL per channel.</p>
      </header>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Month" value={k.month_start ?? '—'} />
        <Kpi label="Total budget" value={fmtR(k.total_budget_rupees)} />
        <Kpi label="Total spend (MTD)" value={fmtR(k.total_spend_rupees)} />
        <Kpi label="Total leads" value={fmtNum(k.total_leads)} />
        <Kpi label="Utilization" value={fmtPct(k.utilization_pct)} />
        <Kpi label="Overrun" value={fmtR(k.overrun_rupees)} />
        <Kpi label="Channels over budget" value={fmtNum(k.channels_over_budget)} />
        <Kpi label="Channels under budget" value={fmtNum(k.channels_under_budget)} />
        <Kpi label="Avg CPL" value={fmtR(k.avg_cpl_rupees)} />
        <Kpi label="Best CPL channel" value={k.best_cpl_channel ?? '—'} />
        <Kpi label="Worst CPL channel" value={k.worst_cpl_channel ?? '—'} />
        <Kpi label="Last month spend" value={fmtR(k.spend_last_month_rupees)} />
        <Kpi label="MoM change" value={fmtPct(k.mom_change_pct)} />
        <Kpi label="Pacing" value={fmtPct(k.pacing_pct)} />
        <Kpi label="Days into month" value={fmtNum(k.days_into_month)} />
        <Kpi label="Forecast EOM" value={fmtR(k.forecast_eom_spend_rupees)} />
      </div>

      <Section title="Channel breakdown (current month)" subtitle="Budget vs actual + lead efficiency per channel">
        <DataTable
          rows={breakdown}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'channel', header: 'Channel', render: (r: any) => <span className="font-medium">{r.channel}</span> },
            { key: 'budget', header: 'Budget', render: (r: any) => fmtR(r.budget_rupees) },
            { key: 'spend', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
            { key: 'util', header: 'Util %', render: (r: any) => fmtPct(r.utilization_pct) },
            { key: 'overrun', header: 'Overrun', render: (r: any) => r.overrun_rupees > 0 ? <span className="text-red-700">{fmtR(r.overrun_rupees)}</span> : '—' },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'cpl', header: 'CPL', render: (r: any) => fmtR(r.cpl_rupees) },
            { key: 'status', header: 'Status', render: (r: any) => {
              const tone = r.status === 'overrun' ? 'red' : r.status === 'near_cap' ? 'amber' : r.status === 'on_track' ? 'green' : 'gray';
              return <Pill tone={tone}>{r.status}</Pill>;
            } },
            { key: 'owner', header: 'Owner', render: (r: any) => r.owner ?? '—' },
          ]}
        />
      </Section>

      <Section title="Monthly trend (last 6 months)" subtitle="Budget, spend, leads, CPL">
        <DataTable
          rows={trend}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'month', header: 'Month', render: (r: any) => r.month_label },
            { key: 'budget', header: 'Budget', render: (r: any) => fmtR(r.budget_rupees) },
            { key: 'spend', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
            { key: 'util', header: 'Util %', render: (r: any) => fmtPct(r.utilization_pct) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'cpl', header: 'CPL', render: (r: any) => fmtR(r.cpl_rupees) },
          ]}
        />
      </Section>

      <Section title="Overrun flags" subtitle="Channels exceeding monthly budget">
        <DataTable
          rows={overruns}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'channel', header: 'Channel', render: (r: any) => <span className="font-medium">{r.channel}</span> },
            { key: 'budget', header: 'Budget', render: (r: any) => fmtR(r.budget_rupees) },
            { key: 'spend', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
            { key: 'overrun', header: 'Overrun', render: (r: any) => <span className="text-red-700">{fmtR(r.overrun_rupees)}</span> },
            { key: 'overrun_pct', header: 'Over %', render: (r: any) => fmtPct(r.overrun_pct) },
            { key: 'severity', header: 'Severity', render: (r: any) => {
              const tone = r.severity === 'severe' ? 'red' : r.severity === 'high' ? 'red' : r.severity === 'mild' ? 'amber' : 'gray';
              return <Pill tone={tone}>{r.severity}</Pill>;
            } },
          ]}
        />
      </Section>

      <Section title="CPL by channel" subtitle="Lower is better; ranked ascending">
        <DataTable
          rows={cpl}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'rank', header: '#', render: (r: any) => r.rank },
            { key: 'channel', header: 'Channel', render: (r: any) => <span className="font-medium">{r.channel}</span> },
            { key: 'spend', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'cpl', header: 'CPL', render: (r: any) => <span className="font-medium">{fmtR(r.cpl_rupees)}</span> },
          ]}
        />
      </Section>

      <Section title="Top campaigns by CPL (last 90 days, min 5 leads)">
        <DataTable
          rows={topCamp}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'campaign', header: 'Campaign', render: (r: any) => <span className="font-medium">{r.campaign}</span> },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
            { key: 'spend', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads) },
            { key: 'cpl', header: 'CPL', render: (r: any) => fmtR(r.cpl_rupees) },
            { key: 'last', header: 'Last spent', render: (r: any) => r.last_spent_on },
          ]}
        />
      </Section>

      <Section title="Recent spend entries" subtitle="Latest 50 line items">
        <DataTable
          rows={recent}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'date', header: 'Date', render: (r: any) => r.spent_on },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
            { key: 'campaign', header: 'Campaign', render: (r: any) => r.campaign ?? '—' },
            { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor ?? '—' },
            { key: 'amount', header: 'Amount', render: (r: any) => fmtR(r.amount_rupees) },
            { key: 'leads', header: 'Leads', render: (r: any) => fmtNum(r.leads_generated) },
            { key: 'cpl', header: 'CPL', render: (r: any) => fmtR(r.cpl_rupees) },
          ]}
        />
      </Section>
    </main>
  );
}
