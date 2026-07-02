import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/data-table';
import type { Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type Overview = { total_lessons: number; total_endorsements: number; total_incidents_prevented: number; sentinel_count: number };
type Quarter = { quarter: string; lesson_count: number; incidents_prevented: number; sentinel_count: number };
type Category = { device_category: string; lesson_count: number; incidents_prevented: number; avg_endorsement: number };
type Severity = { severity: string; lesson_count: number; incidents_prevented: number };
type TopLesson = { lesson_title: string; device_category: string; severity: string; incidents_prevented: number; endorsement_count: number };
type Endorse = { endorser_role: string; endorsement_count: number; avg_weight: number };
type Recent = { lesson_title: string; device_category: string; severity: string; published_at: string };
type Sentinel = { lesson_title: string; device_category: string; root_cause: string; corrective_action: string; incidents_prevented: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, qt, cat, sev, top, end, rec, sen] = await Promise.all([
    supabase.rpc('founder_psl_r2969_overview'),
    supabase.rpc('founder_psl_r2969_by_quarter'),
    supabase.rpc('founder_psl_r2969_by_category'),
    supabase.rpc('founder_psl_r2969_by_severity'),
    supabase.rpc('founder_psl_r2969_top_lessons'),
    supabase.rpc('founder_psl_r2969_endorsement_breakdown'),
    supabase.rpc('founder_psl_r2969_recent_published'),
    supabase.rpc('founder_psl_r2969_sentinel_focus'),
  ]);

  const overview: Overview | null = (ov.data?.[0] as Overview) ?? null;
  const quarters: Quarter[] = (qt.data as Quarter[]) ?? [];
  const cats: Category[] = (cat.data as Category[]) ?? [];
  const sevs: Severity[] = (sev.data as Severity[]) ?? [];
  const tops: TopLesson[] = (top.data as TopLesson[]) ?? [];
  const ends: Endorse[] = (end.data as Endorse[]) ?? [];
  const recs: Recent[] = (rec.data as Recent[]) ?? [];
  const sens: Sentinel[] = (sen.data as Sentinel[]) ?? [];

  const qCols: Column<Quarter>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Lessons', accessor: (r) => r.lesson_count },
    { header: 'Incidents prevented', accessor: (r) => r.incidents_prevented },
    { header: 'Sentinel', accessor: (r) => r.sentinel_count },
  ];
  const cCols: Column<Category>[] = [
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'Lessons', accessor: (r) => r.lesson_count },
    { header: 'Prevented', accessor: (r) => r.incidents_prevented },
    { header: 'Avg endorsement', accessor: (r) => r.avg_endorsement },
  ];
  const sCols: Column<Severity>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Lessons', accessor: (r) => r.lesson_count },
    { header: 'Prevented', accessor: (r) => r.incidents_prevented },
  ];
  const tCols: Column<TopLesson>[] = [
    { header: 'Lesson', accessor: (r) => r.lesson_title },
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Prevented', accessor: (r) => r.incidents_prevented },
    { header: 'Endorsements', accessor: (r) => r.endorsement_count },
  ];
  const eCols: Column<Endorse>[] = [
    { header: 'Role', accessor: (r) => r.endorser_role },
    { header: 'Count', accessor: (r) => r.endorsement_count },
    { header: 'Avg weight', accessor: (r) => r.avg_weight },
  ];
  const rCols: Column<Recent>[] = [
    { header: 'Lesson', accessor: (r) => r.lesson_title },
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Published', accessor: (r) => new Date(r.published_at).toLocaleDateString() },
  ];
  const senCols: Column<Sentinel>[] = [
    { header: 'Lesson', accessor: (r) => r.lesson_title },
    { header: 'Category', accessor: (r) => r.device_category },
    { header: 'Root cause', accessor: (r) => r.root_cause },
    { header: 'Corrective action', accessor: (r) => r.corrective_action },
    { header: 'Prevented', accessor: (r) => r.incidents_prevented },
  ];

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Quarterly Patient-Safety Lessons-Learned Library</h1>
      <p className="text-sm text-gray-600">Engineer-driven safety lessons rolled up across quarters & device categories.</p>

      {overview && (
        <div className="grid grid-cols-4 gap-4">
          <div className="border rounded p-4"><div className="text-xs text-gray-500">Total lessons</div><div className="text-2xl font-semibold">{overview.total_lessons}</div></div>
          <div className="border rounded p-4"><div className="text-xs text-gray-500">Endorsements</div><div className="text-2xl font-semibold">{overview.total_endorsements}</div></div>
          <div className="border rounded p-4"><div className="text-xs text-gray-500">Incidents prevented</div><div className="text-2xl font-semibold">{overview.total_incidents_prevented}</div></div>
          <div className="border rounded p-4"><div className="text-xs text-gray-500">Sentinel events</div><div className="text-2xl font-semibold">{overview.sentinel_count}</div></div>
        </div>
      )}

      <section>
        <h2 className="text-lg font-medium mb-2">By quarter</h2>
        <DataTable rows={quarters} columns={qCols} emptyMessage="No quarters" rowKey={(r, i) => String(r.quarter ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">By device category</h2>
        <DataTable rows={cats} columns={cCols} emptyMessage="No categories" rowKey={(r, i) => String(r.device_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">By severity</h2>
        <DataTable rows={sevs} columns={sCols} emptyMessage="No severities" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top lessons (by incidents prevented)</h2>
        <DataTable rows={tops} columns={tCols} emptyMessage="No lessons" rowKey={(r, i) => String(r.lesson_title ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Endorsement breakdown</h2>
        <DataTable rows={ends} columns={eCols} emptyMessage="No endorsements" rowKey={(r, i) => String(r.endorser_role ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recently published</h2>
        <DataTable rows={recs} columns={rCols} emptyMessage="None" rowKey={(r, i) => String(r.lesson_title ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Sentinel-event focus</h2>
        <DataTable rows={sens} columns={senCols} emptyMessage="None" rowKey={(r, i) => String(r.lesson_title ?? i)} />
      </section>
    </div>
  );
}
