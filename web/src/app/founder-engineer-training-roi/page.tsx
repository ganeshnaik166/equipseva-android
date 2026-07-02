import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}
function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}
function fmtNum(n: number | null | undefined, d = 2): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(d);
}
function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(1) + '%';
}
function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}
function shortId(s: string | null | undefined): string {
  if (!s) return '—';
  return s.slice(0, 8);
}

export default async function FounderEngineerTrainingRoiPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpiRes, rankRes, catRes, attRes, monthRes, paybackRes, recentRes] = await Promise.all([
    sb.rpc('founder_training_kpis'),
    sb.rpc('founder_training_program_ranking'),
    sb.rpc('founder_training_by_category'),
    sb.rpc('founder_training_top_attendees'),
    sb.rpc('founder_training_monthly_spend'),
    sb.rpc('founder_training_payback_curve'),
    sb.rpc('founder_training_recent_attendance'),
  ]);

  const k: any = (kpiRes.data && kpiRes.data[0]) || {};
  const ranking: any[] = rankRes.data ?? [];
  const byCategory: any[] = catRes.data ?? [];
  const topAtt: any[] = attRes.data ?? [];
  const monthly: any[] = monthRes.data ?? [];
  const payback: any[] = paybackRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];

  const kpis: Kpi[] = [
    { label: 'Total programs', value: fmtInt(k.total_programs) },
    { label: 'Total attendees', value: fmtInt(k.total_attendees) },
    { label: 'Total spend', value: fmtRupees(k.total_spend_rupees) },
    { label: 'Avg cost / attendee', value: fmtRupees(Math.round(Number(k.avg_cost_per_attendee ?? 0))) },
    { label: 'Cert yield', value: fmtPct(k.cert_yield_pct) },
    { label: 'Completion rate', value: fmtPct(k.completion_pct) },
    { label: 'Avg NPS lift', value: fmtNum(k.avg_nps_lift) },
    { label: 'Avg efficiency lift', value: fmtPct(k.avg_efficiency_lift_pct) },
    { label: 'Avg rating lift', value: fmtNum(k.avg_rating_lift) },
    { label: 'Avg payback (days)', value: fmtNum(k.payback_days_avg, 1) },
    { label: 'Programs positive ROI', value: fmtInt(k.programs_positive_roi) },
    { label: 'Programs negative ROI', value: fmtInt(k.programs_negative_roi) },
    { label: 'Categories tracked', value: fmtInt(byCategory.length) },
    { label: 'Top attendees shown', value: fmtInt(topAtt.length) },
    { label: 'Monthly buckets', value: fmtInt(monthly.length) },
    { label: 'Recent attendance rows', value: fmtInt(recent.length) },
  ];

  const rankCols: Column<any>[] = [
    { key: 'program_code', header: 'Code', render: (r: any) => r.program_code ?? '—' },
    { key: 'program_name', header: 'Program', render: (r: any) => r.program_name ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'attendees', header: 'Attendees', render: (r: any) => fmtInt(r.attendees) },
    { key: 'total_spend_rupees', header: 'Spend', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'cost_per_attendee', header: 'Cost / att', render: (r: any) => fmtRupees(Math.round(Number(r.cost_per_attendee ?? 0))) },
    { key: 'cert_yield_pct', header: 'Cert %', render: (r: any) => fmtPct(r.cert_yield_pct) },
    { key: 'avg_nps_lift', header: 'NPS lift', render: (r: any) => fmtNum(r.avg_nps_lift) },
    { key: 'avg_efficiency_lift_pct', header: 'Eff lift', render: (r: any) => fmtPct(r.avg_efficiency_lift_pct) },
    { key: 'payback_days', header: 'Payback (d)', render: (r: any) => fmtNum(r.payback_days, 1) },
    { key: 'roi_score', header: 'ROI score', render: (r: any) => fmtNum(r.roi_score) },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'programs', header: 'Programs', render: (r: any) => fmtInt(r.programs) },
    { key: 'attendees', header: 'Attendees', render: (r: any) => fmtInt(r.attendees) },
    { key: 'total_spend_rupees', header: 'Spend', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'avg_nps_lift', header: 'NPS lift', render: (r: any) => fmtNum(r.avg_nps_lift) },
    { key: 'avg_efficiency_lift_pct', header: 'Eff lift', render: (r: any) => fmtPct(r.avg_efficiency_lift_pct) },
    { key: 'cert_yield_pct', header: 'Cert %', render: (r: any) => fmtPct(r.cert_yield_pct) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_user_id) },
    { key: 'programs_attended', header: 'Programs', render: (r: any) => fmtInt(r.programs_attended) },
    { key: 'total_invested_rupees', header: 'Invested', render: (r: any) => fmtRupees(r.total_invested_rupees) },
    { key: 'certs_earned', header: 'Certs', render: (r: any) => fmtInt(r.certs_earned) },
    { key: 'avg_nps_lift', header: 'NPS lift', render: (r: any) => fmtNum(r.avg_nps_lift) },
    { key: 'avg_efficiency_lift_pct', header: 'Eff lift', render: (r: any) => fmtPct(r.avg_efficiency_lift_pct) },
  ];

  const monthCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ?? '—' },
    { key: 'attendees', header: 'Attendees', render: (r: any) => fmtInt(r.attendees) },
    { key: 'total_spend_rupees', header: 'Spend', render: (r: any) => fmtRupees(r.total_spend_rupees) },
    { key: 'certs', header: 'Certs', render: (r: any) => fmtInt(r.certs) },
    { key: 'avg_nps_lift', header: 'NPS lift', render: (r: any) => fmtNum(r.avg_nps_lift) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'program_name', header: 'Program', render: (r: any) => r.program_name ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_user_id) },
    { key: 'attended_at', header: 'Attended', render: (r: any) => fmtDate(r.attended_at) },
    { key: 'cost_actual_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.cost_actual_rupees) },
    { key: 'completed', header: 'Done', render: (r: any) => (r.completed ? 'yes' : 'no') },
    { key: 'certified', header: 'Cert', render: (r: any) => (r.certified ? 'yes' : 'no') },
    { key: 'nps_lift', header: 'NPS lift', render: (r: any) => fmtNum(r.nps_lift) },
    { key: 'efficiency_lift_pct', header: 'Eff lift', render: (r: any) => fmtPct(r.efficiency_lift_pct) },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <p className="text-xs uppercase tracking-wide text-slate-500">Founder · Engineering · r1488</p>
        <h1 className="mt-1 text-2xl font-semibold text-slate-900">Engineer training cost ROI</h1>
        <p className="mt-1 text-sm text-slate-600">
          Per-program spend, attendees, post-training NPS/efficiency lift, certification yield, payback, and ROI rank.
        </p>
      </header>

      <section className="mb-8 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {kpis.map((kpi) => (
          <div key={kpi.label} className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs text-slate-500">{kpi.label}</div>
            <div className="mt-1 text-xl font-semibold text-slate-900">{kpi.value}</div>
          </div>
        ))}
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-slate-700">Program ROI ranking</h2>
        <DataTable columns={rankCols} rows={ranking} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-slate-700">By category</h2>
        <DataTable columns={catCols} rows={byCategory} rowKey={(r: any) => r.category} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-slate-700">Top attendees</h2>
        <DataTable columns={topCols} rows={topAtt} rowKey={(r: any) => r.engineer_user_id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-slate-700">Monthly spend (12 mo)</h2>
        <DataTable columns={monthCols} rows={monthly} rowKey={(r: any) => r.month_start} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-slate-700">Payback curve</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          {payback.map((p: any) => (
            <div key={p.bucket} className="rounded-lg border border-slate-200 bg-white p-3">
              <div className="text-xs text-slate-500">{p.bucket}</div>
              <div className="mt-1 text-lg font-semibold text-slate-900">{fmtInt(p.programs)}</div>
              <div className="text-xs text-slate-500">{fmtInt(p.attendees)} attendees</div>
              <div className="text-xs text-slate-500">avg {fmtNum(p.avg_payback_days, 1)}d</div>
            </div>
          ))}
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-slate-700">Recent attendance</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
