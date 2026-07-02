import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = {
  pursuit_month: string;
  pursuits_count: number;
  total_tcv_lakh: number;
  won_count: number;
  won_tcv_lakh: number;
  win_rate_pct: number | null;
  avg_competitor_count: number;
};

type CategoryRow = {
  category: string;
  pursuits: number;
  wins: number;
  losses: number;
  win_rate_pct: number | null;
  avg_margin_lakh: number | null;
};

type StateRow = {
  state_code: string;
  pursuits: number;
  wins: number;
  total_tcv_lakh: number;
  won_tcv_lakh: number;
  win_rate_pct: number | null;
};

type EmdRow = {
  tender_ref: string;
  emd_lakh: number;
  bank_name: string;
  release_status: string;
  days_blocked: number;
  carry_cost_rupees: number;
};

type WinRow = {
  tender_ref: string;
  authority: string;
  category: string;
  our_price_lakh: number;
  l1_price_lakh: number;
  margin_lakh: number;
  pursuit_month: string;
};

type LossRow = {
  tender_ref: string;
  authority: string;
  category: string;
  our_price_lakh: number;
  l1_price_lakh: number;
  price_gap_pct: number;
  competitor_count: number;
  notes: string | null;
};

type PipelineRow = {
  tender_ref: string;
  authority: string;
  our_price_lakh: number;
  win_probability_pct: number;
  expected_value_lakh: number;
  bid_due_at: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, byCategory, byState, openEmd, topWins, losses, pipeline] = await Promise.all([
    supabase.rpc('r2893_monthly_pursuit_summary'),
    supabase.rpc('r2893_winrate_by_category'),
    supabase.rpc('r2893_state_exposure'),
    supabase.rpc('r2893_open_emd_exposure'),
    supabase.rpc('r2893_top_wins'),
    supabase.rpc('r2893_loss_diagnostics'),
    supabase.rpc('r2893_pipeline_forecast'),
  ]);

  const monthlyRows = (monthly.data ?? []) as MonthlySummary[];
  const categoryRows = (byCategory.data ?? []) as CategoryRow[];
  const stateRows = (byState.data ?? []) as StateRow[];
  const emdRows = (openEmd.data ?? []) as EmdRow[];
  const winRows = (topWins.data ?? []) as WinRow[];
  const lossRows = (losses.data ?? []) as LossRow[];
  const pipelineRows = (pipeline.data ?? []) as PipelineRow[];

  const thisMonth = monthlyRows[0];
  const totalOpenEmd = emdRows.reduce((s, r) => s + Number(r.emd_lakh ?? 0), 0);
  const totalCarryCost = emdRows.reduce((s, r) => s + Number(r.carry_cost_rupees ?? 0), 0);
  const pipelineExpected = pipelineRows.reduce((s, r) => s + Number(r.expected_value_lakh ?? 0), 0);

  const monthlyCols: Column<MonthlySummary>[] = [
    { key: 'pursuit_month', header: 'Month', render: (r) => String(r.pursuit_month).slice(0, 7) },
    { key: 'pursuits_count', header: 'Pursuits', render: (r) => r.pursuits_count },
    { key: 'total_tcv_lakh', header: 'TCV (lakh)', render: (r) => `Rs ${Number(r.total_tcv_lakh).toFixed(2)}L` },
    { key: 'won_count', header: 'Wins', render: (r) => r.won_count },
    { key: 'won_tcv_lakh', header: 'Won TCV', render: (r) => `Rs ${Number(r.won_tcv_lakh).toFixed(2)}L` },
    { key: 'win_rate_pct', header: 'Win rate', render: (r) => (r.win_rate_pct == null ? '—' : `${r.win_rate_pct}%`) },
    { key: 'avg_competitor_count', header: 'Avg competitors', render: (r) => r.avg_competitor_count },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'pursuits', header: 'Pursuits', render: (r) => r.pursuits },
    { key: 'wins', header: 'Wins', render: (r) => r.wins },
    { key: 'losses', header: 'Losses', render: (r) => r.losses },
    { key: 'win_rate_pct', header: 'Win rate', render: (r) => (r.win_rate_pct == null ? '—' : `${r.win_rate_pct}%`) },
    { key: 'avg_margin_lakh', header: 'Avg gap vs L1', render: (r) => (r.avg_margin_lakh == null ? '—' : `Rs ${Number(r.avg_margin_lakh).toFixed(2)}L`) },
  ];

  const stateCols: Column<StateRow>[] = [
    { key: 'state_code', header: 'State', render: (r) => r.state_code },
    { key: 'pursuits', header: 'Pursuits', render: (r) => r.pursuits },
    { key: 'wins', header: 'Wins', render: (r) => r.wins },
    { key: 'total_tcv_lakh', header: 'Total TCV', render: (r) => `Rs ${Number(r.total_tcv_lakh).toFixed(2)}L` },
    { key: 'won_tcv_lakh', header: 'Won TCV', render: (r) => `Rs ${Number(r.won_tcv_lakh).toFixed(2)}L` },
    { key: 'win_rate_pct', header: 'Win rate', render: (r) => (r.win_rate_pct == null ? '—' : `${r.win_rate_pct}%`) },
  ];

  const emdCols: Column<EmdRow>[] = [
    { key: 'tender_ref', header: 'Tender', render: (r) => r.tender_ref },
    { key: 'emd_lakh', header: 'EMD', render: (r) => `Rs ${Number(r.emd_lakh).toFixed(2)}L` },
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'release_status', header: 'Status', render: (r) => r.release_status },
    { key: 'days_blocked', header: 'Days blocked', render: (r) => r.days_blocked },
    { key: 'carry_cost_rupees', header: 'Carry cost', render: (r) => `Rs ${Number(r.carry_cost_rupees).toFixed(0)}` },
  ];

  const winCols: Column<WinRow>[] = [
    { key: 'tender_ref', header: 'Tender', render: (r) => r.tender_ref },
    { key: 'authority', header: 'Authority', render: (r) => r.authority },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'our_price_lakh', header: 'Our price', render: (r) => `Rs ${Number(r.our_price_lakh).toFixed(2)}L` },
    { key: 'l1_price_lakh', header: 'L1 price', render: (r) => `Rs ${Number(r.l1_price_lakh).toFixed(2)}L` },
    { key: 'margin_lakh', header: 'Gap', render: (r) => `Rs ${Number(r.margin_lakh).toFixed(2)}L` },
  ];

  const lossCols: Column<LossRow>[] = [
    { key: 'tender_ref', header: 'Tender', render: (r) => r.tender_ref },
    { key: 'authority', header: 'Authority', render: (r) => r.authority },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'our_price_lakh', header: 'Our price', render: (r) => `Rs ${Number(r.our_price_lakh).toFixed(2)}L` },
    { key: 'l1_price_lakh', header: 'L1 price', render: (r) => `Rs ${Number(r.l1_price_lakh).toFixed(2)}L` },
    { key: 'price_gap_pct', header: 'Gap %', render: (r) => `${r.price_gap_pct}%` },
    { key: 'competitor_count', header: 'Competitors', render: (r) => r.competitor_count },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const pipelineCols: Column<PipelineRow>[] = [
    { key: 'tender_ref', header: 'Tender', render: (r) => r.tender_ref },
    { key: 'authority', header: 'Authority', render: (r) => r.authority },
    { key: 'our_price_lakh', header: 'Our price', render: (r) => `Rs ${Number(r.our_price_lakh).toFixed(2)}L` },
    { key: 'win_probability_pct', header: 'Win prob', render: (r) => `${r.win_probability_pct}%` },
    { key: 'expected_value_lakh', header: 'Expected (lakh)', render: (r) => `Rs ${Number(r.expected_value_lakh).toFixed(2)}L` },
    { key: 'bid_due_at', header: 'Due', render: (r) => new Date(r.bid_due_at).toLocaleDateString() },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: '1.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, margin: 0 }}>
          Monthly Government Tender Pursuit &amp; Win-Rate Drilldown
        </h1>
        <p style={{ color: '#555', marginTop: '0.5rem' }}>
          CEO readout of GeM tender pipeline — TCV pursued, win-rate by category &amp; state, open EMD exposure, and L1 vs L2 price-gap diagnostics. Govt is the highest-leverage channel: every L1 win locks 3-5 yr AMCs across &gt;= 1 hospital cluster, but EMD carry-cost &amp; capacity discipline gate scale.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <KpiCard label="This month pursuits" value={thisMonth ? String(thisMonth.pursuits_count) : '—'} />
        <KpiCard label="This month TCV" value={thisMonth ? `Rs ${Number(thisMonth.total_tcv_lakh).toFixed(1)}L` : '—'} />
        <KpiCard label="Win rate" value={thisMonth?.win_rate_pct != null ? `${thisMonth.win_rate_pct}%` : '—'} />
        <KpiCard label="Open EMD blocked" value={`Rs ${totalOpenEmd.toFixed(2)}L`} />
        <KpiCard label="EMD carry cost" value={`Rs ${totalCarryCost.toFixed(0)}`} />
        <KpiCard label="Pipeline expected" value={`Rs ${pipelineExpected.toFixed(1)}L`} />
      </section>

      <Section title="Monthly pursuit summary" subtitle="TCV pursued vs won by month — track velocity & conversion">
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No pursuit data"
          rowKey={(r, i) => String(r.pursuit_month ?? i)}
        />
      </Section>

      <Section title="Win-rate by category" subtitle="Where we win >= 60% vs where we are price-uncompetitive">
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category data"
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </Section>

      <Section title="State exposure heatmap" subtitle="Geographic concentration of pipeline & wins">
        <DataTable
          rows={stateRows}
          columns={stateCols}
          emptyMessage="No state data"
          rowKey={(r, i) => String(r.state_code ?? i)}
        />
      </Section>

      <Section title="Open EMD exposure" subtitle="Working capital blocked in bank guarantees & FDRs — release SLA <= 14d post-result">
        <DataTable
          rows={emdRows}
          columns={emdCols}
          emptyMessage="No open EMDs — clean"
          rowKey={(r, i) => String(r.tender_ref ?? i)}
        />
      </Section>

      <Section title="Top wins (by ticket size)" subtitle="L1 awards anchoring multi-year AMC revenue">
        <DataTable
          rows={winRows}
          columns={winCols}
          emptyMessage="No wins yet"
          rowKey={(r, i) => String(r.tender_ref ?? i)}
        />
      </Section>

      <Section title="Loss diagnostics" subtitle="Where we got beaten on price — gap % tells if it was beatable or sub-cost incumbent">
        <DataTable
          rows={lossRows}
          columns={lossCols}
          emptyMessage="No losses — flawless quarter"
          rowKey={(r, i) => String(r.tender_ref ?? i)}
        />
      </Section>

      <Section title="Pipeline forecast (submitted, awaiting open)" subtitle="Probability-weighted expected value of in-flight bids">
        <DataTable
          rows={pipelineRows}
          columns={pipelineCols}
          emptyMessage="No bids in flight"
          rowKey={(r, i) => String(r.tender_ref ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '1rem', background: '#fafafa' }}>
      <div style={{ fontSize: '0.75rem', color: '#666', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ fontSize: '1.5rem', fontWeight: 700, marginTop: '0.25rem' }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '2rem' }}>
      <h2 style={{ fontSize: '1.15rem', fontWeight: 600, margin: 0 }}>{title}</h2>
      <p style={{ color: '#666', fontSize: '0.9rem', margin: '0.25rem 0 0.75rem' }}>{subtitle}</p>
      {children}
    </section>
  );
}
