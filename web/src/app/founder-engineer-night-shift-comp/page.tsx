import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_shifts: number;
  total_engineers: number;
  total_premium_rupees: number;
  total_base_rupees: number;
  pending_approvals: number;
  approved_this_month: number;
};

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(v);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const kpisRes = await sb.rpc('founder_night_shift_kpis');
  const perEngRes = await sb.rpc('founder_night_shift_per_engineer');
  const recentRes = await sb.rpc('founder_night_shift_recent_shifts');
  const queueRes = await sb.rpc('founder_night_shift_pending_queue');
  const reconRes = await sb.rpc('founder_night_shift_reconciliation');

  const kpis: Kpis = (kpisRes.data?.[0] ?? {
    total_shifts: 0,
    total_engineers: 0,
    total_premium_rupees: 0,
    total_base_rupees: 0,
    pending_approvals: 0,
    approved_this_month: 0,
  }) as Kpis;

  const perEng = (perEngRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const queue = (queueRes.data ?? []) as any[];
  const recon = (reconRes.data ?? []) as any[];

  const perEngCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '—' },
    { key: 'shifts_count', header: 'Shifts', render: (r: any) => String(r.shifts_count ?? 0) },
    { key: 'total_hours', header: 'Hours', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'base_pay_rupees', header: 'Base ₹', render: (r: any) => inr(r.base_pay_rupees) },
    { key: 'premium_pay_rupees', header: 'Night Premium ₹', render: (r: any) => inr(r.premium_pay_rupees) },
    { key: 'total_pay_rupees', header: 'Total ₹', render: (r: any) => inr(r.total_pay_rupees) },
    { key: 'premium_ratio_pct', header: 'Premium %', render: (r: any) => (r.premium_ratio_pct ?? 0) + '%' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'shift_started_at', header: 'Started', render: (r: any) => r.shift_started_at ? new Date(r.shift_started_at).toLocaleString('en-IN') : '—' },
    { key: 'hours_worked', header: 'Hours', render: (r: any) => String(r.hours_worked ?? 0) },
    { key: 'jobs_count', header: 'Jobs', render: (r: any) => String(r.jobs_count ?? 0) },
    { key: 'base_pay_rupees', header: 'Base ₹', render: (r: any) => inr(r.base_pay_rupees) },
    { key: 'night_premium_rupees', header: 'Premium ₹', render: (r: any) => inr(r.night_premium_rupees) },
    { key: 'total_pay_rupees', header: 'Total ₹', render: (r: any) => inr(r.total_pay_rupees) },
  ];

  const queueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '—' },
    { key: 'shifts_count', header: 'Shifts', render: (r: any) => String(r.shifts_count ?? 0) },
    { key: 'total_premium_rupees', header: 'Premium ₹', render: (r: any) => inr(r.total_premium_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => r.submitted_at ? new Date(r.submitted_at).toLocaleString('en-IN') : '—' },
  ];

  const reconCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'shifts_premium_rupees', header: 'Shifts Premium ₹', render: (r: any) => inr(r.shifts_premium_rupees) },
    { key: 'payouts_total_rupees', header: 'Payouts ₹', render: (r: any) => inr(r.payouts_total_rupees) },
    { key: 'delta_rupees', header: 'Δ ₹', render: (r: any) => inr(r.delta_rupees) },
    { key: 'payouts_paid_count', header: 'Paid Count', render: (r: any) => String(r.payouts_paid_count ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Night-Shift Comp Tracker</h1>
        <p className="text-sm text-gray-600">Per-engineer night-shift earnings, premium pay, reconciliation vs base, and founder approval queue.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Shifts (30d)</div>
          <div className="text-xl font-semibold">{inr(kpis.total_shifts)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Engineers</div>
          <div className="text-xl font-semibold">{inr(kpis.total_engineers)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Premium ₹ (30d)</div>
          <div className="text-xl font-semibold">{inr(kpis.total_premium_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Base ₹ (30d)</div>
          <div className="text-xl font-semibold">{inr(kpis.total_base_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Pending Approvals</div>
          <div className="text-xl font-semibold">{inr(kpis.pending_approvals)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Approved (MTD)</div>
          <div className="text-xl font-semibold">{inr(kpis.approved_this_month)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-Engineer Comp (30d)</h2>
        <DataTable
          rows={perEng}
          columns={perEngCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending Approval Queue</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reconciliation vs Payouts (30d)</h2>
        <DataTable
          rows={recon}
          columns={reconCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Shifts</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
