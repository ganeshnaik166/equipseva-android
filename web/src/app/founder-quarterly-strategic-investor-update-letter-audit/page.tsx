import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Letter = {
  quarter_label: string;
  fiscal_year: string;
  sent_at: string;
  letter_title: string;
  arr_reported_rupees: number;
  burn_reported_rupees: number;
  runway_months_reported: number;
  net_new_logos: number;
  tone_score: number;
  hype_index: number;
  letter_status: string;
};

type Claim = {
  quarter_label: string;
  fiscal_year: string;
  claim_category: string;
  claim_text: string;
  claim_type: string;
  audit_status: string;
  variance_pct: number | null;
  severity: string;
  remediation_note: string | null;
};

type Promise = {
  quarter_label: string;
  fiscal_year: string;
  num_promises_made: number;
  num_promises_kept: number;
  keep_rate_pct: number;
};

type Flagged = {
  quarter_label: string;
  fiscal_year: string;
  claim_text: string;
  audit_status: string;
  variance_pct: number | null;
  severity: string;
  remediation_note: string | null;
};

type Hype = {
  quarter_label: string;
  fiscal_year: string;
  tone_score: number;
  hype_index: number;
  hype_minus_tone: number;
  total_word_count: number;
};

type Capital = {
  quarter_label: string;
  fiscal_year: string;
  cash_balance_rupees: number;
  burn_reported_rupees: number;
  runway_months_reported: number;
  arr_reported_rupees: number;
  burn_multiple: number | null;
};

type CategorySummary = {
  claim_category: string;
  total_claims: number;
  verified_count: number;
  flagged_count: number;
  pending_count: number;
  high_severity_count: number;
  avg_variance_pct: number;
};

