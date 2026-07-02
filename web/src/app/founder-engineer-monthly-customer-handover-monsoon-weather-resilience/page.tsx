import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, weatherRes, leaderboardRes, cityRes, kitRes, refineRes, recentRes, outcomeRes] = await Promise.all([
    supabase.rpc('founder_r2870_handover_overview'),
    supabase.rpc('founder_r2870_weather_breakdown'),
    supabase.rpc('founder_r2870_engineer_leaderboard'),
    supabase.rpc('founder_r2870_city_impact'),
    supabase.rpc('founder_r2870_preparedness_kit_correlation'),
    supabase.rpc('founder_r2870_refinement_queue'),
    supabase.rpc('founder_r2870_recent_handovers'),
    supabase.rpc('founder_r2870_outcome_distribution'),
  ]);

  const overview = (overviewRes.data ?? [])[0] ?? {
    total_handovers: 0,
    weather_disrupted: 0,
    avg_delay_min: 0,
    avg_csat: 0,
    avg_preparedness: 0,
  };
  const weather = weatherRes.data ?? [];
  const leaderboard = leaderboardRes.data ?? [];
  const cities = cityRes.data ?? [];
  const kit = kitRes.data ?? [];
  const refine = refineRes.data ?? [];
  const recent = recentRes.data ?? [];
  const outcomes = outcomeRes.data ?? [];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Handover — Monsoon Weather Resilience</h1>
        <p className="text-sm text-gray-600">
          r2870 · engineer x handover x weather x delay x preparedness x outcome x refine. Tracks how monsoon weather hits
          handovers, where engineers slip, and what refinement actions land next.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total handovers</div>
          <div className="text-2xl font-bold">{overview.total_handovers}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Weather disrupted</div>
          <div className="text-2xl font-bold">{overview.weather_disrupted}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Avg delay (min)</div>
          <div className="text-2xl font-bold">{overview.avg_delay_min ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Avg CSAT</div>
          <div className="text-2xl font-bold">{overview.avg_csat ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Avg preparedness</div>
          <div className="text-2xl font-bold">{overview.avg_preparedness ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weather condition breakdown</h2>
        <DataTable
          rows={weather}
          columns={[
            { key: 'weather_condition', header: 'Condition', render: (r: any) => r.weather_condition },
            { key: 'handover_count', header: 'Handovers', render: (r: any) => r.handover_count },
            { key: 'avg_delay', header: 'Avg delay (min)', render: (r: any) => r.avg_delay },
            { key: 'aborted', header: 'Aborted', render: (r: any) => r.aborted },
            { key: 'avg_rainfall', header: 'Avg rain (mm)', render: (r: any) => r.avg_rainfall },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.weather_condition ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer leaderboard — preparedness x outcome</h2>
        <DataTable
          rows={leaderboard}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: any) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'handovers', header: 'Handovers', render: (r: any) => r.handovers },
            { key: 'avg_prep', header: 'Avg prep', render: (r: any) => r.avg_prep },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat },
            { key: 'on_time_pct', header: 'On-time %', render: (r: any) => r.on_time_pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">City impact — rainfall vs delay</h2>
          <DataTable
            rows={cities}
            columns={[
              { key: 'city', header: 'City', render: (r: any) => r.city },
              { key: 'handovers', header: 'Handovers', render: (r: any) => r.handovers },
              { key: 'avg_rainfall', header: 'Avg rain (mm)', render: (r: any) => r.avg_rainfall },
              { key: 'avg_delay', header: 'Avg delay', render: (r: any) => r.avg_delay },
              { key: 'aborted', header: 'Aborted', render: (r: any) => r.aborted },
            ]}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.city ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Kit correlation — with vs without raincoat kit</h2>
          <DataTable
            rows={kit}
            columns={[
              { key: 'kit_status', header: 'Kit status', render: (r: any) => r.kit_status },
              { key: 'handovers', header: 'Handovers', render: (r: any) => r.handovers },
              { key: 'avg_delay', header: 'Avg delay', render: (r: any) => r.avg_delay },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat },
              { key: 'on_time_pct', header: 'On-time %', render: (r: any) => r.on_time_pct },
            ]}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.kit_status ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome distribution</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
            { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
            { key: 'pct', header: '%', render: (r: any) => r.pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Refinement queue — grade x action x review</h2>
        <DataTable
          rows={refine}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: any) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
            { key: 'grade', header: 'Grade', render: (r: any) => r.grade },
            { key: 'action', header: 'Action', render: (r: any) => r.action },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
            { key: 'next_review', header: 'Next review', render: (r: any) => r.next_review },
            { key: 'note', header: 'Founder note', render: (r: any) => r.note },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent handovers</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'handover_date', header: 'Date', render: (r: any) => r.handover_date },
            { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer },
            { key: 'customer', header: 'Customer', render: (r: any) => r.customer },
            { key: 'city', header: 'City', render: (r: any) => r.city },
            { key: 'weather', header: 'Weather', render: (r: any) => r.weather },
            { key: 'delay_min', header: 'Delay (min)', render: (r: any) => r.delay_min },
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
            { key: 'csat', header: 'CSAT', render: (r: any) => r.csat ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
