import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ComplianceRow = { compliance_flag: string; total: number; avg_match: number };
type BadgeRow = { badge_status: string; total: number; signed_off: number };
type RiskRow = { engineer_code: string; hospital_code: string; badge_status: string; photo_match_score: number; compliance_flag: string };
type CityRow = { hospital_city: string; total: number; critical: number; avg_match: number };
type SeverityRow = { severity: string; total: number; open_count: number };
type EscalationRow = { engineer_code: string; hospital_code: string; event_type: string; severity: string; detail: string; event_at: string };
type EventTypeRow = { event_type: string; total: number; avg_duration: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [c1, c2, c3, c4, c5, c6, c7] = await Promise.all([
    sb.rpc('founder_r2938_compliance_summary'),
    sb.rpc('founder_r2938_badge_status_breakdown'),
    sb.rpc('founder_r2938_top_risk_engineers'),
    sb.rpc('founder_r2938_city_rollup'),
    sb.rpc('founder_r2938_event_severity_mix'),
    sb.rpc('founder_r2938_open_escalations'),
    sb.rpc('founder_r2938_event_type_volume'),
  ]);

  const compliance = (c1.data ?? []) as ComplianceRow[];
  const badges = (c2.data ?? []) as BadgeRow[];
  const risk = (c3.data ?? []) as RiskRow[];
  const city = (c4.data ?? []) as CityRow[];
  const severity = (c5.data ?? []) as SeverityRow[];
  const escalations = (c6.data ?? []) as EscalationRow[];
  const events = (c7.data ?? []) as EventTypeRow[];

  const complianceCols: Column<ComplianceRow>[] = [
    { key: 'compliance_flag', header: 'Flag', render: (r) => r.compliance_flag },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'avg_match', header: 'Avg Match %', render: (r) => r.avg_match },
  ];

  const badgeCols: Column<BadgeRow>[] = [
    { key: 'badge_status', header: 'Status', render: (r) => r.badge_status },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'signed_off', header: 'Signed Off', render: (r) => r.signed_off },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'hospital_code', header: 'Hospital', render: (r) => r.hospital_code },
    { key: 'badge_status', header: 'Badge', render: (r) => r.badge_status },
    { key: 'photo_match_score', header: 'Match %', render: (r) => r.photo_match_score },
    { key: 'compliance_flag', header: 'Flag', render: (r) => r.compliance_flag },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'hospital_city', header: 'City', render: (r) => r.hospital_city },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'critical', header: 'Critical', render: (r) => r.critical },
    { key: 'avg_match', header: 'Avg Match %', render: (r) => r.avg_match },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
  ];

  const escCols: Column<EscalationRow>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'hospital_code', header: 'Hospital', render: (r) => r.hospital_code },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'detail', header: 'Detail', render: (r) => r.detail },
    { key: 'event_at', header: 'When', render: (r) => new Date(r.event_at).toLocaleString() },
  ];

  const evCols: Column<EventTypeRow>[] = [
    { key: 'event_type', header: 'Event Type', render: (r) => r.event_type },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'avg_duration', header: 'Avg Duration (min)', render: (r) => r.avg_duration },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Badge Re-Verification — r2938</h1>
        <p className="text-sm text-gray-600">Monthly hospital ID-badge compliance & field audit events.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compliance Summary</h2>
        <DataTable rows={compliance} columns={complianceCols} emptyMessage="No data" rowKey={(r, i) => String((r as ComplianceRow).compliance_flag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Badge Status Breakdown</h2>
        <DataTable rows={badges} columns={badgeCols} emptyMessage="No data" rowKey={(r, i) => String((r as BadgeRow).badge_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Risk Engineers</h2>
        <DataTable rows={risk} columns={riskCols} emptyMessage="No risk rows" rowKey={(r, i) => String((r as RiskRow).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
        <DataTable rows={city} columns={cityCols} emptyMessage="No data" rowKey={(r, i) => String((r as CityRow).hospital_city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Event Severity Mix</h2>
        <DataTable rows={severity} columns={sevCols} emptyMessage="No data" rowKey={(r, i) => String((r as SeverityRow).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Escalations</h2>
        <DataTable rows={escalations} columns={escCols} emptyMessage="No open escalations" rowKey={(r, i) => `${(r as EscalationRow).engineer_code}-${i}`} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Event Type Volume</h2>
        <DataTable rows={events} columns={evCols} emptyMessage="No data" rowKey={(r, i) => String((r as EventTypeRow).event_type ?? i)} />
      </section>
    </div>
  );
}
