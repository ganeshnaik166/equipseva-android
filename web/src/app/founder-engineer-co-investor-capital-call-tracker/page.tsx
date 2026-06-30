import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_lps: number;
  total_commitment_rupees: number;
  total_called_rupees: number;
  total_uncalled_rupees: number;
  total_reserves_rupees: number;
  total_follow_on_rupees: number;
  red_count: number;
  amber_count: number;
  green_count: number;
  default_imminent_count: number;
};

type RiskRow = {
  lp_name: string;
  lp_type: string;
  vintage_quarter: string;
  funding_risk_band: string;
  total_commitment_rupees: number;
  uncalled_rupees: number;
  next_call_due_at: string | null;
  next_call_amount_rupees: number | null;
};

type UpcomingRow = {
  lp_name: string;
  call_sequence: number;
  call_purpose: string;
  requested_rupees: number;
  due_at: string;
  days_until_due: number;
  status: string;
  risk_flag: string;
};

type DelinquentRow = {
  lp_name: string;
  call_sequence: number;
  call_purpose: string;
  requested_rupees: number;
  received_rupees: number;
  delay_days: number;
  status: string;
  risk_flag: string;
  remediation_plan: string | null;
};

type ReservesRow = {
  lp_name: string;
  reserves_earmarked_rupees: number;
  reserves_released_pct: number;
  follow_on_commitment_rupees: number;
  uncalled_rupees: number;
};

type SecondaryRow = {
  secondary_appetite: string;
  lp_count: number;
  total_commitment_rupees: number;
  uncalled_rupees: number;
};

type SidecarRow = {
  lp_name: string;
  lp_type: string;
  sidecar_eligible: boolean;
  follow_on_commitment_rupees: number;
  uncalled_rupees: number;
  side_letter_terms: string | null;
};

type PurposeRow = {
  call_purpose: string;
  call_count: number;
  total_requested_rupees: number;
  total_received_rupees: number;
  avg_delay_days: number;
};

