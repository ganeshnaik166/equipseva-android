import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ToneTrend = { quarter: string; avg_optimism: number; avg_hedges: number; letters: number };
type DriftDist = { drift_flag: string; letters: number; share_pct: number };
type AuthorVoice = { author_role: string; letters: number; avg_optimism: number; avg_singular: number; avg_plural: number };
type SevRow = { severity: string; findings: number; open_count: number; escalated_count: number };
type KindRow = { finding_kind: string; total: number; avg_delta: number | null; critical_count: number };
type ReversalRow = { quarter: string; author_role: string; letter_title: string; tone_label: string; optimism_score: number; drift_flag: string };
type OwnerRow = { owner: string; total: number; open_count: number; rewritten_count: number; escalated_count: number };
type GapRow = { quarter: string; founder_optimism: number | null; engineer_optimism: number | null; gap: number | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [trend, dist, voice, sev, kind, reversal, owner, gap] = await Promise.all([
    sb.rpc('r3057_letter_tone_trend'),
    sb.rpc('r3057_drift_flag_distribution'),
    sb.rpc('r3057_author_voice_compare'),
    sb.rpc('r3057_findings_by_severity'),
    sb.rpc('r3057_finding_kind_heatmap'),
    sb.rpc('r3057_tone_reversal_letters'),
    sb.rpc('r3057_owner_workload'),
    sb.rpc('r3057_cross_author_tone_gap'),
  ]);

  const trendCols: Column<ToneTrend>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Avg optimism', accessor: (r) => r.avg_optimism },
    { header: 'Avg hedges', accessor: (r) => r.avg_hedges },
    { header: 'Letters', accessor: (r) => r.letters },
  ];
  const distCols: Column<DriftDist>[] = [
    { header: 'Drift flag', accessor: (r) => r.drift_flag },
    { header: 'Letters', accessor: (r) => r.letters },
    { header: 'Share %', accessor: (r) => r.share_pct },
  ];
  const voiceCols: Column<AuthorVoice>[] = [
    { header: 'Author', accessor: (r) => r.author_role },
    { header: 'Letters', accessor: (r) => r.letters },
    { header: 'Avg optimism', accessor: (r) => r.avg_optimism },
    { header: 'Singular ratio', accessor: (r) => r.avg_singular },
    { header: 'Plural ratio', accessor: (r) => r.avg_plural },
  ];
  const sevCols: Column<SevRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
  ];
  const kindCols: Column<KindRow>[] = [
    { header: 'Kind', accessor: (r) => r.finding_kind },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Avg delta', accessor: (r) => r.avg_delta ?? '-' },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];
  const reversalCols: Column<ReversalRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Author', accessor: (r) => r.author_role },
    { header: 'Title', accessor: (r) => r.letter_title },
    { header: 'Tone', accessor: (r) => r.tone_label },
    { header: 'Optimism', accessor: (r) => r.optimism_score },
    { header: 'Drift', accessor: (r) => r.drift_flag },
  ];
  const ownerCols: Column<OwnerRow>[] = [
    { header: 'Owner', accessor: (r) => r.owner },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Rewritten', accessor: (r) => r.rewritten_count },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
  ];
  const gapCols: Column<GapRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Founder optimism', accessor: (r) => r.founder_optimism ?? '-' },
    { header: 'Engineer optimism', accessor: (r) => r.engineer_optimism ?? '-' },
    { header: 'Gap', accessor: (r) => r.gap ?? '-' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Investor Letter Tone Drift Audit</h1>
        <p className="text-sm text-gray-600">Round r3057 — founder & engineer-founder public letter tone drift surface</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Letter tone trend by quarter</h2>
        <DataTable<ToneTrend>
          rows={(trend.data ?? []) as ToneTrend[]}
          columns={trendCols}
          emptyMessage="No tone trend"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drift flag distribution</h2>
        <DataTable<DriftDist>
          rows={(dist.data ?? []) as DriftDist[]}
          columns={distCols}
          emptyMessage="No drift data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Author voice comparison</h2>
        <DataTable<AuthorVoice>
          rows={(voice.data ?? []) as AuthorVoice[]}
          columns={voiceCols}
          emptyMessage="No author voice"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings by severity</h2>
        <DataTable<SevRow>
          rows={(sev.data ?? []) as SevRow[]}
          columns={sevCols}
          emptyMessage="No severity rows"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finding kind heatmap</h2>
        <DataTable<KindRow>
          rows={(kind.data ?? []) as KindRow[]}
          columns={kindCols}
          emptyMessage="No findings"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tone reversal & material drift letters</h2>
        <DataTable<ReversalRow>
          rows={(reversal.data ?? []) as ReversalRow[]}
          columns={reversalCols}
          emptyMessage="No reversals"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner workload</h2>
        <DataTable<OwnerRow>
          rows={(owner.data ?? []) as OwnerRow[]}
          columns={ownerCols}
          emptyMessage="No owner load"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cross-author tone gap (same quarter)</h2>
        <DataTable<GapRow>
          rows={(gap.data ?? []) as GapRow[]}
          columns={gapCols}
          emptyMessage="No gap data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
