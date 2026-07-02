import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_candidates: number;
  auto_eligible: number;
  on_hold: number;
  arr_at_risk_rupees: number;
  avg_score: number;
};

type Candidate = {
  candidate_id: string;
  contract_id: string;
  hospital_name: string;
  amc_tier: string;
  monthly_fee_rupees: number;
  ends_on: string;
  days_to_expiry: number;
  jobs_last_90d: number;
  avg_hospital_rating: number | null;
  outstanding_disputes: number;
  eligibility_score: number;
  auto_eligible: boolean;
};

type TierRow = {
  amc_tier: string;
  candidate_count: number;
  auto_eligible_count: number;
  arr_rupees: number;
  avg_score: number;
};

type DecisionRow = {
  decision_id: string;
  contract_id: string;
  hospital_name: string;
  decision: string;
  notes: string | null;
  decided_at: string;
};

type BucketRow = {
  bucket: string;
  candidate_count: number;
  arr_rupees: number;
};

function inr(n: number | null | undefined): string {
  const v = n ?? 0;
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
}

export default async function FounderHospitalAutoRenewPage() {
  const sb = await getSupabaseServerClient();

  const kpisRes = await sb.rpc('founder_hospital_auto_renew_kpis');
  const candidatesRes = await sb.rpc('founder_hospital_auto_renew_candidates');
  const tierRes = await sb.rpc('founder_hospital_auto_renew_by_tier');
  const decisionsRes = await sb.rpc('founder_hospital_auto_renew_recent_decisions');
  const bucketsRes = await sb.rpc('founder_hospital_auto_renew_expiry_buckets');

  const kpis = (kpisRes.data as Kpis | null) ?? {
    total_candidates: 0,
    auto_eligible: 0,
    on_hold: 0,
    arr_at_risk_rupees: 0,
    avg_score: 0,
  };
  const candidates = (candidatesRes.data as Candidate[] | null) ?? [];
  const tiers = (tierRes.data as TierRow[] | null) ?? [];
  const decisions = (decisionsRes.data as DecisionRow[] | null) ?? [];
  const buckets = (bucketsRes.data as BucketRow[] | null) ?? [];

  const candidateColumns: Column<Candidate>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'amc_tier', header: 'Tier', render: (r) => r.amc_tier ?? '—' },
    { key: 'monthly_fee_rupees', header: 'Monthly Fee', render: (r) => inr(r.monthly_fee_rupees) },
    { key: 'ends_on', header: 'Ends On', render: (r) => r.ends_on ?? '—' },
    { key: 'days_to_expiry', header: 'Days Left', render: (r) => String(r.days_to_expiry ?? 0) },
    { key: 'jobs_last_90d', header: 'Jobs 90d', render: (r) => String(r.jobs_last_90d ?? 0) },
    { key: 'avg_hospital_rating', header: 'Avg Rating', render: (r) => (r.avg_hospital_rating ?? 0).toFixed(2) },
    { key: 'outstanding_disputes', header: 'Disputes', render: (r) => String(r.outstanding_disputes ?? 0) },
    { key: 'eligibility_score', header: 'Score', render: (r) => String(r.eligibility_score ?? 0) },
    { key: 'auto_eligible', header: 'Auto OK', render: (r) => (r.auto_eligible ? 'Yes' : 'No') },
  ];

  const tierColumns: Column<TierRow>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r) => r.amc_tier ?? '—' },
    { key: 'candidate_count', header: 'Candidates', render: (r) => String(r.candidate_count ?? 0) },
    { key: 'auto_eligible_count', header: 'Auto-Eligible', render: (r) => String(r.auto_eligible_count ?? 0) },
    { key: 'arr_rupees', header: 'ARR if Renewed', render: (r) => inr(r.arr_rupees) },
    { key: 'avg_score', header: 'Avg Score', render: (r) => (r.avg_score ?? 0).toFixed(1) },
  ];

  const decisionColumns: Column<DecisionRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'decision', header: 'Decision', render: (r) => r.decision ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
    { key: 'decided_at', header: 'Decided At', render: (r) => new Date(r.decided_at).toLocaleString('en-IN') },
  ];

  const bucketColumns: Column<BucketRow>[] = [
    { key: 'bucket', header: 'Expiry Window', render: (r) => r.bucket ?? '—' },
    { key: 'candidate_count', header: 'Contracts', render: (r) => String(r.candidate_count ?? 0) },
    { key: 'arr_rupees', header: 'ARR at Stake', render: (r) => inr(r.arr_rupees) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Contract Auto-Renew</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        AMC contracts approaching renewal. Eligibility scored on jobs, ratings, disputes. Founder go/no-go before auto-renew triggers.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Candidates (7d)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.total_candidates ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Auto-Eligible</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.auto_eligible ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>On Hold (30d)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.on_hold ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>ARR if Renewed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{inr(kpis.arr_at_risk_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Score</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{(kpis.avg_score ?? 0).toFixed(1)}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Renewal Candidates</h2>
        <DataTable<Candidate>
          columns={candidateColumns}
          rows={candidates}
          rowKey={(r) => r.candidate_id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Expiry Buckets</h2>
        <DataTable<BucketRow>
          columns={bucketColumns}
          rows={buckets}
          rowKey={(r) => r.bucket}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Tier</h2>
        <DataTable<TierRow>
          columns={tierColumns}
          rows={tiers}
          rowKey={(r) => r.amc_tier}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Decisions</h2>
        <DataTable<DecisionRow>
          columns={decisionColumns}
          rows={decisions}
          rowKey={(r) => r.decision_id}
        />
      </section>
    </div>
  );
}
