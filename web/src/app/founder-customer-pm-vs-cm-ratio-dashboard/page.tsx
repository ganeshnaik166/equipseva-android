import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    monthlyRatios,
    alerts,
    topCmRising,
    under50Pm,
    distribution,
    companyAvg,
    interventionPlan,
  ] = await Promise.all([
    sb.rpc('list_monthly_ratios_r2412'),
    sb.rpc('list_alerts_r2412'),
    sb.rpc('top_cm_rising_r2412'),
    sb.rpc('hospitals_under_50pct_pm_r2412'),
    sb.rpc('ratio_distribution_r2412'),
    sb.rpc('monthly_company_avg_r2412'),
    sb.rpc('intervention_plan_summary_r2412'),
  ]);

  const monthlyRows = (monthlyRatios.data ?? []) as any[];
  const alertRows = (alerts.data ?? []) as any[];
  const topCmRows = (topCmRising.data ?? []) as any[];
  const under50Rows = (under50Pm.data ?? []) as any[];
  const distRows = (distribution.data ?? []) as any[];
  const companyRows = (companyAvg.data ?? []) as any[];
  const planRows = (interventionPlan.data ?? []) as any[];

  const monthlyCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email },
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'pm_visits', header: 'PM visits', render: (r: any) => Number(r.pm_visits) },
    { key: 'cm_visits', header: 'CM visits', render: (r: any) => Number(r.cm_visits) },
    { key: 'pm_ratio_pct', header: 'PM %', render: (r: any) => `${Number(r.pm_ratio_pct).toFixed(2)}%` },
    { key: 'cm_ratio_pct', header: 'CM %', render: (r: any) => `${Number(r.cm_ratio_pct).toFixed(2)}%` },
    { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: any) => Number(r.downtime_minutes) },
    { key: 'slo_breaches', header: 'SLO breaches', render: (r: any) => Number(r.slo_breaches) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const alertCols: Column<any>[] = [
    { key: 'detected_at', header: 'Detected', render: (r: any) => new Date(r.detected_at).toLocaleString() },
    { key: 'alert_kind', header: 'Kind', render: (r: any) => r.alert_kind },
    { key: 'prior_pm_ratio_pct', header: 'Prior PM %', render: (r: any) => `${Number(r.prior_pm_ratio_pct).toFixed(2)}%` },
    { key: 'current_pm_ratio_pct', header: 'Current PM %', render: (r: any) => `${Number(r.current_pm_ratio_pct).toFixed(2)}%` },
    { key: 'ratio_delta_pct', header: 'Delta %', render: (r: any) => `${Number(r.ratio_delta_pct).toFixed(2)}%` },
    { key: 'recommended_action', header: 'Action', render: (r: any) => r.recommended_action ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topCmCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email },
    { key: 'current_pm_ratio_pct', header: 'Current PM %', render: (r: any) => `${Number(r.current_pm_ratio_pct).toFixed(2)}%` },
    { key: 'prior_pm_ratio_pct', header: 'Prior PM %', render: (r: any) => `${Number(r.prior_pm_ratio_pct).toFixed(2)}%` },
    { key: 'ratio_delta_pct', header: 'Delta %', render: (r: any) => `${Number(r.ratio_delta_pct).toFixed(2)}%` },
    { key: 'recommended_action', header: 'Recommended action', render: (r: any) => r.recommended_action ?? '—' },
  ];

  const under50Cols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email },
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'pm_ratio_pct', header: 'PM %', render: (r: any) => `${Number(r.pm_ratio_pct).toFixed(2)}%` },
    { key: 'cm_ratio_pct', header: 'CM %', render: (r: any) => `${Number(r.cm_ratio_pct).toFixed(2)}%` },
    { key: 'total_visits', header: 'Total visits', render: (r: any) => Number(r.total_visits) },
  ];

  const distCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => Number(r.hospital_count) },
  ];

  const companyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'avg_pm_ratio_pct', header: 'Avg PM %', render: (r: any) => `${Number(r.avg_pm_ratio_pct).toFixed(2)}%` },
    { key: 'avg_cm_ratio_pct', header: 'Avg CM %', render: (r: any) => `${Number(r.avg_cm_ratio_pct).toFixed(2)}%` },
    { key: 'total_pm_visits', header: 'PM visits', render: (r: any) => Number(r.total_pm_visits) },
    { key: 'total_cm_visits', header: 'CM visits', render: (r: any) => Number(r.total_cm_visits) },
    { key: 'total_slo_breaches', header: 'SLO breaches', render: (r: any) => Number(r.total_slo_breaches) },
  ];

  const planCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'alert_kind', header: 'Kind', render: (r: any) => r.alert_kind },
    { key: 'alert_count', header: 'Alerts', render: (r: any) => Number(r.alert_count) },
    { key: 'avg_ratio_delta_pct', header: 'Avg delta %', render: (r: any) => `${Number(r.avg_ratio_delta_pct).toFixed(2)}%` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer PM vs CM Ratio Dashboard</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-hospital preventive vs corrective maintenance trending. CM-rising =&gt; retention risk.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-2">Monthly PM/CM ratios</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly rollups yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Top CM-rising hospitals</h2>
        <DataTable
          rows={topCmRows}
          columns={topCmCols}
          emptyMessage="No open CM-rising alerts."
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Hospitals under 50% PM</h2>
        <DataTable
          rows={under50Rows}
          columns={under50Cols}
          emptyMessage="All hospitals above 50% PM."
          rowKey={(r: any, i: number) => String(r.hospital_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Latest month ratio distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No data yet."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Company-wide monthly averages</h2>
        <DataTable
          rows={companyRows}
          columns={companyCols}
          emptyMessage="No data yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Intervention plan summary</h2>
        <DataTable
          rows={planRows}
          columns={planCols}
          emptyMessage="No alerts yet."
          rowKey={(r: any, i: number) => `${r.status}-${r.alert_kind}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">All alerts</h2>
        <DataTable
          rows={alertRows}
          columns={alertCols}
          emptyMessage="No alerts."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
