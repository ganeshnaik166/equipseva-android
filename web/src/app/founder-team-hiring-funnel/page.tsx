import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [overview, byRole, conversion, tth, pipeline, source, ctc] = await Promise.all([
    sb.rpc('founder_hiring_funnel_overview_r2273'),
    sb.rpc('founder_hiring_funnel_by_role_r2273'),
    sb.rpc('founder_hiring_conversion_r2273'),
    sb.rpc('founder_hiring_time_to_hire_r2273'),
    sb.rpc('founder_hiring_active_pipeline_r2273'),
    sb.rpc('founder_hiring_source_effectiveness_r2273'),
    sb.rpc('founder_hiring_offer_ctc_r2273'),
  ]);

  const overviewCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'applicants', header: 'Applicants', render: (r) => r.applicants },
  ];
  const byRoleCols: Column<any>[] = [
    { key: 'role_bucket', header: 'Role', render: (r) => r.role_bucket },
    { key: 'applied', header: 'Applied', render: (r) => r.applied },
    { key: 'screened', header: 'Screened', render: (r) => r.screened },
    { key: 'interviewed', header: 'Interviewed', render: (r) => r.interviewed },
    { key: 'offered', header: 'Offered', render: (r) => r.offered },
    { key: 'joined', header: 'Joined', render: (r) => r.joined },
  ];
  const convCols: Column<any>[] = [
    { key: 'role_bucket', header: 'Role', render: (r) => r.role_bucket },
    { key: 'screen_rate', header: 'Screen %', render: (r) => r.screen_rate ?? '-' },
    { key: 'interview_rate', header: 'Interview %', render: (r) => r.interview_rate ?? '-' },
    { key: 'offer_rate', header: 'Offer %', render: (r) => r.offer_rate ?? '-' },
    { key: 'join_rate', header: 'Join %', render: (r) => r.join_rate ?? '-' },
  ];
  const tthCols: Column<any>[] = [
    { key: 'role_bucket', header: 'Role', render: (r) => r.role_bucket },
    { key: 'avg_days_to_screen', header: 'Avg days to screen', render: (r) => r.avg_days_to_screen ?? '-' },
    { key: 'avg_days_to_interview', header: 'Avg days to interview', render: (r) => r.avg_days_to_interview ?? '-' },
    { key: 'avg_days_to_offer', header: 'Avg days to offer', render: (r) => r.avg_days_to_offer ?? '-' },
    { key: 'avg_days_to_join', header: 'Avg days to join', render: (r) => r.avg_days_to_join ?? '-' },
  ];
  const pipeCols: Column<any>[] = [
    { key: 'applicant_name', header: 'Applicant', render: (r) => r.applicant_name },
    { key: 'role_bucket', header: 'Role', render: (r) => r.role_bucket },
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'source', header: 'Source', render: (r) => r.source },
    { key: 'days_in_pipeline', header: 'Days in pipeline', render: (r) => r.days_in_pipeline },
  ];
  const sourceCols: Column<any>[] = [
    { key: 'source', header: 'Source', render: (r) => r.source },
    { key: 'applied', header: 'Applied', render: (r) => r.applied },
    { key: 'joined', header: 'Joined', render: (r) => r.joined },
    { key: 'join_rate', header: 'Join %', render: (r) => r.join_rate ?? '-' },
  ];
  const ctcCols: Column<any>[] = [
    { key: 'role_bucket', header: 'Role', render: (r) => r.role_bucket },
    { key: 'offers_count', header: 'Offers', render: (r) => r.offers_count },
    { key: 'avg_offered_lakhs', header: 'Avg offered (L)', render: (r) => r.avg_offered_lakhs ?? '-' },
    { key: 'avg_expected_lakhs', header: 'Avg expected (L)', render: (r) => r.avg_expected_lakhs ?? '-' },
    { key: 'gap_pct', header: 'Gap %', render: (r) => r.gap_pct ?? '-' },
  ];

  return (
    <main className="p-6 space-y-8">
      <h1 className="text-2xl font-bold">Team hiring funnel</h1>
      <p className="text-sm text-gray-600">
        Applicants &gt; screened &gt; interviewed &gt; offer &gt; joined. Conversion &amp; time-to-hire per role bucket.
      </p>

      <section>
        <h2 className="text-lg font-semibold mb-2">Funnel overview</h2>
        <DataTable columns={overviewCols} rows={overview.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Funnel by role bucket</h2>
        <DataTable columns={byRoleCols} rows={byRole.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Conversion rates by role</h2>
        <DataTable columns={convCols} rows={conversion.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Time to hire (avg days)</h2>
        <DataTable columns={tthCols} rows={tth.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active pipeline</h2>
        <DataTable columns={pipeCols} rows={pipeline.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Source effectiveness</h2>
        <DataTable columns={sourceCols} rows={source.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Offer CTC summary</h2>
        <DataTable columns={ctcCols} rows={ctc.data ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
