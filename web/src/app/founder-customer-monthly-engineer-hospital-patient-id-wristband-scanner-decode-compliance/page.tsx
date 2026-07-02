import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyVolume = { scan_month: string; total_scans: number; decoded: number; failed: number; tampered: number };
type DecodeBreak = { decode_status: string; n: number; avg_ms: number | null };
type ComplianceMix = { compliance_state: string; n: number };
type WardPerf = { ward_label: string; scans: number; non_compliant: number };
type DeviceSpeed = { device_model: string; scans: number; avg_ms: number | null };
type SeverityMix = { severity: string; n: number; open_n: number };
type OpenFinding = { finding_type: string; severity: string; resolution_state: string; notes: string | null; detected_at: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [monthly, decode, mix, ward, device, sev, open] = await Promise.all([
    supabase.rpc('founder_r3084_monthly_scan_volume'),
    supabase.rpc('founder_r3084_decode_status_breakdown'),
    supabase.rpc('founder_r3084_compliance_state_mix'),
    supabase.rpc('founder_r3084_ward_performance'),
    supabase.rpc('founder_r3084_device_decode_speed'),
    supabase.rpc('founder_r3084_finding_severity_mix'),
    supabase.rpc('founder_r3084_open_findings'),
  ]);

  const monthlyRows = (monthly.data ?? []) as MonthlyVolume[];
  const decodeRows = (decode.data ?? []) as DecodeBreak[];
  const mixRows = (mix.data ?? []) as ComplianceMix[];
  const wardRows = (ward.data ?? []) as WardPerf[];
  const deviceRows = (device.data ?? []) as DeviceSpeed[];
  const sevRows = (sev.data ?? []) as SeverityMix[];
  const openRows = (open.data ?? []) as OpenFinding[];

  const monthlyCols: Column<MonthlyVolume>[] = [
    { header: 'Month', accessor: (r) => r.scan_month },
    { header: 'Total', accessor: (r) => r.total_scans },
    { header: 'Decoded', accessor: (r) => r.decoded },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Tampered', accessor: (r) => r.tampered },
  ];
  const decodeCols: Column<DecodeBreak>[] = [
    { header: 'Status', accessor: (r) => r.decode_status },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Avg ms', accessor: (r) => r.avg_ms ?? '—' },
  ];
  const mixCols: Column<ComplianceMix>[] = [
    { header: 'Compliance', accessor: (r) => r.compliance_state },
    { header: 'N', accessor: (r) => r.n },
  ];
  const wardCols: Column<WardPerf>[] = [
    { header: 'Ward', accessor: (r) => r.ward_label },
    { header: 'Scans', accessor: (r) => r.scans },
    { header: 'Non-compliant', accessor: (r) => r.non_compliant },
  ];
  const deviceCols: Column<DeviceSpeed>[] = [
    { header: 'Device', accessor: (r) => r.device_model },
    { header: 'Scans', accessor: (r) => r.scans },
    { header: 'Avg ms', accessor: (r) => r.avg_ms ?? '—' },
  ];
  const sevCols: Column<SeverityMix>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Open', accessor: (r) => r.open_n },
  ];
  const openCols: Column<OpenFinding>[] = [
    { header: 'Type', accessor: (r) => r.finding_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'State', accessor: (r) => r.resolution_state },
    { header: 'Notes', accessor: (r) => r.notes ?? '—' },
    { header: 'Detected', accessor: (r) => new Date(r.detected_at).toLocaleString() },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Patient ID Wristband Scanner-Decode Compliance — r3084</h1>
        <p className="text-sm text-gray-600">Monthly engineer audit of hospital patient identity wristband scans & compliance findings.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly Scan Volume</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No scans" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Decode Status Breakdown</h2>
        <DataTable rows={decodeRows} columns={decodeCols} emptyMessage="No data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Compliance State Mix</h2>
        <DataTable rows={mixRows} columns={mixCols} emptyMessage="No data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Ward Performance</h2>
        <DataTable rows={wardRows} columns={wardCols} emptyMessage="No wards" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Device Decode Speed</h2>
        <DataTable rows={deviceRows} columns={deviceCols} emptyMessage="No devices" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Finding Severity Mix</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No findings" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open Findings</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="All clear" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </div>
  );
}
