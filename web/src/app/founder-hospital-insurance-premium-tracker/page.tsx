import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Premium = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  insurer_name: string;
  coverage_type: string;
  annual_premium_rupees: number;
  policy_start_date: string;
  policy_end_date: string;
  status: string;
  days_to_expiry: number | null;
  created_at: string;
};

type Claim = {
  id: string;
  premium_id: string;
  insurer_name: string;
  coverage_type: string;
  hospital_email: string | null;
  claim_date: string;
  claim_amount_rupees: number;
  claim_status: string;
  payout_rupees: number;
  payout_date: string | null;
  created_at: string;
};

type Summary = {
  total_premiums: number;
  active_premiums: number;
  expired_premiums: number;
  under_renewal: number;
  total_annual_premium_rupees: number;
  expiring_30d: number;
  expiring_60d: number;
};

type InsurerRatio = {
  insurer_name: string;
  total_premiums: number;
  total_premium_rupees: number;
  total_claims: number;
  total_claim_amount_rupees: number;
  total_payout_rupees: number;
  claims_ratio_pct: number;
  payout_ratio_pct: number;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toLocaleDateString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [premiumsRes, claimsRes, summaryRes, ratioRes] = await Promise.all([
    sb.rpc('list_insurance_premiums_r1719'),
    sb.rpc('list_insurance_claims_r1719'),
    sb.rpc('insurance_premium_summary_r1719'),
    sb.rpc('insurance_claims_ratio_per_insurer_r1719'),
  ]);

  const premiums: Premium[] = (premiumsRes.data as Premium[]) ?? [];
  const claims: Claim[] = (claimsRes.data as Claim[]) ?? [];
  const summaryRows = (summaryRes.data as Summary[]) ?? [];
  const summary: Summary = summaryRows[0] ?? {
    total_premiums: 0,
    active_premiums: 0,
    expired_premiums: 0,
    under_renewal: 0,
    total_annual_premium_rupees: 0,
    expiring_30d: 0,
    expiring_60d: 0,
  };
  const ratios: InsurerRatio[] = (ratioRes.data as InsurerRatio[]) ?? [];

  const errors = [premiumsRes.error, claimsRes.error, summaryRes.error, ratioRes.error]
    .filter(Boolean)
    .map((e) => e?.message ?? 'unknown');

  const premiumColumns: Column<Premium>[] = [
    { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name },
    { key: 'coverage_type', header: 'Coverage', render: (r: any) => r.coverage_type },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'annual_premium_rupees', header: 'Annual Premium', render: (r: any) => rupees(r.annual_premium_rupees) },
    { key: 'policy_start_date', header: 'Start', render: (r: any) => fmtDate(r.policy_start_date) },
    { key: 'policy_end_date', header: 'End', render: (r: any) => fmtDate(r.policy_end_date) },
    {
      key: 'days_to_expiry',
      header: 'Days Left',
      render: (r: any) => {
        const d = r.days_to_expiry;
        if (d == null) return '-';
        if (d < 0) return `expired ${Math.abs(d)}d ago`;
        if (d <= 30) return `${d}d (urgent)`;
        return `${d}d`;
      },
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const claimColumns: Column<Claim>[] = [
    { key: 'claim_date', header: 'Filed', render: (r: any) => fmtDate(r.claim_date) },
    { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name },
    { key: 'coverage_type', header: 'Coverage', render: (r: any) => r.coverage_type },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'claim_amount_rupees', header: 'Claim Amount', render: (r: any) => rupees(r.claim_amount_rupees) },
    { key: 'claim_status', header: 'Status', render: (r: any) => r.claim_status },
    { key: 'payout_rupees', header: 'Payout', render: (r: any) => rupees(r.payout_rupees) },
    { key: 'payout_date', header: 'Paid On', render: (r: any) => fmtDate(r.payout_date) },
  ];

  const ratioColumns: Column<InsurerRatio>[] = [
    { key: 'insurer_name', header: 'Insurer', render: (r: any) => r.insurer_name },
    { key: 'total_premiums', header: 'Policies', render: (r: any) => String(r.total_premiums) },
    { key: 'total_premium_rupees', header: 'Premium Pool', render: (r: any) => rupees(r.total_premium_rupees) },
    { key: 'total_claims', header: 'Claims', render: (r: any) => String(r.total_claims) },
    { key: 'total_claim_amount_rupees', header: 'Claims Total', render: (r: any) => rupees(r.total_claim_amount_rupees) },
    { key: 'total_payout_rupees', header: 'Payouts', render: (r: any) => rupees(r.total_payout_rupees) },
    {
      key: 'claims_ratio_pct',
      header: 'Claims Ratio %',
      render: (r: any) => {
        const v = Number(r.claims_ratio_pct ?? 0);
        const flag = v > 80 ? ' (high)' : v > 50 ? ' (watch)' : '';
        return `${v.toFixed(2)}%${flag}`;
      },
    },
    {
      key: 'payout_ratio_pct',
      header: 'Payout Ratio %',
      render: (r: any) => `${Number(r.payout_ratio_pct ?? 0).toFixed(2)}%`,
    },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital Insurance Premium Tracker</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Track hospital insurance premiums and claims for AMC bundling. Renewal alerts fire when
          policy end date is less than or equal to 30 days away.
        </p>
        <p style={{ color: '#777', fontSize: 12, marginTop: 4 }}>Round r1719 · founder-only</p>
      </header>

      {errors.length > 0 ? (
        <div style={{ background: '#fee', border: '1px solid #f99', padding: 12, marginBottom: 16, borderRadius: 6 }}>
          <strong>Errors:</strong>
          <ul style={{ margin: '6px 0 0 18px' }}>
            {errors.map((e, i) => (
              <li key={i}>{e}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Portfolio Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <Stat label="Total Policies" value={String(summary.total_premiums)} />
          <Stat label="Active" value={String(summary.active_premiums)} />
          <Stat label="Expired" value={String(summary.expired_premiums)} />
          <Stat label="Under Renewal" value={String(summary.under_renewal)} />
          <Stat label="Annual Premium Pool" value={rupees(summary.total_annual_premium_rupees)} />
          <Stat label="Expiring in 30 days" value={String(summary.expiring_30d)} highlight={summary.expiring_30d > 0} />
          <Stat label="Expiring in 60 days" value={String(summary.expiring_60d)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>Active Policies</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Sorted by policy end date ascending — soonest expiry on top. Days less than 30 flagged as urgent.
        </p>
        <DataTable<Premium>
          rows={premiums}
          columns={premiumColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>Recent Claims</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Latest claim activity. Status flow: filed → processing → approved or rejected → paid.
        </p>
        <DataTable<Claim>
          rows={claims}
          columns={claimColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>Insurer Performance & Claims Ratio</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Claims ratio greater than 80% flagged (high). Greater than 50% flagged (watch). Used for AMC bundling negotiations.
        </p>
        <DataTable<InsurerRatio>
          rows={ratios}
          columns={ratioColumns}
          rowKey={(r: any, i: number) => String(r.insurer_name ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, paddingTop: 16, borderTop: '1px solid #eee', fontSize: 12, color: '#888' }}>
        Data via SECURITY DEFINER RPCs gated by is_founder(). Writes log to founder_action_log.
      </footer>
    </div>
  );
}

function Stat({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div
      style={{
        background: highlight ? '#fff4e6' : '#f7f7f8',
        border: highlight ? '1px solid #f5a623' : '1px solid #e5e5e7',
        borderRadius: 8,
        padding: 14,
      }}
    >
      <div style={{ color: '#666', fontSize: 12, marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
