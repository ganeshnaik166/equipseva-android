import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Forecast = {
  id: string;
  hospital_user_id: string;
  hospital_name: string | null;
  hospital_city: string | null;
  contract_id: string;
  amc_tier: string | null;
  expiry_date: string;
  days_to_expiry: number;
  monthly_fee_rupees: number;
  renewal_likelihood: 'low' | 'med' | 'high';
  risk_note: string | null;
  last_assessed_at: string | null;
};

type HighRisk = {
  id: string;
  hospital_name: string | null;
  hospital_city: string | null;
  amc_tier: string | null;
  expiry_date: string;
  days_to_expiry: number;
  monthly_fee_rupees: number;
  annual_revenue_at_risk: number;
  risk_note: string | null;
  last_assessed_at: string | null;
};

type Summary = {
  total_forecasts: number;
  total_revenue_at_risk_rupees: number;
  low_count: number;
  med_count: number;
  high_count: number;
  open_actions: number;
  done_actions: number;
};

function fmtINR(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function likelihoodBadge(l: string) {
  const color =
    l === 'low' ? '#b91c1c' : l === 'med' ? '#b45309' : '#047857';
  const bg =
    l === 'low' ? '#fee2e2' : l === 'med' ? '#fef3c7' : '#d1fae5';
  return (
    <span
      style={{
        background: bg,
        color,
        padding: '2px 8px',
        borderRadius: 6,
        fontSize: 12,
        fontWeight: 600,
        textTransform: 'uppercase',
      }}
    >
      {l}
    </span>
  );
}

export default async function FounderHospitalRenewalForecastPage() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, summaryRes, highRiskRes] = await Promise.all([
    sb.rpc('founder_list_renewal_forecasts'),
    sb.rpc('founder_renewal_summary'),
    sb.rpc('founder_high_risk_renewals'),
  ]);

  const forecasts: Forecast[] = (forecastsRes.data as Forecast[]) ?? [];
  const summary: Summary | null =
    (summaryRes.data as Summary[] | null)?.[0] ??
    (summaryRes.data as Summary | null) ??
    null;
  const highRisk: HighRisk[] = (highRiskRes.data as HighRisk[]) ?? [];

  const forecastCols: Column<Forecast>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'hospital_city', header: 'City', render: (r) => r.hospital_city ?? '—' },
    { key: 'amc_tier', header: 'Tier', render: (r) => r.amc_tier ?? '—' },
    { key: 'expiry_date', header: 'Expires', render: (r) => r.expiry_date },
    {
      key: 'days_to_expiry',
      header: 'Days',
      render: (r) => (
        <span style={{ color: r.days_to_expiry < 30 ? '#b91c1c' : '#374151' }}>
          {r.days_to_expiry}
        </span>
      ),
    },
    {
      key: 'monthly_fee_rupees',
      header: 'Monthly',
      render: (r) => fmtINR(r.monthly_fee_rupees),
    },
    {
      key: 'renewal_likelihood',
      header: 'Likelihood',
      render: (r) => likelihoodBadge(r.renewal_likelihood),
    },
    { key: 'risk_note', header: 'Risk note', render: (r) => r.risk_note ?? '—' },
    {
      key: 'last_assessed_at',
      header: 'Assessed',
      render: (r) =>
        r.last_assessed_at
          ? new Date(r.last_assessed_at).toLocaleDateString('en-IN')
          : '—',
    },
  ];

  const highRiskCols: Column<HighRisk>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'hospital_city', header: 'City', render: (r) => r.hospital_city ?? '—' },
    { key: 'amc_tier', header: 'Tier', render: (r) => r.amc_tier ?? '—' },
    { key: 'expiry_date', header: 'Expires', render: (r) => r.expiry_date },
    {
      key: 'days_to_expiry',
      header: 'Days',
      render: (r) => (
        <span style={{ color: '#b91c1c', fontWeight: 600 }}>
          {r.days_to_expiry}
        </span>
      ),
    },
    {
      key: 'annual_revenue_at_risk',
      header: 'Annual @ risk',
      render: (r) => (
        <span style={{ fontWeight: 600 }}>{fmtINR(r.annual_revenue_at_risk)}</span>
      ),
    },
    { key: 'risk_note', header: 'Risk note', render: (r) => r.risk_note ?? '—' },
  ];

  const kpi = (label: string, value: string, tone?: string) => (
    <div
      style={{
        background: '#fff',
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: '14px 18px',
        minWidth: 160,
        flex: '1 1 160px',
      }}
    >
      <div style={{ color: '#6b7280', fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>
        {label}
      </div>
      <div style={{ fontSize: 22, fontWeight: 700, color: tone ?? '#111827', marginTop: 4 }}>
        {value}
      </div>
    </div>
  );

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>
          Hospital Renewal Forecast
        </h1>
        <p style={{ color: '#6b7280', fontSize: 14 }}>
          AMC renewal pipeline · revenue at risk · per-hospital action queue (r1663)
        </p>
      </header>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#374151' }}>
          Summary
        </h2>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
          {kpi('Total forecasts', String(summary?.total_forecasts ?? 0))}
          {kpi(
            'Revenue at risk',
            fmtINR(summary?.total_revenue_at_risk_rupees ?? 0),
            '#b91c1c',
          )}
          {kpi('Low likelihood', String(summary?.low_count ?? 0), '#b91c1c')}
          {kpi('Med likelihood', String(summary?.med_count ?? 0), '#b45309')}
          {kpi('High likelihood', String(summary?.high_count ?? 0), '#047857')}
          {kpi('Open actions', String(summary?.open_actions ?? 0))}
          {kpi('Done actions', String(summary?.done_actions ?? 0))}
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#374151' }}>
          All renewal forecasts
        </h2>
        <DataTable
          rows={forecasts}
          columns={forecastCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#b91c1c' }}>
          High-risk action queue (likelihood = low)
        </h2>
        <DataTable
          rows={highRisk}
          columns={highRiskCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
