import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [ov, tb, cr, top, fl, au, ad] = await Promise.all([
    sb.rpc('founder_r2964_coverage_overview'),
    sb.rpc('founder_r2964_tier_breakdown'),
    sb.rpc('founder_r2964_city_rollup'),
    sb.rpc('founder_r2964_top_engineers'),
    sb.rpc('founder_r2964_flagged_engineers'),
    sb.rpc('founder_r2964_audit_summary'),
    sb.rpc('founder_r2964_audit_detail'),
  ]);

  const ovCols: Column<any>[] = [
    { header: 'Month', accessor: (r) => r.month_start },
    { header: 'Engineers', accessor: (r) => r.engineers_tracked },
    { header: 'Avg Photo %', accessor: (r) => r.avg_photo_pct },
    { header: 'Avg Geotag %', accessor: (r) => r.avg_geotag_pct },
    { header: 'Platinum', accessor: (r) => r.platinum_cnt },
    { header: 'Flagged', accessor: (r) => r.flagged_cnt },
  ];
  const tbCols: Column<any>[] = [
    { header: 'Tier', accessor: (r) => r.quality_tier },
    { header: 'Engineers', accessor: (r) => r.engineer_count },
    { header: 'Total Jobs', accessor: (r) => r.total_jobs },
    { header: 'Avg Photo %', accessor: (r) => r.avg_photo_pct },
    { header: 'Avg Geotag %', accessor: (r) => r.avg_geotag_pct },
  ];
  const crCols: Column<any>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Engineers', accessor: (r) => r.engineers },
    { header: 'Total Jobs', accessor: (r) => r.total_jobs },
    { header: 'Avg Photo %', accessor: (r) => r.avg_photo_pct },
    { header: 'Avg Geotag %', accessor: (r) => r.avg_geotag_pct },
  ];
  const topCols: Column<any>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Customer', accessor: (r) => r.customer_org_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Jobs', accessor: (r) => r.jobs_completed },
    { header: 'Photo %', accessor: (r) => r.photo_coverage_pct },
    { header: 'Geotag %', accessor: (r) => r.geotag_coverage_pct },
    { header: 'Tier', accessor: (r) => r.quality_tier },
  ];
  const flCols: Column<any>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Customer', accessor: (r) => r.customer_org_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Jobs', accessor: (r) => r.jobs_completed },
    { header: 'Photo %', accessor: (r) => r.photo_coverage_pct },
    { header: 'Geotag %', accessor: (r) => r.geotag_coverage_pct },
    { header: 'Notes', accessor: (r) => r.notes },
  ];
  const auCols: Column<any>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Photos', accessor: (r) => r.total_photos },
    { header: 'Blurry', accessor: (r) => r.total_blurry },
    { header: 'Off-site', accessor: (r) => r.total_off_site },
    { header: 'Avg Reject %', accessor: (r) => r.avg_rejection_pct },
  ];
  const adCols: Column<any>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Customer', accessor: (r) => r.customer_org_name },
    { header: 'Audit Date', accessor: (r) => r.audit_date },
    { header: 'Photos', accessor: (r) => r.audited_photo_count },
    { header: 'Blurry', accessor: (r) => r.blurry_count },
    { header: 'Off-site', accessor: (r) => r.off_site_count },
    { header: 'Dup', accessor: (r) => r.duplicate_count },
    { header: 'Reject %', accessor: (r) => r.rejection_rate_pct },
    { header: 'Status', accessor: (r) => r.audit_status },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Repair-Job Photo-Evidence Geo-Tag Coverage Quality</h1>
        <p className="text-sm text-gray-600">Round r2964 — photo & geotag coverage per engineer per customer per month.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coverage Overview</h2>
        <DataTable rows={ov.data ?? []} columns={ovCols} emptyMessage="No coverage data" rowKey={(r, i) => String(r.month_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quality Tier Breakdown</h2>
        <DataTable rows={tb.data ?? []} columns={tbCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.quality_tier ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
        <DataTable rows={cr.data ?? []} columns={crCols} emptyMessage="No city data" rowKey={(r, i) => String(r.city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Engineers (photo coverage &gt;= 90%)</h2>
        <DataTable rows={top.data ?? []} columns={topCols} emptyMessage="No top engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Flagged Engineers (coverage &lt; 80%)</h2>
        <DataTable rows={fl.data ?? []} columns={flCols} emptyMessage="No flagged engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Summary</h2>
        <DataTable rows={au.data ?? []} columns={auCols} emptyMessage="No audits" rowKey={(r, i) => String(r.audit_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Detail</h2>
        <DataTable rows={ad.data ?? []} columns={adCols} emptyMessage="No audit detail" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
