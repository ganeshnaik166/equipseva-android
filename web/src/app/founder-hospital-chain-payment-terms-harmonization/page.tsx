import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = {
  id: string;
  chain_name: string;
  current_terms: string;
  target_terms: string;
  monthly_billing_rupees: number;
  outstanding_rupees: number;
  contract_renewal_date: string | null;
  harmonization_status: string;
  days_to_renewal: number | null;
  gap_days: number | null;
};

type RiskRow = {
  id: string;
  chain_name: string;
  current_terms: string;
  outstanding_rupees: number;
  contract_renewal_date: string | null;
  days_to_renewal: number | null;
  harmonization_status: string;
  risk_reason: string;
};

type Concentration = {
  total_chains: number;
  chains_above_net30: number;
  total_outstanding_rupees: number;
  outstanding_above_net30_rupees: number;
  pct_outstanding_above_net30: number;
  largest_chain_name: string | null;
  largest_chain_outstanding: number | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹ ' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [chainsRes, riskRes, concRes] = await Promise.all([
    sb.rpc('list_chain_terms_r2311'),
    sb.rpc('chains_at_risk_r2311'),
    sb.rpc('chain_risk_concentration_r2311'),
  ]);

  const chains: ChainRow[] = (chainsRes.data as ChainRow[] | null) ?? [];
  const risks: RiskRow[] = (riskRes.data as RiskRow[] | null) ?? [];
  const concArr: Concentration[] = (concRes.data as Concentration[] | null) ?? [];
  const conc: Concentration | null = concArr.length > 0 ? concArr[0] : null;

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'current_terms', header: 'Current', render: (r: any) => r.current_terms },
    { key: 'target_terms', header: 'Target', render: (r: any) => r.target_terms },
    { key: 'gap_days', header: 'Gap (days)', render: (r: any) => (r.gap_days ?? 0) },
    { key: 'monthly_billing_rupees', header: 'Monthly billing', render: (r: any) => fmtRupees(r.monthly_billing_rupees) },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRupees(r.outstanding_rupees) },
    { key: 'contract_renewal_date', header: 'Renewal', render: (r: any) => r.contract_renewal_date ?? '—' },
    { key: 'days_to_renewal', header: 'Days to renewal', render: (r: any) => (r.days_to_renewal ?? '—') },
    { key: 'harmonization_status', header: 'Status', render: (r: any) => r.harmonization_status },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'current_terms', header: 'Current', render: (r: any) => r.current_terms },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRupees(r.outstanding_rupees) },
    { key: 'contract_renewal_date', header: 'Renewal', render: (r: any) => r.contract_renewal_date ?? '—' },
    { key: 'days_to_renewal', header: 'Days to renewal', render: (r: any) => (r.days_to_renewal ?? '—') },
    { key: 'harmonization_status', header: 'Status', render: (r: any) => r.harmonization_status },
    { key: 'risk_reason', header: 'Risk reason', render: (r: any) => r.risk_reason },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Payment-Terms Harmonization</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Hospital chains run on different payment terms (NET-30 / NET-60 / NET-90). Push every chain toward the NET-30 standard. Track current vs target terms, outstanding exposure, and risk concentration above NET-30.
      </p>

      {conc && (
        <section style={{ marginBottom: 32, padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Risk concentration</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Chains total</div>
              <div style={{ fontSize: 20, fontWeight: 600 }}>{conc.total_chains}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Above NET-30</div>
              <div style={{ fontSize: 20, fontWeight: 600 }}>{conc.chains_above_net30}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Pct outstanding above NET-30</div>
              <div style={{ fontSize: 20, fontWeight: 600 }}>{String(conc.pct_outstanding_above_net30 ?? 0)}%</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Total outstanding</div>
              <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(conc.total_outstanding_rupees)}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Outstanding above NET-30</div>
              <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(conc.outstanding_above_net30_rupees)}</div>
            </div>
            <div>
              <div style={{ fontSize: 12, color: '#666' }}>Largest chain exposure</div>
              <div style={{ fontSize: 16, fontWeight: 600 }}>{conc.largest_chain_name ?? '—'} ({fmtRupees(conc.largest_chain_outstanding)})</div>
            </div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All chains ({chains.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Gap = current terms days − target terms days. Positive gap means chain pays slower than target. Standard target is NET-30.
        </p>
        <DataTable
          rows={chains}
          columns={chainCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No chains tracked yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Chains at risk ({risks.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Chains flagged at risk OR rejected harmonization OR NET-90+ terms OR outstanding &gt; ₹10L above NET-30.
        </p>
        <DataTable
          rows={risks}
          columns={riskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No chains currently flagged as at risk."
        />
      </section>
    </div>
  );
}
