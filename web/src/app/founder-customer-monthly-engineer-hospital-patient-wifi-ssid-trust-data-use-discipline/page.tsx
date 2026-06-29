import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type TrustRow = {
  id: string;
  hospital_name: string;
  ssid: string;
  trust_tier: string;
  ssid_class: string;
  encryption_mode: string;
  discipline_score: number;
  monthly_engineer_visits: number;
  suspicious_event_count: number;
};

type TierRow = {
  trust_tier: string;
  ssid_count: number;
  avg_discipline: number;
  total_suspicious: number;
  total_engineer_visits: number;
};

type EncRow = {
  encryption_mode: string;
  ssid_count: number;
  verified_count: number;
  blocked_count: number;
  avg_discipline: number;
};

type EventRow = {
  id: string;
  hospital_name: string;
  ssid: string;
  engineer_name: string;
  event_kind: string;
  data_use_class: string;
  patient_pii_flag: boolean;
  bytes_transferred_mb: number;
  discipline_impact: number;
  resolution_status: string;
  occurred_at: string;
};

type MonthRow = {
  event_month: string;
  event_count: number;
  pii_event_count: number;
  total_bytes_mb: number;
  avg_discipline_impact: number;
  escalated_count: number;
};

type PiiRow = {
  data_use_class: string;
  event_count: number;
  pii_flagged: number;
  open_count: number;
  escalated_count: number;
  total_bytes_mb: number;
};

type EngRow = {
  engineer_name: string;
  total_events: number;
  clean_visits: number;
  pii_incidents: number;
  net_discipline: number;
  escalations: number;
};

type HospRow = {
  hospital_name: string;
  ssid_count: number;
  avg_discipline: number;
  blocked_or_suspicious: number;
  total_visits: number;
  total_devices: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [roster, tier, enc, recent, monthly, pii, eng, hosp] = await Promise.all([
    supabase.rpc('founder_r3008_trust_roster'),
    supabase.rpc('founder_r3008_tier_breakdown'),
    supabase.rpc('founder_r3008_encryption_discipline'),
    supabase.rpc('founder_r3008_recent_events'),
    supabase.rpc('founder_r3008_monthly_trend'),
    supabase.rpc('founder_r3008_pii_class_breakdown'),
    supabase.rpc('founder_r3008_engineer_leaderboard'),
    supabase.rpc('founder_r3008_hospital_trust_score'),
  ]);

  const rosterRows: TrustRow[] = (roster.data as TrustRow[]) ?? [];
  const tierRows: TierRow[] = (tier.data as TierRow[]) ?? [];
  const encRows: EncRow[] = (enc.data as EncRow[]) ?? [];
  const recentRows: EventRow[] = (recent.data as EventRow[]) ?? [];
  const monthRows: MonthRow[] = (monthly.data as MonthRow[]) ?? [];
  const piiRows: PiiRow[] = (pii.data as PiiRow[]) ?? [];
  const engRows: EngRow[] = (eng.data as EngRow[]) ?? [];
  const hospRows: HospRow[] = (hosp.data as HospRow[]) ?? [];

  const rosterCols: Column<TrustRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ssid', header: 'SSID' },
    { key: 'trust_tier', header: 'Tier' },
    { key: 'ssid_class', header: 'Class' },
    { key: 'encryption_mode', header: 'Encryption' },
    { key: 'discipline_score', header: 'Score' },
    { key: 'monthly_engineer_visits', header: 'Visits/mo' },
    { key: 'suspicious_event_count', header: 'Suspicious' },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'trust_tier', header: 'Tier' },
    { key: 'ssid_count', header: 'SSIDs' },
    { key: 'avg_discipline', header: 'Avg Discipline' },
    { key: 'total_suspicious', header: 'Suspicious' },
    { key: 'total_engineer_visits', header: 'Visits' },
  ];

  const encCols: Column<EncRow>[] = [
    { key: 'encryption_mode', header: 'Encryption' },
    { key: 'ssid_count', header: 'SSIDs' },
    { key: 'verified_count', header: 'Verified' },
    { key: 'blocked_count', header: 'Blocked' },
    { key: 'avg_discipline', header: 'Avg Discipline' },
  ];

  const recentCols: Column<EventRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ssid', header: 'SSID' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'event_kind', header: 'Event' },
    { key: 'data_use_class', header: 'Data Class' },
    {
      key: 'patient_pii_flag',
      header: 'PII?',
      render: (r) => (r.patient_pii_flag ? 'yes' : 'no'),
    },
    { key: 'bytes_transferred_mb', header: 'MB' },
    { key: 'discipline_impact', header: 'Impact' },
    { key: 'resolution_status', header: 'Status' },
  ];

  const monthCols: Column<MonthRow>[] = [
    { key: 'event_month', header: 'Month' },
    { key: 'event_count', header: 'Events' },
    { key: 'pii_event_count', header: 'PII Events' },
    { key: 'total_bytes_mb', header: 'Total MB' },
    { key: 'avg_discipline_impact', header: 'Avg Impact' },
    { key: 'escalated_count', header: 'Escalated' },
  ];

  const piiCols: Column<PiiRow>[] = [
    { key: 'data_use_class', header: 'Data Class' },
    { key: 'event_count', header: 'Events' },
    { key: 'pii_flagged', header: 'PII Flagged' },
    { key: 'open_count', header: 'Open' },
    { key: 'escalated_count', header: 'Escalated' },
    { key: 'total_bytes_mb', header: 'MB' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_events', header: 'Events' },
    { key: 'clean_visits', header: 'Clean' },
    { key: 'pii_incidents', header: 'PII' },
    { key: 'net_discipline', header: 'Net Discipline' },
    { key: 'escalations', header: 'Escalations' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ssid_count', header: 'SSIDs' },
    { key: 'avg_discipline', header: 'Avg Discipline' },
    { key: 'blocked_or_suspicious', header: 'Risk SSIDs' },
    { key: 'total_visits', header: 'Visits' },
    { key: 'total_devices', header: 'Devices' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">
          Patient WiFi SSID Trust &amp; Data-Use Discipline
        </h1>
        <p className="text-sm text-gray-600">
          Round r3008 — monthly engineer visits, hospital WiFi trust tiers, and patient PII data-use discipline (score &gt;= 80 = healthy).
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">SSID Trust Roster</h2>
        <DataTable
          rows={rosterRows}
          columns={rosterCols}
          emptyMessage="No SSIDs registered"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Trust Tier Breakdown</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data"
          rowKey={(r, i) => String(r.trust_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Encryption Discipline</h2>
        <DataTable
          rows={encRows}
          columns={encCols}
          emptyMessage="No encryption data"
          rowKey={(r, i) => String(r.encryption_mode ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Data-Use Events</h2>
        <DataTable
          rows={recentRows}
          columns={recentCols}
          emptyMessage="No events"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Trend</h2>
        <DataTable
          rows={monthRows}
          columns={monthCols}
          emptyMessage="No monthly data"
          rowKey={(r, i) => String(r.event_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">PII Data-Use Class</h2>
        <DataTable
          rows={piiRows}
          columns={piiCols}
          emptyMessage="No PII class data"
          rowKey={(r, i) => String(r.data_use_class ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineers"
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital Trust Score</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospitals"
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>
    </main>
  );
}