type Kpis = {
  total_letters: number;
  total_claims: number;
  flagged_claims: number;
  high_severity_claims: number;
  total_promises_made: number;
  total_promises_kept: number;
  overall_keep_rate_pct: number;
  avg_hype_index: number;
  latest_arr_rupees: number;
  latest_cash_rupees: number;
};

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return n.toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    portfolioRes,
    claimsRes,
    promisesRes,
    flaggedRes,
    hypeRes,
    capitalRes,
    categoryRes,
    kpisRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2901_letter_portfolio'),
    supabase.rpc('founder_r2901_claim_audit_ledger'),
    supabase.rpc('founder_r2901_promise_keep_rate'),
    supabase.rpc('founder_r2901_flagged_claims'),
    supabase.rpc('founder_r2901_hype_drift'),
    supabase.rpc('founder_r2901_capital_trajectory'),
    supabase.rpc('founder_r2901_category_audit_summary'),
    supabase.rpc('founder_r2901_portfolio_kpis'),
  ]);

  const portfolio: Letter[] = (portfolioRes.data as Letter[]) ?? [];
  const claims: Claim[] = (claimsRes.data as Claim[]) ?? [];
  const promises: Promise[] = (promisesRes.data as Promise[]) ?? [];
  const flagged: Flagged[] = (flaggedRes.data as Flagged[]) ?? [];
  const hype: Hype[] = (hypeRes.data as Hype[]) ?? [];
  const capital: Capital[] = (capitalRes.data as Capital[]) ?? [];
  const categories: CategorySummary[] = (categoryRes.data as CategorySummary[]) ?? [];
  const kpis: Kpis | null = (kpisRes.data?.[0] as Kpis) ?? null;

  const portfolioCols: Column<Letter>[] = [
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter_label + ' ' + r.fiscal_year },
    { key: 'sent', header: 'Sent', render: (r) => new Date(r.sent_at).toLocaleDateString('en-IN') },
    { key: 'title', header: 'Letter Title', render: (r) => r.letter_title },
    { key: 'arr', header: 'ARR', render: (r) => rupees(r.arr_reported_rupees) },
    { key: 'burn', header: 'Burn/mo', render: (r) => rupees(r.burn_reported_rupees) },
    { key: 'runway', header: 'Runway (mo)', render: (r) => r.runway_months_reported.toFixed(1) },
    { key: 'logos', header: 'Net Logos', render: (r) => String(r.net_new_logos) },
    { key: 'tone', header: 'Tone', render: (r) => r.tone_score.toFixed(2) },
    { key: 'hype', header: 'Hype', render: (r) => r.hype_index.toFixed(2) },
    { key: 'status', header: 'Status', render: (r) => r.letter_status },
  ];

  const claimsCols: Column<Claim>[] = [
    { key: 'q', header: 'Quarter', render: (r) => r.quarter_label + ' ' + r.fiscal_year },
    { key: 'cat', header: 'Category', render: (r) => r.claim_category },
    { key: 'text', header: 'Claim', render: (r) => r.claim_text },
    { key: 'type', header: 'Type', render: (r) => r.claim_type },
    { key: 'status', header: 'Audit', render: (r) => r.audit_status },
    { key: 'var', header: 'Variance', render: (r) => r.variance_pct === null ? '—' : pct(r.variance_pct) },
    { key: 'sev', header: 'Severity', render: (r) => r.severity },
    { key: 'note', header: 'Note', render: (r) => r.remediation_note ?? '—' },
  ];

  const promiseCols: Column<Promise>[] = [
    { key: 'q', header: 'Quarter', render: (r) => r.quarter_label + ' ' + r.fiscal_year },
    { key: 'made', header: 'Promises Made', render: (r) => String(r.num_promises_made) },
    { key: 'kept', header: 'Promises Kept', render: (r) => String(r.num_promises_kept) },
    { key: 'rate', header: 'Keep Rate', render: (r) => pct(r.keep_rate_pct) },
  ];

  const flaggedCols: Column<Flagged>[] = [
    { key: 'q', header: 'Quarter', render: (r) => r.quarter_label + ' ' + r.fiscal_year },
    { key: 'text', header: 'Claim', render: (r) => r.claim_text },
    { key: 'status', header: 'Audit', render: (r) => r.audit_status },
    { key: 'var', header: 'Variance', render: (r) => r.variance_pct === null ? '—' : pct(r.variance_pct) },
    { key: 'sev', header: 'Severity', render: (r) => r.severity },
    { key: 'note', header: 'Remediation', render: (r) => r.remediation_note ?? '—' },
  ];

  const hypeCols: Column<Hype>[] = [
    { key: 'q', header: 'Quarter', render: (r) => r.quarter_label + ' ' + r.fiscal_year },
    { key: 'tone', header: 'Tone', render: (r) => r.tone_score.toFixed(2) },
    { key: 'hype', header: 'Hype', render: (r) => r.hype_index.toFixed(2) },
    { key: 'drift', header: 'Hype − Tone', render: (r) => r.hype_minus_tone.toFixed(2) },
    { key: 'words', header: 'Word Count', render: (r) => String(r.total_word_count) },
  ];

  const capitalCols: Column<Capital>[] = [
    { key: 'q', header: 'Quarter', render: (r) => r.quarter_label + ' ' + r.fiscal_year },
    { key: 'cash', header: 'Cash', render: (r) => rupees(r.cash_balance_rupees) },
    { key: 'burn', header: 'Burn/mo', render: (r) => rupees(r.burn_reported_rupees) },
    { key: 'runway', header: 'Runway', render: (r) => r.runway_months_reported.toFixed(1) + ' mo' },
    { key: 'arr', header: 'ARR', render: (r) => rupees(r.arr_reported_rupees) },
    { key: 'bm', header: 'Burn Multiple', render: (r) => r.burn_multiple === null ? '—' : r.burn_multiple.toFixed(2) },
  ];

  const categoryCols: Column<CategorySummary>[] = [
    { key: 'cat', header: 'Category', render: (r) => r.claim_category },
    { key: 'total', header: 'Total', render: (r) => String(r.total_claims) },
    { key: 'verified', header: 'Verified', render: (r) => String(r.verified_count) },
    { key: 'flagged', header: 'Flagged', render: (r) => String(r.flagged_count) },
    { key: 'pending', header: 'Pending', render: (r) => String(r.pending_count) },
    { key: 'high', header: 'High Sev', render: (r) => String(r.high_severity_count) },
    { key: 'avgvar', header: 'Avg |Variance|', render: (r) => pct(r.avg_variance_pct) },
  ];

  return (
    <main style={{ padding: '32px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
          Quarterly Strategic Founder-Investor Update Letter Audit
        </h1>
        <p style={{ color: '#666', fontSize: '15px' }}>
          CEO-grade truth-in-reporting audit. Every quarterly investor letter sent &gt;= FY24 is
          decomposed into atomic claims &amp; promises, then cross-checked against ground-truth
          ledgers. Hype-vs-tone drift, promise-keep rate, and variance-by-category give the board
          a credibility heatmap before the next raise.
        </p>
      </header>

      {kpis && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
          {[
            { label: 'Letters Sent', value: String(kpis.total_letters) },
            { label: 'Claims Audited', value: String(kpis.total_claims) },
            { label: 'Flagged Claims', value: String(kpis.flagged_claims) },
            { label: 'High-Severity', value: String(kpis.high_severity_claims) },
            { label: 'Promises Made', value: String(kpis.total_promises_made) },
            { label: 'Promises Kept', value: String(kpis.total_promises_kept) },
            { label: 'Keep Rate', value: pct(kpis.overall_keep_rate_pct) },
            { label: 'Avg Hype Index', value: kpis.avg_hype_index?.toFixed(2) ?? '—' },
            { label: 'Latest ARR', value: rupees(kpis.latest_arr_rupees) },
            { label: 'Latest Cash', value: rupees(kpis.latest_cash_rupees) },
          ].map((k) => (
            <div key={k.label} style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px', background: '#fff' }}>
              <div style={{ fontSize: '12px', color: '#888', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{k.label}</div>
              <div style={{ fontSize: '22px', fontWeight: 700, marginTop: '6px' }}>{k.value}</div>
            </div>
          ))}
        </section>
      )}

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Letter Portfolio</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Every investor letter sent, with headline ARR/burn/runway and tone vs hype.
        </p>
        <DataTable
          rows={portfolio}
          columns={portfolioCols}
          emptyMessage="No letters yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Claim-Level Audit Ledger</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Atomic claims extracted from each letter, cross-checked against source-of-truth ledgers.
        </p>
        <DataTable
          rows={claims}
          columns={claimsCols}
          emptyMessage="No claims audited yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Promise-Keep Rate by Quarter</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Forward-looking commitments per letter, scored at the next quarter's close.
        </p>
        <DataTable
          rows={promises}
          columns={promiseCols}
          emptyMessage="No promises tracked"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Flagged &amp; High-Severity Claims</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Claims where audited reality diverged &gt;= material threshold from the letter.
        </p>
        <DataTable
          rows={flagged}
          columns={flaggedCols}
          emptyMessage="Zero flagged claims — clean audit"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Hype vs Tone Drift</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Hype index &gt; tone score signals over-promising language relative to factual content.
        </p>
        <DataTable
          rows={hype}
          columns={hypeCols}
          emptyMessage="No tone analysis yet"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Capital & Runway Trajectory</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Quarter-over-quarter cash, burn, ARR and burn-multiple as reported in each letter.
        </p>
        <DataTable
          rows={capital}
          columns={capitalCols}
          emptyMessage="No capital history"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Category-Wise Audit Summary</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Which claim categories drift most? Revenue & metric categories vs roadmap promises.
        </p>
        <DataTable
          rows={categories}
          columns={categoryCols}
          emptyMessage="No category data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
