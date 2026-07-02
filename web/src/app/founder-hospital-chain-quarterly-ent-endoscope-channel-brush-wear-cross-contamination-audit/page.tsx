import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/data-table';
import type { Column } from '@/components/data-table';

export const dynamic = 'force-dynamic';

type ChainSummary = { chain_code: string; scopes_audited: number; breaches: number; avg_bristle_loss: number; severe_deformations: number };
type Overdue = { chain_code: string; hospital_site: string; endoscope_serial: string; cycles_overdue: number; last_brush_change_at: string | null };
type RiskRollup = { risk_tier: string; swabs: number; total_patient_exposure: number; avg_cfu: number };
type Organism = { organism_detected: string; occurrences: number; hospitals_hit: number; max_cfu: number };
type Correlation = { chain_code: string; breach_scopes: number; contam_events_from_worn_brush: number; patient_exposure: number };
type Quarantine = { chain_code: string; hospital_site: string; endoscope_serial: string; organism_detected: string; cfu_count: number; swab_taken_at: string };
type ChannelProfile = { channel_type: string; scopes: number; avg_bristle_loss: number; red_or_critical_swabs: number; total_exposure: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summary, overdue, rollup, organisms, correlation, quarantines, channels] = await Promise.all([
    supabase.rpc('founder_brush_wear_chain_summary_r3071'),
    supabase.rpc('founder_brush_overdue_replacements_r3071'),
    supabase.rpc('founder_contam_risk_rollup_r3071'),
    supabase.rpc('founder_contam_organism_breakdown_r3071'),
    supabase.rpc('founder_worn_brush_contam_correlation_r3071'),
    supabase.rpc('founder_open_quarantines_r3071'),
    supabase.rpc('founder_channel_type_risk_profile_r3071'),
  ]);

  const summaryRows: ChainSummary[] = (summary.data as ChainSummary[] | null) ?? [];
  const overdueRows: Overdue[] = (overdue.data as Overdue[] | null) ?? [];
  const rollupRows: RiskRollup[] = (rollup.data as RiskRollup[] | null) ?? [];
  const orgRows: Organism[] = (organisms.data as Organism[] | null) ?? [];
  const corrRows: Correlation[] = (correlation.data as Correlation[] | null) ?? [];
  const qRows: Quarantine[] = (quarantines.data as Quarantine[] | null) ?? [];
  const chRows: ChannelProfile[] = (channels.data as ChannelProfile[] | null) ?? [];

  const summaryCols: Column<ChainSummary>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Scopes Audited', accessor: (r) => r.scopes_audited },
    { header: 'Breaches', accessor: (r) => r.breaches },
    { header: 'Avg Bristle Loss %', accessor: (r) => r.avg_bristle_loss },
    { header: 'Severe Deformations', accessor: (r) => r.severe_deformations },
  ];

  const overdueCols: Column<Overdue>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Hospital', accessor: (r) => r.hospital_site },
    { header: 'Scope Serial', accessor: (r) => r.endoscope_serial },
    { header: 'Cycles Overdue', accessor: (r) => r.cycles_overdue },
    { header: 'Last Brush Change', accessor: (r) => r.last_brush_change_at ?? '—' },
  ];

  const rollupCols: Column<RiskRollup>[] = [
    { header: 'Risk Tier', accessor: (r) => r.risk_tier },
    { header: 'Swabs', accessor: (r) => r.swabs },
    { header: 'Total Patient Exposure', accessor: (r) => r.total_patient_exposure },
    { header: 'Avg CFU', accessor: (r) => r.avg_cfu },
  ];

  const orgCols: Column<Organism>[] = [
    { header: 'Organism', accessor: (r) => r.organism_detected },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Hospitals Hit', accessor: (r) => r.hospitals_hit },
    { header: 'Max CFU', accessor: (r) => r.max_cfu },
  ];

  const corrCols: Column<Correlation>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Breach Scopes', accessor: (r) => r.breach_scopes },
    { header: 'Worn-Brush Contam Events', accessor: (r) => r.contam_events_from_worn_brush },
    { header: 'Patient Exposure', accessor: (r) => r.patient_exposure },
  ];

  const qCols: Column<Quarantine>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Hospital', accessor: (r) => r.hospital_site },
    { header: 'Scope Serial', accessor: (r) => r.endoscope_serial },
    { header: 'Organism', accessor: (r) => r.organism_detected },
    { header: 'CFU', accessor: (r) => r.cfu_count },
    { header: 'Swab At', accessor: (r) => r.swab_taken_at },
  ];

  const chCols: Column<ChannelProfile>[] = [
    { header: 'Channel Type', accessor: (r) => r.channel_type },
    { header: 'Scopes', accessor: (r) => r.scopes },
    { header: 'Avg Bristle Loss %', accessor: (r) => r.avg_bristle_loss },
    { header: 'Red/Critical Swabs', accessor: (r) => r.red_or_critical_swabs },
    { header: 'Total Exposure', accessor: (r) => r.total_exposure },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital Chain Quarterly ENT Endoscope Channel Brush Wear &amp; Cross-Contamination Audit</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Cross-chain view: channel-brush wear &gt;= breach threshold rolls up to cross-contamination risk tiers. Worn brush =&gt; biofilm =&gt; patient exposure.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>1. Chain Brush-Wear Summary</h2>
        <DataTable rows={summaryRows} columns={summaryCols} emptyMessage="No brush-wear data" rowKey={(r, i) => String((r as ChainSummary).chain_code ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>2. Overdue Brush Replacements (cycles &lt; 0)</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue scopes" rowKey={(r, i) => String((r as Overdue).endoscope_serial ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>3. Contamination Risk Roll-up</h2>
        <DataTable rows={rollupRows} columns={rollupCols} emptyMessage="No swab data" rowKey={(r, i) => String((r as RiskRollup).risk_tier ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>4. Organism Breakdown</h2>
        <DataTable rows={orgRows} columns={orgCols} emptyMessage="No organisms detected" rowKey={(r, i) => String((r as Organism).organism_detected ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>5. Worn-Brush =&gt; Contamination Correlation</h2>
        <DataTable rows={corrRows} columns={corrCols} emptyMessage="No correlations" rowKey={(r, i) => String((r as Correlation).chain_code ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>6. Open Quarantines (unresolved)</h2>
        <DataTable rows={qRows} columns={qCols} emptyMessage="No open quarantines" rowKey={(r, i) => String((r as Quarantine).endoscope_serial ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>7. Channel-Type Risk Profile</h2>
        <DataTable rows={chRows} columns={chCols} emptyMessage="No channel data" rowKey={(r, i) => String((r as ChannelProfile).channel_type ?? i)} />
      </section>
    </div>
  );
}
