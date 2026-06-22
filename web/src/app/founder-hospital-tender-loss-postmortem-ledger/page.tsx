import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpisRes, lossesRes, causesRes, lessonsRes] = await Promise.all([
    sb.rpc('r2259_kpis'),
    sb.rpc('r2259_losses_overview'),
    sb.rpc('r2259_root_cause_breakdown'),
    sb.rpc('r2259_lessons_log'),
  ]);

  const kpis = (kpisRes.data?.[0] ?? {}) as Record<string, number | string>;
  const losses = (lossesRes.data ?? []) as Array<Record<string, unknown>>;
  const causes = (causesRes.data ?? []) as Array<Record<string, unknown>>;
  const lessons = (lessonsRes.data ?? []) as Array<Record<string, unknown>>;

  const rupees = (v: unknown) =>
    `₹${Number(v ?? 0).toLocaleString('en-IN')}`;
  const dt = (v: unknown) =>
    v ? new Date(String(v)).toLocaleDateString('en-IN') : '-';

  const lossCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'tender_title', header: 'Tender', render: (r) => String(r.tender_title ?? '') },
    { key: 'tender_value_rupees', header: 'Tender Value', render: (r) => rupees(r.tender_value_rupees) },
    { key: 'root_cause', header: 'Root Cause', render: (r) => String(r.root_cause ?? '') },
    { key: 'winning_competitor', header: 'Winner', render: (r) => String(r.winning_competitor ?? '-') },
    { key: 'our_bid_rupees', header: 'Our Bid', render: (r) => rupees(r.our_bid_rupees) },
    { key: 'winning_bid_rupees', header: 'Win Bid', render: (r) => rupees(r.winning_bid_rupees) },
    { key: 'price_gap_pct', header: 'Gap %', render: (r) => `${Number(r.price_gap_pct ?? 0).toFixed(2)}%` },
    { key: 'lessons_count', header: 'Lessons', render: (r) => `${r.applied_count ?? 0}/${r.lessons_count ?? 0}` },
    { key: 'decision_at', header: 'Decided', render: (r) => dt(r.decision_at) },
  ];

  const causeCols: Column<any>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r) => String(r.root_cause ?? '') },
    { key: 'losses_count', header: 'Losses', render: (r) => String(r.losses_count ?? 0) },
    { key: 'total_value_rupees', header: 'Lost Value', render: (r) => rupees(r.total_value_rupees) },
    { key: 'avg_price_gap_pct', header: 'Avg Gap %', render: (r) => `${Number(r.avg_price_gap_pct ?? 0).toFixed(2)}%` },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => String(r.hospital_name ?? '') },
    { key: 'tender_title', header: 'Tender', render: (r) => String(r.tender_title ?? '') },
    { key: 'lesson_text', header: 'Lesson', render: (r) => String(r.lesson_text ?? '') },
    { key: 'next_time_action', header: 'Next Time', render: (r) => String(r.next_time_action ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r) => String(r.owner_email ?? '') },
    { key: 'applied', header: 'Applied', render: (r) => (r.applied ? 'Yes' : 'No') },
    { key: 'applied_at', header: 'Applied At', render: (r) => dt(r.applied_at) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Tender Loss Post-Mortem Ledger</h1>
        <p className="text-sm text-gray-600">Tenders we lost, root cause, lessons learned & next-time actions</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <Kpi label="Total Losses" value={String(kpis.total_losses ?? 0)} />
        <Kpi label="Lost Value" value={rupees(kpis.total_value_rupees)} />
        <Kpi label="Applied Lessons" value={String(kpis.applied_lessons ?? 0)} />
        <Kpi label="Open Lessons" value={String(kpis.open_lessons ?? 0)} />
        <Kpi label="Avg Gap %" value={`${Number(kpis.avg_price_gap_pct ?? 0).toFixed(2)}%`} />
        <Kpi label="Losses 30d" value={String(kpis.losses_30d ?? 0)} />
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lost Tenders</h2>
        <DataTable columns={lossCols} rows={losses} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Root Cause Breakdown</h2>
        <DataTable columns={causeCols} rows={causes} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lessons Log</h2>
        <DataTable columns={lessonCols} rows={lessons} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-lg font-bold">{value}</div>
    </div>
  );
}
