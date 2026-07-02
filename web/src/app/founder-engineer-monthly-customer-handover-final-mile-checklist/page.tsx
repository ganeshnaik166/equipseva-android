import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };
type StepRow = { handover_step: string; total: number; signed_count: number; blocker_count: number };
type FinalMileRow = { final_mile_action: string; total: number; thanked: number };
type SignoffRow = { signoff_state: string; total: number; green_count: number; red_count: number };
type Checklist = { engineer_code: string; engineer_name: string; customer_org: string; handover_step: string; signoff_state: string; verdict: string; customer_thanked: boolean; duration_minutes: number };
type Rollup = { engineer_code: string; total_handovers: number; signed_count: number; thanked_count: number; blocker_count: number; coach_bucket: string; avg_duration_minutes: number };
type Coach = { coach_bucket: string; engineers: number; total_signed: number; total_blocker: number };
type Alert = { engineer_code: string; engineer_name: string; customer_org: string; handover_step: string; notes: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, byStep, byFinalMile, bySignoff, recent, rollup, coach, alerts] = await Promise.all([
    supabase.rpc('founder_r2834_overview'),
    supabase.rpc('founder_r2834_by_step'),
    supabase.rpc('founder_r2834_by_final_mile'),
    supabase.rpc('founder_r2834_by_signoff'),
    supabase.rpc('founder_r2834_recent_checklist'),
    supabase.rpc('founder_r2834_engineer_rollup'),
    supabase.rpc('founder_r2834_coach_buckets'),
    supabase.rpc('founder_r2834_blocker_alerts'),
  ]);

  const kpis: Kpi[] = (overview.data ?? []) as Kpi[];
  const stepRows: StepRow[] = (byStep.data ?? []) as StepRow[];
  const finalMileRows: FinalMileRow[] = (byFinalMile.data ?? []) as FinalMileRow[];
  const signoffRows: SignoffRow[] = (bySignoff.data ?? []) as SignoffRow[];
  const checklist: Checklist[] = (recent.data ?? []) as Checklist[];
  const rollupRows: Rollup[] = (rollup.data ?? []) as Rollup[];
  const coachRows: Coach[] = (coach.data ?? []) as Coach[];
  const alertRows: Alert[] = (alerts.data ?? []) as Alert[];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Monthly Customer Handover &amp; Final-Mile Checklist</h1>
        <p style={{ color: '#666', marginTop: 6 }}>
          Engineer × handover step × final-mile × signoff × customer thanked × verdict. Coverage threshold: signed handovers &gt;= 80%, blocker rate &lt;= 5%.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
            <div style={{ color: '#6b7280', fontSize: 12 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By handover step</h2>
        <DataTable
          rows={stepRows}
          columns={[
            { key: 'handover_step', header: 'Step', render: (r: StepRow) => r.handover_step },
            { key: 'total', header: 'Total', render: (r: StepRow) => String(r.total) },
            { key: 'signed_count', header: 'Signed', render: (r: StepRow) => String(r.signed_count) },
            { key: 'blocker_count', header: 'Blocker', render: (r: StepRow) => String(r.blocker_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: StepRow, i: number) => String(r.handover_step ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By final-mile action</h2>
        <DataTable
          rows={finalMileRows}
          columns={[
            { key: 'final_mile_action', header: 'Final-mile action', render: (r: FinalMileRow) => r.final_mile_action },
            { key: 'total', header: 'Total', render: (r: FinalMileRow) => String(r.total) },
            { key: 'thanked', header: 'Customer thanked', render: (r: FinalMileRow) => String(r.thanked) },
          ]}
          emptyMessage="No data"
          rowKey={(r: FinalMileRow, i: number) => String(r.final_mile_action ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By signoff state</h2>
        <DataTable
          rows={signoffRows}
          columns={[
            { key: 'signoff_state', header: 'Signoff state', render: (r: SignoffRow) => r.signoff_state },
            { key: 'total', header: 'Total', render: (r: SignoffRow) => String(r.total) },
            { key: 'green_count', header: 'Green verdicts', render: (r: SignoffRow) => String(r.green_count) },
            { key: 'red_count', header: 'Red verdicts', render: (r: SignoffRow) => String(r.red_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignoffRow, i: number) => String(r.signoff_state ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent checklist entries</h2>
        <DataTable
          rows={checklist}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: Checklist) => `${r.engineer_code} — ${r.engineer_name}` },
            { key: 'customer_org', header: 'Customer', render: (r: Checklist) => r.customer_org },
            { key: 'handover_step', header: 'Step', render: (r: Checklist) => r.handover_step },
            { key: 'signoff_state', header: 'Signoff', render: (r: Checklist) => r.signoff_state },
            { key: 'verdict', header: 'Verdict', render: (r: Checklist) => r.verdict },
            { key: 'customer_thanked', header: 'Thanked', render: (r: Checklist) => (r.customer_thanked ? 'yes' : 'no') },
            { key: 'duration_minutes', header: 'Duration (min)', render: (r: Checklist) => String(r.duration_minutes) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Checklist, i: number) => `${r.engineer_code}-${i}`}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engineer rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: Rollup) => r.engineer_code },
            { key: 'total_handovers', header: 'Total', render: (r: Rollup) => String(r.total_handovers) },
            { key: 'signed_count', header: 'Signed', render: (r: Rollup) => String(r.signed_count) },
            { key: 'thanked_count', header: 'Thanked', render: (r: Rollup) => String(r.thanked_count) },
            { key: 'blocker_count', header: 'Blocker', render: (r: Rollup) => String(r.blocker_count) },
            { key: 'avg_duration_minutes', header: 'Avg duration', render: (r: Rollup) => String(r.avg_duration_minutes) },
            { key: 'coach_bucket', header: 'Coach bucket', render: (r: Rollup) => r.coach_bucket },
          ]}
          emptyMessage="No data"
          rowKey={(r: Rollup, i: number) => `${r.engineer_code}-${i}`}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Coach buckets</h2>
        <DataTable
          rows={coachRows}
          columns={[
            { key: 'coach_bucket', header: 'Bucket', render: (r: Coach) => r.coach_bucket },
            { key: 'engineers', header: 'Engineers', render: (r: Coach) => String(r.engineers) },
            { key: 'total_signed', header: 'Total signed', render: (r: Coach) => String(r.total_signed) },
            { key: 'total_blocker', header: 'Total blocker', render: (r: Coach) => String(r.total_blocker) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Coach, i: number) => String(r.coach_bucket ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Blocker & red alerts</h2>
        <DataTable
          rows={alertRows}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: Alert) => `${r.engineer_code} — ${r.engineer_name}` },
            { key: 'customer_org', header: 'Customer', render: (r: Alert) => r.customer_org },
            { key: 'handover_step', header: 'Step', render: (r: Alert) => r.handover_step },
            { key: 'notes', header: 'Notes', render: (r: Alert) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: Alert, i: number) => `${r.engineer_code}-${i}`}
        />
      </section>
    </div>
  );
}