import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = { audit_month: string; audits: number; exact_pct: number | null; avg_match_score: number | null; avg_csat: number | null; total_rework: number };
type ByTier = { match_tier: string; audits: number; avg_score: number | null; avg_csat: number | null; rework_total: number };
type ByEquip = { equipment_category: string; audits: number; avg_match: number | null; flagged: number; escalated: number };
type Scorecard = { engineer_label: string; audits: number; avg_score: number | null; avg_csat: number | null; flagged: number; total_rework: number };
type SegmentLens = { customer_segment: string; audits: number; avg_match: number | null; mismatch_count: number; avg_csat: number | null };
type FindingsRow = { finding_type: string; severity: string; items: number; rupees_impact: number; open_items: number };
type EscRow = { engineer_label: string; equipment_category: string; customer_label: string; audit_month: string; match_score: number | null; severity: string; finding_note: string; rupees_impact: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [m1, m2, m3, m4, m5, m6, m7] = await Promise.all([
    sb.rpc('founder_r2948_monthly_match_summary'),
    sb.rpc('founder_r2948_by_match_tier'),
    sb.rpc('founder_r2948_by_equipment_category'),
    sb.rpc('founder_r2948_engineer_scorecard'),
    sb.rpc('founder_r2948_customer_segment_lens'),
    sb.rpc('founder_r2948_findings_rollup'),
    sb.rpc('founder_r2948_escalation_queue'),
  ]);

  const monthly = (m1.data ?? []) as MonthlySummary[];
  const tiers = (m2.data ?? []) as ByTier[];
  const equip = (m3.data ?? []) as ByEquip[];
  const scorecards = (m4.data ?? []) as Scorecard[];
  const segments = (m5.data ?? []) as SegmentLens[];
  const findings = (m6.data ?? []) as FindingsRow[];
  const escal = (m7.data ?? []) as EscRow[];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Exact %', accessor: (r) => (r.exact_pct ?? 0) + '%' },
    { header: 'Avg Match', accessor: (r) => r.avg_match_score ?? '—' },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat ?? '—' },
    { header: 'Rework', accessor: (r) => r.total_rework },
  ];

  const tierCols: Column<ByTier>[] = [
    { header: 'Tier', accessor: (r) => r.match_tier },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score ?? '—' },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat ?? '—' },
    { header: 'Rework', accessor: (r) => r.rework_total },
  ];

  const equipCols: Column<ByEquip>[] = [
    { header: 'Equipment', accessor: (r) => r.equipment_category },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Match', accessor: (r) => r.avg_match ?? '—' },
    { header: 'Flagged', accessor: (r) => r.flagged },
    { header: 'Escalated', accessor: (r) => r.escalated },
  ];

  const scoreCols: Column<Scorecard>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_label },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Score', accessor: (r) => r.avg_score ?? '—' },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat ?? '—' },
    { header: 'Flagged', accessor: (r) => r.flagged },
    { header: 'Rework', accessor: (r) => r.total_rework },
  ];

  const segCols: Column<SegmentLens>[] = [
    { header: 'Segment', accessor: (r) => r.customer_segment },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Match', accessor: (r) => r.avg_match ?? '—' },
    { header: 'Mismatch', accessor: (r) => r.mismatch_count },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat ?? '—' },
  ];

  const findCols: Column<FindingsRow>[] = [
    { header: 'Finding', accessor: (r) => r.finding_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Items', accessor: (r) => r.items },
    { header: 'Open', accessor: (r) => r.open_items },
    { header: 'Rupees Impact', accessor: (r) => '₹' + (r.rupees_impact ?? 0).toLocaleString('en-IN') },
  ];

  const escCols: Column<EscRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_label },
    { header: 'Equipment', accessor: (r) => r.equipment_category },
    { header: 'Customer', accessor: (r) => r.customer_label },
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Score', accessor: (r) => r.match_score ?? '—' },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Note', accessor: (r) => r.finding_note },
    { header: 'Impact', accessor: (r) => '₹' + (r.rupees_impact ?? 0).toLocaleString('en-IN') },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer Monthly Engineer Equipment-Specialization Match Quality Audit</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Monthly audit of engineer specialization vs equipment category vs customer segment. Flags mismatches that hurt CSAT & drive rework cost.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>1. Monthly Summary</h2>
        <DataTable rows={monthly} columns={monthlyCols} emptyMessage="No audits yet" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>2. By Match Tier</h2>
        <DataTable rows={tiers} columns={tierCols} emptyMessage="No tier breakdown" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>3. By Equipment Category (lowest match first)</h2>
        <DataTable rows={equip} columns={equipCols} emptyMessage="No equipment data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>4. Engineer Scorecard</h2>
        <DataTable rows={scorecards} columns={scoreCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>5. Customer Segment Lens</h2>
        <DataTable rows={segments} columns={segCols} emptyMessage="No segment data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>6. Findings Rollup (sorted by rupees impact)</h2>
        <DataTable rows={findings} columns={findCols} emptyMessage="No findings" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>7. Founder Escalation Queue</h2>
        <DataTable rows={escal} columns={escCols} emptyMessage="No escalations — all clear" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </main>
  );
}