function inr(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Math.round(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  const d = new Date(s);
  return d.toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, riskRes, upcomingRes, delinquentRes, reservesRes, secondaryRes, sidecarRes, purposeRes] = await Promise.all([
    supabase.rpc('fn_r3119_commitments_summary'),
    supabase.rpc('fn_r3119_commitments_by_risk'),
    supabase.rpc('fn_r3119_upcoming_calls'),
    supabase.rpc('fn_r3119_delinquent_calls'),
    supabase.rpc('fn_r3119_reserves_utilization'),
    supabase.rpc('fn_r3119_secondary_appetite'),
    supabase.rpc('fn_r3119_sidecar_eligibility'),
    supabase.rpc('fn_r3119_calls_by_purpose'),
  ]);

  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[]) ?? [];
  const risk: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];
  const upcoming: UpcomingRow[] = (upcomingRes.data as UpcomingRow[]) ?? [];
  const delinquent: DelinquentRow[] = (delinquentRes.data as DelinquentRow[]) ?? [];
  const reserves: ReservesRow[] = (reservesRes.data as ReservesRow[]) ?? [];
  const secondary: SecondaryRow[] = (secondaryRes.data as SecondaryRow[]) ?? [];
  const sidecar: SidecarRow[] = (sidecarRes.data as SidecarRow[]) ?? [];
  const purpose: PurposeRow[] = (purposeRes.data as PurposeRow[]) ?? [];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'total_lps', header: 'LPs', render: (r) => String(r.total_lps) },
    { key: 'total_commitment_rupees', header: 'Committed', render: (r) => inr(r.total_commitment_rupees) },
    { key: 'total_called_rupees', header: 'Called', render: (r) => inr(r.total_called_rupees) },
    { key: 'total_uncalled_rupees', header: 'Uncalled', render: (r) => inr(r.total_uncalled_rupees) },
    { key: 'total_reserves_rupees', header: 'Reserves', render: (r) => inr(r.total_reserves_rupees) },
    { key: 'total_follow_on_rupees', header: 'Follow-on', render: (r) => inr(r.total_follow_on_rupees) },
    { key: 'red_count', header: 'Red', render: (r) => String(r.red_count) },
    { key: 'amber_count', header: 'Amber', render: (r) => String(r.amber_count) },
    { key: 'green_count', header: 'Green', render: (r) => String(r.green_count) },
    { key: 'default_imminent_count', header: 'Default Imm.', render: (r) => String(r.default_imminent_count) },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'lp_name', header: 'LP', render: (r) => r.lp_name },
    { key: 'lp_type', header: 'Type', render: (r) => r.lp_type },
    { key: 'vintage_quarter', header: 'Vintage', render: (r) => r.vintage_quarter },
    { key: 'funding_risk_band', header: 'Risk', render: (r) => r.funding_risk_band },
    { key: 'total_commitment_rupees', header: 'Committed', render: (r) => inr(r.total_commitment_rupees) },
    { key: 'uncalled_rupees', header: 'Uncalled', render: (r) => inr(r.uncalled_rupees) },
    { key: 'next_call_due_at', header: 'Next Due', render: (r) => fmtDate(r.next_call_due_at) },
    { key: 'next_call_amount_rupees', header: 'Next Amt', render: (r) => inr(r.next_call_amount_rupees) },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'lp_name', header: 'LP', render: (r) => r.lp_name },
    { key: 'call_sequence', header: 'Seq', render: (r) => String(r.call_sequence) },
    { key: 'call_purpose', header: 'Purpose', render: (r) => r.call_purpose },
    { key: 'requested_rupees', header: 'Requested', render: (r) => inr(r.requested_rupees) },
    { key: 'due_at', header: 'Due', render: (r) => fmtDate(r.due_at) },
    { key: 'days_until_due', header: 'Days', render: (r) => String(r.days_until_due) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'risk_flag', header: 'Flag', render: (r) => r.risk_flag },
  ];

  const delinquentCols: Column<DelinquentRow>[] = [
    { key: 'lp_name', header: 'LP', render: (r) => r.lp_name },
    { key: 'call_sequence', header: 'Seq', render: (r) => String(r.call_sequence) },
    { key: 'call_purpose', header: 'Purpose', render: (r) => r.call_purpose },
    { key: 'requested_rupees', header: 'Requested', render: (r) => inr(r.requested_rupees) },
    { key: 'received_rupees', header: 'Received', render: (r) => inr(r.received_rupees) },
    { key: 'delay_days', header: 'Delay (d)', render: (r) => String(r.delay_days) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'risk_flag', header: 'Flag', render: (r) => r.risk_flag },
    { key: 'remediation_plan', header: 'Remediation', render: (r) => r.remediation_plan ?? '-' },
  ];

  const reservesCols: Column<ReservesRow>[] = [
    { key: 'lp_name', header: 'LP', render: (r) => r.lp_name },
    { key: 'reserves_earmarked_rupees', header: 'Reserves Earmarked', render: (r) => inr(r.reserves_earmarked_rupees) },
    { key: 'reserves_released_pct', header: 'Released %', render: (r) => `${Number(r.reserves_released_pct ?? 0).toFixed(1)}%` },
    { key: 'follow_on_commitment_rupees', header: 'Follow-on', render: (r) => inr(r.follow_on_commitment_rupees) },
    { key: 'uncalled_rupees', header: 'Uncalled', render: (r) => inr(r.uncalled_rupees) },
  ];

  const secondaryCols: Column<SecondaryRow>[] = [
    { key: 'secondary_appetite', header: 'Appetite', render: (r) => r.secondary_appetite },
    { key: 'lp_count', header: 'LPs', render: (r) => String(r.lp_count) },
    { key: 'total_commitment_rupees', header: 'Committed', render: (r) => inr(r.total_commitment_rupees) },
    { key: 'uncalled_rupees', header: 'Uncalled', render: (r) => inr(r.uncalled_rupees) },
  ];

  const sidecarCols: Column<SidecarRow>[] = [
    { key: 'lp_name', header: 'LP', render: (r) => r.lp_name },
    { key: 'lp_type', header: 'Type', render: (r) => r.lp_type },
    { key: 'sidecar_eligible', header: 'Eligible', render: (r) => (r.sidecar_eligible ? 'Yes' : 'No') },
    { key: 'follow_on_commitment_rupees', header: 'Follow-on', render: (r) => inr(r.follow_on_commitment_rupees) },
    { key: 'uncalled_rupees', header: 'Uncalled', render: (r) => inr(r.uncalled_rupees) },
    { key: 'side_letter_terms', header: 'Side Letter', render: (r) => r.side_letter_terms ?? '-' },
  ];

  const purposeCols: Column<PurposeRow>[] = [
    { key: 'call_purpose', header: 'Purpose', render: (r) => r.call_purpose },
    { key: 'call_count', header: 'Calls', render: (r) => String(r.call_count) },
    { key: 'total_requested_rupees', header: 'Requested', render: (r) => inr(r.total_requested_rupees) },
    { key: 'total_received_rupees', header: 'Received', render: (r) => inr(r.total_received_rupees) },
    { key: 'avg_delay_days', header: 'Avg Delay (d)', render: (r) => Number(r.avg_delay_days ?? 0).toFixed(1) },
  ];

  return (
    <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '32px' }}>
      <header>
        <h1 style={{ fontSize: '22px', fontWeight: 700 }}>
          Engineer-Founder Co-Investor Capital-Call Risk & Reserve Tracker
        </h1>
        <p style={{ color: '#555', marginTop: '6px' }}>
          Quarterly view: LP capital-call timing, reserves earmarked, follow-on commitments, delayed-funding risk,
          secondary appetite, sidecar opportunities.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>1. Portfolio Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No commitments"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>2. Commitments by Risk Band</h2>
        <DataTable
          rows={risk}
          columns={riskCols}
          emptyMessage="No LPs"
          rowKey={(r, i) => String(r.lp_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>3. Upcoming Capital Calls (next 60d)</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming calls"
          rowKey={(r, i) => String(`${r.lp_name}-${r.call_sequence}-${i}`)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>4. Delinquent & Breached Calls</h2>
        <DataTable
          rows={delinquent}
          columns={delinquentCols}
          emptyMessage="No delinquencies"
          rowKey={(r, i) => String(`${r.lp_name}-${r.call_sequence}-${i}`)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>5. Reserves Utilization</h2>
        <DataTable
          rows={reserves}
          columns={reservesCols}
          emptyMessage="No reserves"
          rowKey={(r, i) => String(r.lp_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>6. Secondary Appetite</h2>
        <DataTable
          rows={secondary}
          columns={secondaryCols}
          emptyMessage="No appetite data"
          rowKey={(r, i) => String(r.secondary_appetite ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>7. Sidecar Eligibility</h2>
        <DataTable
          rows={sidecar}
          columns={sidecarCols}
          emptyMessage="No sidecar-eligible LPs"
          rowKey={(r, i) => String(r.lp_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>8. Calls by Purpose</h2>
        <DataTable
          rows={purpose}
          columns={purposeCols}
          emptyMessage="No call data"
          rowKey={(r, i) => String(r.call_purpose ?? i)}
        />
      </section>
    </div>
  );
}
