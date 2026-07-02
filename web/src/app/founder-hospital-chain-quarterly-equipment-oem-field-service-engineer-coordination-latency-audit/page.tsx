import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; quarters_audited: number; hospitals: number; units: number; avg_score: number; total_breaches: number };
type OemRow = { oem_partner: string; audits: number; avg_dispatch: number; avg_onsite: number; avg_resolution: number; breaches: number };
type QuarterRow = { quarter_label: string; audits: number; avg_score: number; avg_breaches: number; escalated: number };
type CityRow = { city: string; visits: number; breached: number; breach_pct: number; avg_resolution: number };
type CatRow = { equipment_category: string; visits: number; avg_dispatch: number; avg_onsite: number; avg_resolution: number; fails: number };
type EngRow = { engineer_assigned: string; visits: number; passes: number; fails: number; avg_resolution: number };
type EscRow = { chain_name: string; quarter_label: string; oem_partner: string; audit_score: number; breaches: number; status: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [chain, oem, quarter, city, cat, eng, esc] = await Promise.all([
    sb.rpc('founder_r3011_chain_summary'),
    sb.rpc('founder_r3011_oem_latency'),
    sb.rpc('founder_r3011_quarter_trend'),
    sb.rpc('founder_r3011_city_breaches'),
    sb.rpc('founder_r3011_category_latency'),
    sb.rpc('founder_r3011_engineer_scorecard'),
    sb.rpc('founder_r3011_escalations'),
  ]);

  const chainRows = (chain.data ?? []) as ChainRow[];
  const oemRows = (oem.data ?? []) as OemRow[];
  const qRows = (quarter.data ?? []) as QuarterRow[];
  const cityRows = (city.data ?? []) as CityRow[];
  const catRows = (cat.data ?? []) as CatRow[];
  const engRows = (eng.data ?? []) as EngRow[];
  const escRows = (esc.data ?? []) as EscRow[];

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Quarters', accessor: (r) => r.quarters_audited },
    { header: 'Hospitals', accessor: (r) => r.hospitals },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Breaches', accessor: (r) => r.total_breaches },
  ];
  const oemCols: Column<OemRow>[] = [
    { header: 'OEM', accessor: (r) => r.oem_partner },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Dispatch (min)', accessor: (r) => r.avg_dispatch },
    { header: 'On-site (min)', accessor: (r) => r.avg_onsite },
    { header: 'Resolution (min)', accessor: (r) => r.avg_resolution },
    { header: 'Breaches', accessor: (r) => r.breaches },
  ];
  const qCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Avg Breaches', accessor: (r) => r.avg_breaches },
    { header: 'Escalated', accessor: (r) => r.escalated },
  ];
  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Breached', accessor: (r) => r.breached },
    { header: 'Breach %', accessor: (r) => r.breach_pct },
    { header: 'Avg Resolution', accessor: (r) => r.avg_resolution },
  ];
  const catCols: Column<CatRow>[] = [
    { header: 'Category', accessor: (r) => r.equipment_category },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Dispatch', accessor: (r) => r.avg_dispatch },
    { header: 'On-site', accessor: (r) => r.avg_onsite },
    { header: 'Resolution', accessor: (r) => r.avg_resolution },
    { header: 'Fails', accessor: (r) => r.fails },
  ];
  const engCols: Column<EngRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_assigned },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Fail', accessor: (r) => r.fails },
    { header: 'Avg Resolution', accessor: (r) => r.avg_resolution },
  ];
  const escCols: Column<EscRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'OEM', accessor: (r) => r.oem_partner },
    { header: 'Score', accessor: (r) => r.audit_score },
    { header: 'Breaches', accessor: (r) => r.breaches },
    { header: 'Status', accessor: (r) => r.status },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital Chain Quarterly OEM Engineer Coordination Latency Audit</h1>
        <p style={{ color: '#666', fontSize: 13 }}>Round r3011 · dispatch &gt;= on-site &gt;= resolution latency rollups across chains &amp; OEMs</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Chain summary</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String((r as ChainRow).chain_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>OEM latency</h2>
        <DataTable rows={oemRows} columns={oemCols} emptyMessage="No OEM data" rowKey={(r, i) => String((r as OemRow).oem_partner ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Quarter trend</h2>
        <DataTable rows={qRows} columns={qCols} emptyMessage="No quarters" rowKey={(r, i) => String((r as QuarterRow).quarter_label ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>City breaches</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String((r as CityRow).city ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Category latency</h2>
        <DataTable rows={catRows} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String((r as CatRow).equipment_category ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as EngRow).engineer_assigned ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Escalations</h2>
        <DataTable rows={escRows} columns={escCols} emptyMessage="No escalations" rowKey={(r, i) => String((r as EscRow).chain_name ?? i) + '-' + String((r as EscRow).quarter_label ?? i)} />
      </section>
    </div>
  );
}
