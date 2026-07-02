import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_cancellations: number;
  total_refund_rupees: number;
  recovered_value_rupees: number;
  lost_value_rupees: number;
  recovery_rate_pct: number;
  red_engineers: number;
};

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, cancelRes, engRes, causeRes, recoveryRes, winbackRes, verdictRes, redRes] =
    await Promise.all([
      supabase.rpc('founder_r2880_kpi_overview'),
      supabase.rpc('founder_r2880_list_cancellations'),
      supabase.rpc('founder_r2880_engineer_summary'),
      supabase.rpc('founder_r2880_cause_breakdown'),
      supabase.rpc('founder_r2880_recovery_mix'),
      supabase.rpc('founder_r2880_winback_funnel'),
      supabase.rpc('founder_r2880_verdict_distribution'),
      supabase.rpc('founder_r2880_red_engineers'),
    ]);

  const kpi: KpiRow = (kpiRes.data?.[0] as KpiRow) ?? {
    total_cancellations: 0,
    total_refund_rupees: 0,
    recovered_value_rupees: 0,
    lost_value_rupees: 0,
    recovery_rate_pct: 0,
    red_engineers: 0,
  };

  const cancellations = (cancelRes.data ?? []) as Array<Record<string, unknown>>;
  const engineers = (engRes.data ?? []) as Array<Record<string, unknown>>;
  const causes = (causeRes.data ?? []) as Array<Record<string, unknown>>;
  const recovery = (recoveryRes.data ?? []) as Array<Record<string, unknown>>;
  const winback = (winbackRes.data ?? []) as Array<Record<string, unknown>>;
  const verdicts = (verdictRes.data ?? []) as Array<Record<string, unknown>>;
  const red = (redRes.data ?? []) as Array<Record<string, unknown>>;

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Job Cancellation Recovery</h1>
        <p className="text-sm text-gray-600">
          Monthly view: engineer × job × cancellation cause × recovery × refund ×
          win-back × verdict.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Cancellations</div>
          <div className="text-xl font-semibold">{kpi.total_cancellations}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Refund total</div>
          <div className="text-xl font-semibold">{inr(kpi.total_refund_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Recovered value</div>
          <div className="text-xl font-semibold">{inr(kpi.recovered_value_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Lost value</div>
          <div className="text-xl font-semibold">{inr(kpi.lost_value_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Recovery rate</div>
          <div className="text-xl font-semibold">{Number(kpi.recovery_rate_pct ?? 0)}%</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Red engineers</div>
          <div className="text-xl font-semibold">{kpi.red_engineers}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Cancellation events</h2>
        <DataTable
          rows={cancellations}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
            { key: 'job_code', header: 'Job', render: (r) => String(r.job_code ?? '') },
            { key: 'job_kind', header: 'Kind', render: (r) => String(r.job_kind ?? '') },
            { key: 'customer_name', header: 'Customer', render: (r) => String(r.customer_name ?? '') },
            { key: 'cancellation_cause', header: 'Cause', render: (r) => String(r.cancellation_cause ?? '') },
            { key: 'job_value_rupees', header: 'Job value', render: (r) => inr(Number(r.job_value_rupees ?? 0)) },
            { key: 'refund_rupees', header: 'Refund', render: (r) => inr(Number(r.refund_rupees ?? 0)) },
            { key: 'recovery_action', header: 'Recovery', render: (r) => String(r.recovery_action ?? '') },
            { key: 'win_back_state', header: 'Win-back', render: (r) => String(r.win_back_state ?? '') },
            { key: 'verdict', header: 'Verdict', render: (r) => String(r.verdict ?? '') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engineer monthly summary</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => String(r.engineer_code ?? '') },
            { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
            { key: 'total_jobs', header: 'Jobs', render: (r) => String(r.total_jobs ?? 0) },
            { key: 'cancelled_jobs', header: 'Cancelled', render: (r) => String(r.cancelled_jobs ?? 0) },
            { key: 'cancellation_rate_pct', header: 'Cancel %', render: (r) => `${Number(r.cancellation_rate_pct ?? 0)}%` },
            { key: 'refund_rupees', header: 'Refund', render: (r) => inr(Number(r.refund_rupees ?? 0)) },
            { key: 'recovered_value_rupees', header: 'Recovered', render: (r) => inr(Number(r.recovered_value_rupees ?? 0)) },
            { key: 'lost_value_rupees', header: 'Lost', render: (r) => inr(Number(r.lost_value_rupees ?? 0)) },
            { key: 'top_cause', header: 'Top cause', render: (r) => String(r.top_cause ?? '') },
            { key: 'verdict', header: 'Verdict', render: (r) => String(r.verdict ?? '') },
            { key: 'next_step', header: 'Next step', render: (r) => String(r.next_step ?? '') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Cause breakdown</h2>
          <DataTable
            rows={causes}
            columns={[
              { key: 'cause', header: 'Cause', render: (r) => String(r.cause ?? '') },
              { key: 'event_count', header: 'Events', render: (r) => String(r.event_count ?? 0) },
              { key: 'refund_rupees', header: 'Refund', render: (r) => inr(Number(r.refund_rupees ?? 0)) },
              { key: 'lost_value_rupees', header: 'Lost', render: (r) => inr(Number(r.lost_value_rupees ?? 0)) },
              { key: 'recovered_value_rupees', header: 'Recovered', render: (r) => inr(Number(r.recovered_value_rupees ?? 0)) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.cause ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Recovery action mix</h2>
          <DataTable
            rows={recovery}
            columns={[
              { key: 'recovery_action', header: 'Action', render: (r) => String(r.recovery_action ?? '') },
              { key: 'event_count', header: 'Events', render: (r) => String(r.event_count ?? 0) },
              { key: 'refund_rupees', header: 'Refund', render: (r) => inr(Number(r.refund_rupees ?? 0)) },
              { key: 'recovered_value_rupees', header: 'Recovered', render: (r) => inr(Number(r.recovered_value_rupees ?? 0)) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.recovery_action ?? i)}
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Win-back funnel</h2>
          <DataTable
            rows={winback}
            columns={[
              { key: 'win_back_state', header: 'State', render: (r) => String(r.win_back_state ?? '') },
              { key: 'event_count', header: 'Events', render: (r) => String(r.event_count ?? 0) },
              { key: 'job_value_rupees', header: 'Job value', render: (r) => inr(Number(r.job_value_rupees ?? 0)) },
              { key: 'win_back_value_rupees', header: 'Win-back value', render: (r) => inr(Number(r.win_back_value_rupees ?? 0)) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.win_back_state ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Verdict distribution</h2>
          <DataTable
            rows={verdicts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r) => String(r.verdict ?? '') },
              { key: 'event_count', header: 'Events', render: (r) => String(r.event_count ?? 0) },
              { key: 'share_pct', header: 'Share %', render: (r) => `${Number(r.share_pct ?? 0)}%` },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(r.verdict ?? i)}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Red & amber engineers</h2>
        <DataTable
          rows={red}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => String(r.engineer_code ?? '') },
            { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
            { key: 'cancellation_rate_pct', header: 'Cancel %', render: (r) => `${Number(r.cancellation_rate_pct ?? 0)}%` },
            { key: 'top_cause', header: 'Top cause', render: (r) => String(r.top_cause ?? '') },
            { key: 'next_step', header: 'Next step', render: (r) => String(r.next_step ?? '') },
            { key: 'action_owner', header: 'Owner', render: (r) => String(r.action_owner ?? '') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>
    </main>
  );
}
