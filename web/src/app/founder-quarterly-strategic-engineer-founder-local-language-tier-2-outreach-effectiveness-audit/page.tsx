import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type SessionOverview = { session_date: string; tier2_city: string; state_code: string; local_language: string; attendance_count: number; nps_score: number; conversion_pct: number; effectiveness_band: string };
type BandRow = { effectiveness_band: string; session_count: number; avg_nps: number; avg_conversion: number };
type LangRow = { local_language: string; sessions: number; avg_attendance: number; avg_nps: number; exceptional_count: number };
type QuarterRow = { quarter: string; fiscal_year: number; sessions: number; total_attendance: number; avg_conversion: number };
type RoiRow = { followup_kind: string; total_outreach: number; total_conversions: number; total_revenue: number; total_cost: number; roi_x: number };
type BlockedRow = { followup_date: string; followup_kind: string; language_used: string; outreach_count: number; status: string };
type PresenceRow = { founder_present: boolean; sessions: number; avg_nps: number; avg_conversion: number; avg_attendance: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, bands, langs, quarters, roi, blocked, presence] = await Promise.all([
    supabase.rpc('rpc_r3045_session_overview'),
    supabase.rpc('rpc_r3045_band_distribution'),
    supabase.rpc('rpc_r3045_language_effectiveness'),
    supabase.rpc('rpc_r3045_quarterly_trend'),
    supabase.rpc('rpc_r3045_followup_roi'),
    supabase.rpc('rpc_r3045_blocked_followups'),
    supabase.rpc('rpc_r3045_founder_presence_impact'),
  ]);

  const overviewCols: Column<SessionOverview>[] = [
    { header: 'Date', accessor: (r) => r.session_date },
    { header: 'City', accessor: (r) => r.tier2_city },
    { header: 'State', accessor: (r) => r.state_code },
    { header: 'Language', accessor: (r) => r.local_language },
    { header: 'Attendance', accessor: (r) => r.attendance_count },
    { header: 'NPS', accessor: (r) => r.nps_score },
    { header: 'Conv %', accessor: (r) => r.conversion_pct },
    { header: 'Band', accessor: (r) => r.effectiveness_band },
  ];

  const bandCols: Column<BandRow>[] = [
    { header: 'Band', accessor: (r) => r.effectiveness_band },
    { header: 'Sessions', accessor: (r) => r.session_count },
    { header: 'Avg NPS', accessor: (r) => r.avg_nps },
    { header: 'Avg Conv', accessor: (r) => r.avg_conversion },
  ];

  const langCols: Column<LangRow>[] = [
    { header: 'Language', accessor: (r) => r.local_language },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Avg Attendance', accessor: (r) => r.avg_attendance },
    { header: 'Avg NPS', accessor: (r) => r.avg_nps },
    { header: 'Exceptional', accessor: (r) => r.exceptional_count },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'FY', accessor: (r) => r.fiscal_year },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Attendance', accessor: (r) => r.total_attendance },
    { header: 'Avg Conv', accessor: (r) => r.avg_conversion },
  ];

  const roiCols: Column<RoiRow>[] = [
    { header: 'Follow-up Kind', accessor: (r) => r.followup_kind },
    { header: 'Outreach', accessor: (r) => r.total_outreach },
    { header: 'Conversions', accessor: (r) => r.total_conversions },
    { header: 'Revenue (Rs)', accessor: (r) => r.total_revenue },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost },
    { header: 'ROI x', accessor: (r) => r.roi_x },
  ];

  const blockedCols: Column<BlockedRow>[] = [
    { header: 'Date', accessor: (r) => r.followup_date },
    { header: 'Kind', accessor: (r) => r.followup_kind },
    { header: 'Language', accessor: (r) => r.language_used },
    { header: 'Outreach', accessor: (r) => r.outreach_count },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const presenceCols: Column<PresenceRow>[] = [
    { header: 'Founder Present', accessor: (r) => String(r.founder_present) },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Avg NPS', accessor: (r) => r.avg_nps },
    { header: 'Avg Conv', accessor: (r) => r.avg_conversion },
    { header: 'Avg Attendance', accessor: (r) => r.avg_attendance },
  ];

  return (
    <div className="space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Tier-2 Outreach Audit</h1>
        <p className="text-sm text-gray-600">Engineer-founder local-language outreach effectiveness & ROI across Tier-2 cities.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Session Overview</h2>
        <DataTable<SessionOverview>
          rows={(overview.data ?? []) as SessionOverview[]}
          columns={overviewCols}
          emptyMessage="No sessions logged"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Effectiveness Band Distribution</h2>
        <DataTable<BandRow>
          rows={(bands.data ?? []) as BandRow[]}
          columns={bandCols}
          emptyMessage="No band data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Local-Language Effectiveness</h2>
        <DataTable<LangRow>
          rows={(langs.data ?? []) as LangRow[]}
          columns={langCols}
          emptyMessage="No language data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable<QuarterRow>
          rows={(quarters.data ?? []) as QuarterRow[]}
          columns={quarterCols}
          emptyMessage="No quarterly data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up ROI</h2>
        <DataTable<RoiRow>
          rows={(roi.data ?? []) as RoiRow[]}
          columns={roiCols}
          emptyMessage="No ROI data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocked / Pending Follow-ups</h2>
        <DataTable<BlockedRow>
          rows={(blocked.data ?? []) as BlockedRow[]}
          columns={blockedCols}
          emptyMessage="No blocked follow-ups"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder Presence Impact</h2>
        <DataTable<PresenceRow>
          rows={(presence.data ?? []) as PresenceRow[]}
          columns={presenceCols}
          emptyMessage="No presence data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
