import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictMix = {
  hospital_name: string;
  total_audits: number;
  sterile_pass: number;
  marginal_release: number;
  quarantine_cnt: number;
  reject_discard: number;
  recall_lot: number;
};

type MethodRollup = {
  sterility_method: string;
  audits: number;
  avg_bioburden: number | null;
  max_endotoxin: number | null;
  leak_rate_pct: number | null;
};

type ReuseRisk = {
  reuse_band: string;
  audits: number;
  problem_verdicts: number;
  problem_pct: number | null;
};

type VacuumDeviation = {
  measurement_phase: string;
  samples: number;
  avg_target: number;
  avg_actual: number;
  avg_deviation: number | null;
  alarm_rate_pct: number | null;
};

type RiskByAge = {
  cross_contamination_risk_tier: string;
  patient_age_band: string;
  samples: number;
  complication_cnt: number;
};

type CapaQueue = {
  hospital_name: string;
  audit_date: string;
  audit_verdict: string;
  capa_owner_name: string | null;
  capa_due_date: string | null;
  days_to_due: number | null;
};

type LotRecall = {
  tubing_set_lot: string;
  audits: number;
  max_bioburden: number | null;
  quarantine_or_recall: number;
  recommend_recall: boolean;
};

type SurgeonScore = {
  surgeon_name: string;
  hospital_name: string;
  sessions: number;
  cases: number;
  complications: number;
  complication_rate_pct: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictMix,
    methodRollup,
    reuseRisk,
    vacuumDeviation,
    riskByAge,
    capaQueue,
    lotRecall,
    surgeonScore,
  ] = await Promise.all([
    supabase.rpc('founder_phaco_r3130_verdict_mix'),
    supabase.rpc('founder_phaco_r3130_sterility_method_rollup'),
    supabase.rpc('founder_phaco_r3130_cassette_reuse_risk'),
    supabase.rpc('founder_phaco_r3130_vacuum_deviation_by_phase'),
    supabase.rpc('founder_phaco_r3130_risk_by_age'),
    supabase.rpc('founder_phaco_r3130_capa_queue'),
    supabase.rpc('founder_phaco_r3130_lot_recall_signal'),
    supabase.rpc('founder_phaco_r3130_surgeon_scoreboard'),
  ]);

  const verdictRows = (verdictMix.data ?? []) as VerdictMix[];
  const methodRows = (methodRollup.data ?? []) as MethodRollup[];
  const reuseRows = (reuseRisk.data ?? []) as ReuseRisk[];
  const vacuumRows = (vacuumDeviation.data ?? []) as VacuumDeviation[];
  const ageRows = (riskByAge.data ?? []) as RiskByAge[];
  const capaRows = (capaQueue.data ?? []) as CapaQueue[];
  const lotRows = (lotRecall.data ?? []) as LotRecall[];
  const surgeonRows = (surgeonScore.data ?? []) as SurgeonScore[];

  const verdictCols: Column<VerdictMix>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'sterile_pass', header: 'Sterile pass' },
    { key: 'marginal_release', header: 'Marginal' },
    { key: 'quarantine_cnt', header: 'Quarantine' },
    { key: 'reject_discard', header: 'Reject' },
    { key: 'recall_lot', header: 'Recall' },
  ];

  const methodCols: Column<MethodRollup>[] = [
    { key: 'sterility_method', header: 'Sterility method' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_bioburden', header: 'Avg bioburden (CFU/mL)' },
    { key: 'max_endotoxin', header: 'Max endotoxin (EU/mL)' },
    { key: 'leak_rate_pct', header: 'Leak rate %' },
  ];

  const reuseCols: Column<ReuseRisk>[] = [
    { key: 'reuse_band', header: 'Cassette reuse band' },
    { key: 'audits', header: 'Audits' },
    { key: 'problem_verdicts', header: 'Problem verdicts' },
    { key: 'problem_pct', header: 'Problem %' },
  ];

  const vacuumCols: Column<VacuumDeviation>[] = [
    { key: 'measurement_phase', header: 'Phase' },
    { key: 'samples', header: 'Samples' },
    { key: 'avg_target', header: 'Avg target mmHg' },
    { key: 'avg_actual', header: 'Avg actual mmHg' },
    { key: 'avg_deviation', header: 'Avg deviation' },
    { key: 'alarm_rate_pct', header: 'Alarm rate %' },
  ];

  const ageCols: Column<RiskByAge>[] = [
    { key: 'cross_contamination_risk_tier', header: 'Risk tier' },
    { key: 'patient_age_band', header: 'Age band' },
    { key: 'samples', header: 'Samples' },
    { key: 'complication_cnt', header: 'Complications' },
  ];

  const capaCols: Column<CapaQueue>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'audit_date', header: 'Audit date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'capa_owner_name', header: 'CAPA owner' },
    { key: 'capa_due_date', header: 'Due date' },
    { key: 'days_to_due', header: 'Days to due' },
  ];

  const lotCols: Column<LotRecall>[] = [
    { key: 'tubing_set_lot', header: 'Tubing lot' },
    { key: 'audits', header: 'Audits' },
    { key: 'max_bioburden', header: 'Max bioburden' },
    { key: 'quarantine_or_recall', header: 'Quarantine/recall' },
    {
      key: 'recommend_recall',
      header: 'Recall signal',
      render: (r: LotRecall) => (r.recommend_recall ? 'RECALL' : 'monitor'),
    },
  ];

  const surgeonCols: Column<SurgeonScore>[] = [
    { key: 'surgeon_name', header: 'Surgeon' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'sessions', header: 'Sessions' },
    { key: 'cases', header: 'Cases' },
    { key: 'complications', header: 'Complications' },
    { key: 'complication_rate_pct', header: 'Complication rate %' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Phaco Tubing-Set Sterility & Vacuum Performance Audit
        </h1>
        <p className="text-sm text-gray-600">
          Round r3130 — ophthalmology cataract OT fluidics review covering sterility
          methods, cassette reuse, vacuum deviation, cross-contamination risk tiers
          and CAPA closure across customer eye-hospital sites.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Verdict mix per hospital</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audit verdicts recorded."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Sterility method rollup</h2>
        <DataTable
          rows={methodRows}
          columns={methodCols}
          emptyMessage="No sterility-method telemetry."
          rowKey={(r, i) => String(r.sterility_method ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Cassette reuse risk bands</h2>
        <DataTable
          rows={reuseRows}
          columns={reuseCols}
          emptyMessage="No cassette-reuse data."
          rowKey={(r, i) => String(r.reuse_band ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">
          Vacuum deviation by phaco phase (target vs actual mmHg)
        </h2>
        <DataTable
          rows={vacuumRows}
          columns={vacuumCols}
          emptyMessage="No vacuum samples."
          rowKey={(r, i) => String(r.measurement_phase ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">
          Cross-contamination risk tier x patient age band
        </h2>
        <DataTable
          rows={ageRows}
          columns={ageCols}
          emptyMessage="No risk-by-age telemetry."
          rowKey={(r, i) =>
            String(`${r.cross_contamination_risk_tier}-${r.patient_age_band}-${i}`)
          }
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open CAPA queue</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No open CAPA items."
          rowKey={(r, i) => String(`${r.hospital_name}-${r.audit_date}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">
          Tubing-lot recall signal (bioburden &gt; 5 CFU/mL or any reject/recall verdict)
        </h2>
        <DataTable
          rows={lotRows}
          columns={lotCols}
          emptyMessage="No lots flagged."
          rowKey={(r, i) => String(r.tubing_set_lot ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Surgeon complication scoreboard</h2>
        <DataTable
          rows={surgeonRows}
          columns={surgeonCols}
          emptyMessage="No surgeon sessions logged."
          rowKey={(r, i) => String(`${r.surgeon_name}-${r.hospital_name}-${i}`)}
        />
      </section>
    </div>
  );
}
