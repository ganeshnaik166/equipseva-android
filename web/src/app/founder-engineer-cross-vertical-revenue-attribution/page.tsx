import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type VerticalRow = {
  vertical: string;
  engineer_count: number;
  total_jobs: number;
  gross_revenue_rupees: number;
  platform_take_rupees: number;
  avg_csat: number | null;
};

type EngineerRow = {
  engineer_user_id: string;
  engineer_email: string;
  verticals_served: number;
  primary_vertical: string | null;
  total_revenue_rupees: number;
  total_jobs: number;
  vertical_list: string;
};

type TiltRow = {
  engineer_user_id: string;
  engineer_email: string;
  snapshot_date: string;
  total_verticals_served: number;
  top_vertical: string | null;
  top_vertical_share_pct: number | null;
  tilt_classification: string;
  total_revenue_rupees: number;
  herfindahl_index: number | null;
};

type DistRow = {
  tilt_classification: string;
  engineer_count: number;
  avg_top_share_pct: number | null;
  avg_revenue_rupees: number | null;
};

type GeneralistRow = {
  engineer_user_id: string;
  engineer_email: string;
  verticals_count: number;
  total_revenue_rupees: number;
  avg_csat: number | null;
};

type SpecialistRow = {
  engineer_user_id: string;
  engineer_email: string;
  top_vertical: string | null;
  top_vertical_share_pct: number | null;
  total_revenue_rupees: number;
  snapshot_date: string;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    { data: verticals },
    { data: engineers },
    { data: tilts },
    { data: distribution },
    { data: generalists },
    { data: specialists },
  ] = await Promise.all([
    supabase.rpc('fn_r2398_revenue_by_vertical'),
    supabase.rpc('fn_r2398_engineer_breakdown'),
    supabase.rpc('fn_r2398_tilt_roster'),
    supabase.rpc('fn_r2398_tilt_distribution'),
    supabase.rpc('fn_r2398_top_generalists'),
    supabase.rpc('fn_r2398_highly_specialized'),
  ]);

  const verticalCols: Column<any>[] = [
    { key: 'vertical', header: 'Vertical', render: (r: VerticalRow) => r.vertical },
    { key: 'engineer_count', header: 'Engineers', render: (r: VerticalRow) => r.engineer_count },
    { key: 'total_jobs', header: 'Jobs', render: (r: VerticalRow) => r.total_jobs },
    { key: 'gross_revenue_rupees', header: 'Gross Revenue', render: (r: VerticalRow) => rupees(r.gross_revenue_rupees) },
    { key: 'platform_take_rupees', header: 'Platform Take', render: (r: VerticalRow) => rupees(r.platform_take_rupees) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: VerticalRow) => r.avg_csat ?? '-' },
  ];

  const engineerCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: EngineerRow) => r.engineer_email },
    { key: 'verticals_served', header: 'Verticals', render: (r: EngineerRow) => r.verticals_served },
    { key: 'primary_vertical', header: 'Primary', render: (r: EngineerRow) => r.primary_vertical ?? '-' },
    { key: 'vertical_list', header: 'All Verticals', render: (r: EngineerRow) => r.vertical_list },
    { key: 'total_jobs', header: 'Jobs', render: (r: EngineerRow) => r.total_jobs },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: EngineerRow) => rupees(r.total_revenue_rupees) },
  ];

  const tiltCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: TiltRow) => r.engineer_email },
    { key: 'snapshot_date', header: 'Snapshot', render: (r: TiltRow) => r.snapshot_date },
    { key: 'tilt_classification', header: 'Tilt', render: (r: TiltRow) => r.tilt_classification },
    { key: 'total_verticals_served', header: 'Verticals', render: (r: TiltRow) => r.total_verticals_served },
    { key: 'top_vertical', header: 'Top Vertical', render: (r: TiltRow) => r.top_vertical ?? '-' },
    { key: 'top_vertical_share_pct', header: 'Top Share %', render: (r: TiltRow) => r.top_vertical_share_pct != null ? r.top_vertical_share_pct + '%' : '-' },
    { key: 'herfindahl_index', header: 'HHI', render: (r: TiltRow) => r.herfindahl_index ?? '-' },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: TiltRow) => rupees(r.total_revenue_rupees) },
  ];

  const distCols: Column<any>[] = [
    { key: 'tilt_classification', header: 'Classification', render: (r: DistRow) => r.tilt_classification },
    { key: 'engineer_count', header: 'Engineers', render: (r: DistRow) => r.engineer_count },
    { key: 'avg_top_share_pct', header: 'Avg Top Share %', render: (r: DistRow) => r.avg_top_share_pct != null ? r.avg_top_share_pct + '%' : '-' },
    { key: 'avg_revenue_rupees', header: 'Avg Revenue', render: (r: DistRow) => rupees(r.avg_revenue_rupees) },
  ];

  const generalistCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: GeneralistRow) => r.engineer_email },
    { key: 'verticals_count', header: 'Verticals (>=3)', render: (r: GeneralistRow) => r.verticals_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: GeneralistRow) => rupees(r.total_revenue_rupees) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: GeneralistRow) => r.avg_csat ?? '-' },
  ];

  const specialistCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: SpecialistRow) => r.engineer_email },
    { key: 'top_vertical', header: 'Vertical', render: (r: SpecialistRow) => r.top_vertical ?? '-' },
    { key: 'top_vertical_share_pct', header: 'Share %', render: (r: SpecialistRow) => r.top_vertical_share_pct != null ? r.top_vertical_share_pct + '%' : '-' },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: SpecialistRow) => rupees(r.total_revenue_rupees) },
    { key: 'snapshot_date', header: 'Snapshot', render: (r: SpecialistRow) => r.snapshot_date },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Engineer Cross-Vertical Revenue Attribution
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Revenue split by medical vertical. Spot tilt (over-concentration share &gt;=80%) vs balanced
        generalists serving 3+ verticals. Herfindahl index quantifies concentration.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Revenue by Vertical</h2>
        <DataTable
          rows={verticals ?? []}
          columns={verticalCols}
          emptyMessage="No vertical revenue data."
          rowKey={(r: VerticalRow) => r.vertical}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tilt Classification Distribution</h2>
        <DataTable
          rows={distribution ?? []}
          columns={distCols}
          emptyMessage="No tilt snapshots yet."
          rowKey={(r: DistRow) => r.tilt_classification}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Per-Engineer Vertical Breakdown</h2>
        <DataTable
          rows={engineers ?? []}
          columns={engineerCols}
          emptyMessage="No engineer revenue rows."
          rowKey={(r: EngineerRow) => r.engineer_user_id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tilt Roster (latest snapshots)</h2>
        <DataTable
          rows={tilts ?? []}
          columns={tiltCols}
          emptyMessage="No tilt classifications computed."
          rowKey={(r: TiltRow) => r.engineer_user_id + '|' + r.snapshot_date}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Generalists (3+ verticals)</h2>
        <DataTable
          rows={generalists ?? []}
          columns={generalistCols}
          emptyMessage="No generalists yet — average engineer serves <3 verticals."
          rowKey={(r: GeneralistRow) => r.engineer_user_id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Highly Specialized (&gt;=80% from one vertical)</h2>
        <DataTable
          rows={specialists ?? []}
          columns={specialistCols}
          emptyMessage="No highly-specialized engineers in latest snapshot."
          rowKey={(r: SpecialistRow) => r.engineer_user_id}
        />
      </section>
    </main>
  );
}
