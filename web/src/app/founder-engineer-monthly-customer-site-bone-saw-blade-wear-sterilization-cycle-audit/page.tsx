import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type BladeStatusRow = { blade_status: string; blade_count: number; retired_count: number; avg_wear: number };
type EngineerRow = { engineer_name: string; blades_audited: number; red_blades: number; amber_blades: number; avg_quality: number };
type ModelRow = { blade_model: string; units: number; avg_wear: number; avg_chips: number; replacements_due: number };
type SiteRow = { customer_site_name: string; city: string; blades_due: number; avg_wear: number; worst_quality: number };
type OutcomeRow = { audit_outcome: string; audits: number; total_failed_cycles: number; avg_compliance: number };
type MethodRow = { cycle_method: string; runs: number; failures: number; bi_pass_rate: number; avg_compliance: number };
type FindingRow = { audited_at: string; engineer_name: string; customer_site_name: string; autoclave_serial: string; audit_outcome: string; sterility_compliance_pct: number; remediation: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [status, engineers, models, sites, outcomes, methods, findings] = await Promise.all([
    supabase.rpc('r3042_blade_status_distribution'),
    supabase.rpc('r3042_engineer_blade_scorecard'),
    supabase.rpc('r3042_blade_model_wear_summary'),
    supabase.rpc('r3042_site_replacement_queue'),
    supabase.rpc('r3042_sterilization_outcome_distribution'),
    supabase.rpc('r3042_cycle_method_health'),
    supabase.rpc('r3042_critical_findings_feed'),
  ]);

  const statusCols: Column<BladeStatusRow>[] = [
    { header: 'Status', accessor: (r) => r.blade_status },
    { header: 'Blades', accessor: (r) => r.blade_count },
    { header: 'Retired', accessor: (r) => r.retired_count },
    { header: 'Avg Wear %', accessor: (r) => r.avg_wear },
  ];
  const engCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audited', accessor: (r) => r.blades_audited },
    { header: 'Red', accessor: (r) => r.red_blades },
    { header: 'Amber', accessor: (r) => r.amber_blades },
    { header: 'Avg Quality', accessor: (r) => r.avg_quality },
  ];
  const modelCols: Column<ModelRow>[] = [
    { header: 'Model', accessor: (r) => r.blade_model },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Avg Wear %', accessor: (r) => r.avg_wear },
    { header: 'Avg Chips', accessor: (r) => r.avg_chips },
    { header: 'Replace Due', accessor: (r) => r.replacements_due },
  ];
  const siteCols: Column<SiteRow>[] = [
    { header: 'Site', accessor: (r) => r.customer_site_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Due', accessor: (r) => r.blades_due },
    { header: 'Avg Wear %', accessor: (r) => r.avg_wear },
    { header: 'Worst Quality', accessor: (r) => r.worst_quality },
  ];
  const outCols: Column<OutcomeRow>[] = [
    { header: 'Outcome', accessor: (r) => r.audit_outcome },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Failed Cycles', accessor: (r) => r.total_failed_cycles },
    { header: 'Avg Compliance %', accessor: (r) => r.avg_compliance },
  ];
  const methodCols: Column<MethodRow>[] = [
    { header: 'Method', accessor: (r) => r.cycle_method },
    { header: 'Runs', accessor: (r) => r.runs },
    { header: 'Failures', accessor: (r) => r.failures },
    { header: 'BI Pass %', accessor: (r) => r.bi_pass_rate },
    { header: 'Avg Compliance %', accessor: (r) => r.avg_compliance },
  ];
  const findCols: Column<FindingRow>[] = [
    { header: 'When', accessor: (r) => new Date(r.audited_at).toLocaleString() },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Site', accessor: (r) => r.customer_site_name },
    { header: 'Autoclave', accessor: (r) => r.autoclave_serial },
    { header: 'Outcome', accessor: (r) => r.audit_outcome },
    { header: 'Compliance %', accessor: (r) => r.sterility_compliance_pct },
    { header: 'Remediation', accessor: (r) => r.remediation ?? '—' },
  ];

  return (
    <div className="space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Monthly Bone-Saw Blade Wear & Sterilization Cycle Audit</h1>
        <p className="text-sm text-muted-foreground">Founder console r3042 — blade lifecycle & OT sterility compliance across customer sites.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Blade status distribution</h2>
        <DataTable<BladeStatusRow>
          rows={(status.data ?? []) as BladeStatusRow[]}
          columns={statusCols}
          emptyMessage="No blade audits."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer blade scorecard</h2>
        <DataTable<EngineerRow>
          rows={(engineers.data ?? []) as EngineerRow[]}
          columns={engCols}
          emptyMessage="No engineer rows."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Blade model wear summary</h2>
        <DataTable<ModelRow>
          rows={(models.data ?? []) as ModelRow[]}
          columns={modelCols}
          emptyMessage="No models."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Site replacement queue</h2>
        <DataTable<SiteRow>
          rows={(sites.data ?? []) as SiteRow[]}
          columns={siteCols}
          emptyMessage="Nothing pending."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Sterilization outcome distribution</h2>
        <DataTable<OutcomeRow>
          rows={(outcomes.data ?? []) as OutcomeRow[]}
          columns={outCols}
          emptyMessage="No outcomes."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Cycle method health</h2>
        <DataTable<MethodRow>
          rows={(methods.data ?? []) as MethodRow[]}
          columns={methodCols}
          emptyMessage="No methods."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Critical & major findings feed</h2>
        <DataTable<FindingRow>
          rows={(findings.data ?? []) as FindingRow[]}
          columns={findCols}
          emptyMessage="No findings — all clean."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
