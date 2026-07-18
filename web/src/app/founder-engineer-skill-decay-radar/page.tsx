import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [inventory, alerts, distribution, expiring, neverAssessed, topDecayed, pipeline] = await Promise.all([
    sb.rpc('list_inventory_r2414'),
    sb.rpc('list_alerts_r2414'),
    sb.rpc('decay_distribution_r2414'),
    sb.rpc('expiring_certs_r2414'),
    sb.rpc('never_assessed_r2414'),
    sb.rpc('top_decayed_engineers_r2414'),
    sb.rpc('refresher_pipeline_r2414'),
  ]);

  const invRows = inventory.data ?? [];
  const alertRows = alerts.data ?? [];
  const distRows = distribution.data ?? [];
  const expRows = expiring.data ?? [];
  const naRows = neverAssessed.data ?? [];
  const topRows = topDecayed.data ?? [];
  const pipeRows = pipeline.data ?? [];

  const invCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category },
    { key: 'proficiency_level', header: 'Level', render: (r: any) => r.proficiency_level },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => r.last_used_at ? new Date(r.last_used_at).toLocaleDateString() : '-' },
    { key: 'decay_days', header: 'Decay days', render: (r: any) => r.decay_days ?? '-' },
    { key: 'last_score_pct', header: 'Score %', render: (r: any) => r.last_score_pct ?? '-' },
    { key: 'certification_expires_at', header: 'Cert expires', render: (r: any) => r.certification_expires_at ? new Date(r.certification_expires_at).toLocaleDateString() : '-' },
    { key: 'certification_authority', header: 'Authority', render: (r: any) => r.certification_authority ?? '-' },
  ];

  const alertCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'alert_kind', header: 'Kind', render: (r: any) => r.alert_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'decay_days', header: 'Decay days', render: (r: any) => r.decay_days },
    { key: 'recommended_refresher', header: 'Refresher', render: (r: any) => r.recommended_refresher ?? '-' },
    { key: 'refresher_due_at', header: 'Due', render: (r: any) => r.refresher_due_at ? new Date(r.refresher_due_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const distCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'skill_count', header: 'Skills', render: (r: any) => r.skill_count },
  ];

  const expCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'certification_authority', header: 'Authority', render: (r: any) => r.certification_authority ?? '-' },
    { key: 'certification_expires_at', header: 'Expires', render: (r: any) => new Date(r.certification_expires_at).toLocaleDateString() },
    { key: 'days_until_expiry', header: 'Days left', render: (r: any) => r.days_until_expiry },
  ];

  const naCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category },
    { key: 'proficiency_level', header: 'Level', render: (r: any) => r.proficiency_level },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => r.last_used_at ? new Date(r.last_used_at).toLocaleDateString() : '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'decayed_skill_count', header: 'Decayed skills', render: (r: any) => r.decayed_skill_count },
    { key: 'avg_decay_days', header: 'Avg decay days', render: (r: any) => r.avg_decay_days },
    { key: 'max_decay_days', header: 'Max decay days', render: (r: any) => r.max_decay_days },
  ];

  const pipeCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'alert_count', header: 'Alerts', render: (r: any) => r.alert_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r: any) => r.high_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Skill Decay Radar</h1>
        <p className="text-sm text-gray-600">Skills × last-used × decay days × refresher pipeline × certification expiry.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Skill inventory</h2>
        <DataTable
          rows={invRows}
          columns={invCols}
          emptyMessage="No skills tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decay alerts</h2>
        <DataTable
          rows={alertRows}
          columns={alertCols}
          emptyMessage="No open alerts."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decay distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Expiring certifications (next 180 days)</h2>
        <DataTable
          rows={expRows}
          columns={expCols}
          emptyMessage="No expiring certs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Never assessed</h2>
        <DataTable
          rows={naRows}
          columns={naCols}
          emptyMessage="All skills assessed."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top decayed engineers (&gt;90 days)</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No decayed engineers."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Refresher pipeline</h2>
        <DataTable
          rows={pipeRows}
          columns={pipeCols}
          emptyMessage="No pipeline data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
