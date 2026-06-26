import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtInt(n: number | null | undefined) {
  if (n === null || n === undefined) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined) {
  if (!n) return '0';
  if (n >= 10000000) return (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return (n / 100000).toFixed(2) + ' L';
  return new Intl.NumberFormat('en-IN').format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, piecesRes, byFormatRes, byAudienceRes, byPillarRes, topRepRes, effRes, quarterRes] = await Promise.all([
    supabase.rpc('founder_r2825_kpis'),
    supabase.rpc('founder_r2825_pieces_overview'),
    supabase.rpc('founder_r2825_by_format'),
    supabase.rpc('founder_r2825_by_audience'),
    supabase.rpc('founder_r2825_by_pillar'),
    supabase.rpc('founder_r2825_top_repurposes'),
    supabase.rpc('founder_r2825_efficiency_leaderboard'),
    supabase.rpc('founder_r2825_quarter_rollup'),
  ]);

  const kpis = (kpisRes.data && kpisRes.data[0]) || {
    total_pieces: 0,
    total_views: 0,
    total_qualified_leads: 0,
    total_pipeline_rupees: 0,
    total_effort_hours: 0,
    avg_strategic_value: 0,
    evergreen_count: 0,
    total_repurposes: 0,
  };

  const pieces = piecesRes.data ?? [];
  const byFormat = byFormatRes.data ?? [];
  const byAudience = byAudienceRes.data ?? [];
  const byPillar = byPillarRes.data ?? [];
  const topRep = topRepRes.data ?? [];
  const eff = effRes.data ?? [];
  const quarters = quarterRes.data ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Quarterly Strategic Content Output Tracker</h1>
        <p className="text-sm text-gray-600">
          Piece × format × audience × performance × repurpose × strategic value
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Pieces" value={fmtInt(kpis.total_pieces)} />
        <Kpi label="Total Views" value={fmtInt(kpis.total_views)} />
        <Kpi label="Qualified Leads" value={fmtInt(kpis.total_qualified_leads)} />
        <Kpi label="Pipeline (Rupees)" value={fmtRupees(kpis.total_pipeline_rupees)} />
        <Kpi label="Effort Hours" value={fmtInt(kpis.total_effort_hours)} />
        <Kpi label="Avg Strategic Value" value={String(kpis.avg_strategic_value ?? 0)} />
        <Kpi label="Evergreen Pieces" value={fmtInt(kpis.evergreen_count)} />
        <Kpi label="Repurposes Shipped" value={fmtInt(kpis.total_repurposes)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Pieces</h2>
        <DataTable
          rows={pieces}
          rowKey={(r: any, i: number) => String(r.piece_title ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter },
            { key: 'piece_title', header: 'Title', render: (r: any) => r.piece_title },
            { key: 'format', header: 'Format', render: (r: any) => r.format },
            { key: 'primary_audience', header: 'Audience', render: (r: any) => r.primary_audience },
            { key: 'strategic_pillar', header: 'Pillar', render: (r: any) => r.strategic_pillar },
            { key: 'published_on', header: 'Published', render: (r: any) => r.published_on },
            { key: 'views', header: 'Views', render: (r: any) => fmtInt(r.views) },
            { key: 'qualified_leads', header: 'Leads', render: (r: any) => fmtInt(r.qualified_leads) },
            { key: 'pipeline_attributed_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.pipeline_attributed_rupees) },
            { key: 'effort_hours', header: 'Hours', render: (r: any) => String(r.effort_hours) },
            { key: 'strategic_value_score', header: 'Value', render: (r: any) => String(r.strategic_value_score) },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarter Rollup</h2>
        <DataTable
          rows={quarters}
          rowKey={(r: any, i: number) => String(r.quarter ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter },
            { key: 'pieces', header: 'Pieces', render: (r: any) => fmtInt(r.pieces) },
            { key: 'total_views', header: 'Views', render: (r: any) => fmtInt(r.total_views) },
            { key: 'total_leads', header: 'Leads', render: (r: any) => fmtInt(r.total_leads) },
            { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
            { key: 'avg_strategic_value', header: 'Avg Value', render: (r: any) => String(r.avg_strategic_value) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">By Format</h2>
        <DataTable
          rows={byFormat}
          rowKey={(r: any, i: number) => String(r.format ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'format', header: 'Format', render: (r: any) => r.format },
            { key: 'pieces', header: 'Pieces', render: (r: any) => fmtInt(r.pieces) },
            { key: 'total_views', header: 'Views', render: (r: any) => fmtInt(r.total_views) },
            { key: 'total_leads', header: 'Leads', render: (r: any) => fmtInt(r.total_leads) },
            { key: 'avg_strategic_value', header: 'Avg Value', render: (r: any) => String(r.avg_strategic_value) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">By Audience</h2>
        <DataTable
          rows={byAudience}
          rowKey={(r: any, i: number) => String(r.primary_audience ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'primary_audience', header: 'Audience', render: (r: any) => r.primary_audience },
            { key: 'pieces', header: 'Pieces', render: (r: any) => fmtInt(r.pieces) },
            { key: 'total_views', header: 'Views', render: (r: any) => fmtInt(r.total_views) },
            { key: 'total_leads', header: 'Leads', render: (r: any) => fmtInt(r.total_leads) },
            { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">By Strategic Pillar</h2>
        <DataTable
          rows={byPillar}
          rowKey={(r: any, i: number) => String(r.strategic_pillar ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'strategic_pillar', header: 'Pillar', render: (r: any) => r.strategic_pillar },
            { key: 'pieces', header: 'Pieces', render: (r: any) => fmtInt(r.pieces) },
            { key: 'avg_strategic_value', header: 'Avg Value', render: (r: any) => String(r.avg_strategic_value) },
            { key: 'total_effort_hours', header: 'Hours', render: (r: any) => String(r.total_effort_hours) },
            { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Repurposes (multiplier ranked)</h2>
        <DataTable
          rows={topRep}
          rowKey={(r: any, i: number) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'piece_title', header: 'Source Piece', render: (r: any) => r.piece_title },
            { key: 'derivative_format', header: 'Derivative', render: (r: any) => r.derivative_format },
            { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
            { key: 'shipped_on', header: 'Shipped', render: (r: any) => r.shipped_on },
            { key: 'incremental_views', header: 'Views', render: (r: any) => fmtInt(r.incremental_views) },
            { key: 'incremental_leads', header: 'Leads', render: (r: any) => fmtInt(r.incremental_leads) },
            { key: 'multiplier_score', header: 'Multiplier', render: (r: any) => String(r.multiplier_score) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Efficiency Leaderboard (value per hour)</h2>
        <DataTable
          rows={eff}
          rowKey={(r: any, i: number) => String(r.piece_title ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'piece_title', header: 'Piece', render: (r: any) => r.piece_title },
            { key: 'format', header: 'Format', render: (r: any) => r.format },
            { key: 'strategic_value_score', header: 'Value', render: (r: any) => String(r.strategic_value_score) },
            { key: 'effort_hours', header: 'Hours', render: (r: any) => String(r.effort_hours) },
            { key: 'value_per_hour', header: 'Value per Hour', render: (r: any) => String(r.value_per_hour) },
            { key: 'repurpose_count', header: 'Repurposes', render: (r: any) => fmtInt(r.repurpose_count) },
            { key: 'total_amplified_views', header: 'Amplified Views', render: (r: any) => fmtInt(r.total_amplified_views) },
          ]}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
    </div>
  );
}
