import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-[11px] uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function GradeBadge({ grade }: { grade: string }) {
  const color =
    grade === 'A' ? 'bg-emerald-100 text-emerald-800' :
    grade === 'B' ? 'bg-sky-100 text-sky-800' :
    grade === 'C' ? 'bg-amber-100 text-amber-800' :
    'bg-rose-100 text-rose-800';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs font-semibold ${color}`}>{grade}</span>;
}

export default async function VendorSlaScorecardPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, scorecardsRes, bottom5Res, queueRes, trendRes, topRes, breakdownRes] = await Promise.all([
    sb.rpc('founder_vendor_sla_kpis'),
    sb.rpc('founder_vendor_sla_scorecards'),
    sb.rpc('founder_vendor_sla_bottom5'),
    sb.rpc('founder_vendor_replacement_queue'),
    sb.rpc('founder_vendor_grade_trend'),
    sb.rpc('founder_vendor_sla_top_performers'),
    sb.rpc('founder_vendor_sla_breakdown'),
  ]);

  const kpis = (kpisRes.data && kpisRes.data[0]) || {};
  const scorecards = scorecardsRes.data || [];
  const bottom5 = bottom5Res.data || [];
  const queue = queueRes.data || [];
  const trend = trendRes.data || [];
  const top = topRes.data || [];
  const breakdown = breakdownRes.data || [];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4">
      <header className="space-y-1">
        <div className="text-[11px] uppercase tracking-wide text-neutral-500">Operations / r1467</div>
        <h1 className="text-2xl font-bold tracking-tight">Vendor SLA Scorecard</h1>
        <p className="text-sm text-neutral-600">
          Delivery, quality and payment SLAs graded A/B/C/D each quarter. Bottom-5 enter the replacement queue pending founder approval.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Quarter snapshot</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi label="Current Quarter" value={kpis.current_quarter ?? "—"} />
          <Kpi label="Total Vendors" value={kpis.total_vendors ?? 0} />
          <Kpi label="Scored Vendors" value={kpis.scored_vendors ?? 0} />
          <Kpi label="Total Value" value={formatRupees(kpis.total_value_rupees ?? 0)} />
          <Kpi label="Grade A" value={kpis.grade_a ?? 0} />
          <Kpi label="Grade B" value={kpis.grade_b ?? 0} />
          <Kpi label="Grade C" value={kpis.grade_c ?? 0} />
          <Kpi label="Grade D" value={kpis.grade_d ?? 0} />
          <Kpi label="Avg Overall" value={kpis.avg_overall ?? 0} />
          <Kpi label="Avg Delivery" value={kpis.avg_delivery ?? 0} />
          <Kpi label="Avg Quality" value={kpis.avg_quality ?? 0} />
          <Kpi label="Avg Payment" value={kpis.avg_payment ?? 0} />
          <Kpi label="Bottom-5 Pool" value={kpis.bottom5_count ?? 0} />
          <Kpi label="Queue Pending" value={kpis.pending_replacements ?? 0} />
          <Kpi label="Queue Approved" value={kpis.approved_replacements ?? 0} />
          <Kpi label="Queue Executed" value={kpis.executed_replacements ?? 0} />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Current quarter scorecards</h2>
        <DataTable
          rows={scorecards}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? "—" },
            { key: 'orders', header: 'Orders', render: (r: any) => r.total_orders ?? 0 },
            { key: 'value', header: 'Value', render: (r: any) => formatRupees(r.total_value_rupees ?? 0) },
            { key: 'delivery', header: 'Delivery', render: (r: any) => r.delivery_score ?? 0 },
            { key: 'quality', header: 'Quality', render: (r: any) => r.quality_score ?? 0 },
            { key: 'payment', header: 'Payment', render: (r: any) => r.payment_score ?? 0 },
            { key: 'overall', header: 'Overall', render: (r: any) => r.overall_score ?? 0 },
            { key: 'grade', header: 'Grade', render: (r: any) => <GradeBadge grade={r.grade ?? 'C'} /> },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Bottom-5 replacement candidates</h2>
        <DataTable
          rows={bottom5}
          rowKey={(r: any) => r.vendor_org_id}
          columns={[
            { key: 'rank', header: 'Rank', render: (r: any) => `#${r.rank ?? "—"}` },
            { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? "—" },
            { key: 'overall', header: 'Overall', render: (r: any) => r.overall_score ?? 0 },
            { key: 'grade', header: 'Grade', render: (r: any) => <GradeBadge grade={r.grade ?? 'D'} /> },
            { key: 'delivery', header: 'Delivery', render: (r: any) => r.delivery_score ?? 0 },
            { key: 'quality', header: 'Quality', render: (r: any) => r.quality_score ?? 0 },
            { key: 'payment', header: 'Payment', render: (r: any) => r.payment_score ?? 0 },
            { key: 'value', header: 'Value', render: (r: any) => formatRupees(r.total_value_rupees ?? 0) },
            { key: 'queued', header: 'Queued?', render: (r: any) => r.already_queued ? 'Yes' : 'No' },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Replacement queue (founder approval)</h2>
        <DataTable
          rows={queue}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? "—" },
            { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter_label ?? "—" },
            { key: 'rank', header: 'Rank', render: (r: any) => `#${r.bottom_rank ?? "—"}` },
            { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? "—" },
            { key: 'replacement', header: 'Proposed', render: (r: any) => r.proposed_replacement_name ?? "—" },
            { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
            { key: 'decided', header: 'Decided At', render: (r: any) => r.founder_decision_at ? new Date(r.founder_decision_at).toLocaleString('en-IN') : "—" },
            { key: 'note', header: 'Note', render: (r: any) => r.founder_decision_note ?? "—" },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Grade trend (last 6 quarters)</h2>
        <DataTable
          rows={trend}
          rowKey={(r: any) => r.quarter_label}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter_label ?? "—" },
            { key: 'vendors', header: 'Vendors', render: (r: any) => r.vendor_count ?? 0 },
            { key: 'a', header: 'A', render: (r: any) => r.grade_a ?? 0 },
            { key: 'b', header: 'B', render: (r: any) => r.grade_b ?? 0 },
            { key: 'c', header: 'C', render: (r: any) => r.grade_c ?? 0 },
            { key: 'd', header: 'D', render: (r: any) => r.grade_d ?? 0 },
            { key: 'avg', header: 'Avg Score', render: (r: any) => r.avg_score ?? 0 },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Top performers (A & B grade)</h2>
        <DataTable
          rows={top}
          rowKey={(r: any) => r.vendor_org_id}
          columns={[
            { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? "—" },
            { key: 'grade', header: 'Grade', render: (r: any) => <GradeBadge grade={r.grade ?? 'B'} /> },
            { key: 'overall', header: 'Overall', render: (r: any) => r.overall_score ?? 0 },
            { key: 'orders', header: 'Orders', render: (r: any) => r.total_orders ?? 0 },
            { key: 'value', header: 'Value', render: (r: any) => formatRupees(r.total_value_rupees ?? 0) },
            { key: 'delivery', header: 'Delivery', render: (r: any) => r.delivery_score ?? 0 },
            { key: 'quality', header: 'Quality', render: (r: any) => r.quality_score ?? 0 },
            { key: 'payment', header: 'Payment', render: (r: any) => r.payment_score ?? 0 },
          ]}
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-neutral-700">Per-dimension breakdown</h2>
        <DataTable
          rows={breakdown}
          rowKey={(r: any) => r.vendor_org_id}
          columns={[
            { key: 'vendor', header: 'Vendor', render: (r: any) => r.vendor_name ?? "—" },
            { key: 'orders', header: 'Orders', render: (r: any) => r.total_orders ?? 0 },
            { key: 'ontime', header: 'On-time %', render: (r: any) => `${r.on_time_pct ?? 0}%` },
            { key: 'late', header: 'Late %', render: (r: any) => `${r.late_pct ?? 0}%` },
            { key: 'reject', header: 'Reject %', render: (r: any) => `${r.quality_reject_pct ?? 0}%` },
            { key: 'dispute', header: 'Dispute %', render: (r: any) => `${r.dispute_pct ?? 0}%` },
            { key: 'grade', header: 'Grade', render: (r: any) => <GradeBadge grade={r.grade ?? 'C'} /> },
          ]}
        />
      </section>

      <footer className="pt-4 text-xs text-neutral-500">
        r1467 {"·"} vendor_sla_scorecards_v2 + vendor_replacement_queue_v2 {"·"} 7 RPCs {"·"} founder-only
      </footer>
    </div>
  );
}
