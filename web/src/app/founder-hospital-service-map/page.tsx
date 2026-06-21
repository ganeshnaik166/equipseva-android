import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalServiceMapPage() {
  const sb = await getSupabaseServerClient();

  const [locsRes, hotspotsRes, denseRes, underservedRes, distRes] = await Promise.all([
    sb.rpc('list_hospital_service_geo_locations_r1831'),
    sb.rpc('list_hospital_service_geo_hotspots_r1831'),
    sb.rpc('dense_hospital_service_geo_areas_r1831'),
    sb.rpc('underserved_hospital_service_geo_areas_r1831'),
    sb.rpc('hospital_service_geo_distribution_r1831'),
  ]);

  const locations: any[] = Array.isArray(locsRes.data) ? locsRes.data : [];
  const hotspots: any[] = Array.isArray(hotspotsRes.data) ? hotspotsRes.data : [];
  const denseAreas: any[] = Array.isArray(denseRes.data) ? denseRes.data : [];
  const underserved: any[] = Array.isArray(underservedRes.data) ? underservedRes.data : [];
  const distribution: any[] = Array.isArray(distRes.data) ? distRes.data : [];

  const totalLocations = locations.length;
  const activeLocations = locations.filter((l) => l.status === 'active').length;
  const totalHotspots = hotspots.length;
  const denseCount = denseAreas.length;
  const underservedCount = underserved.length;

  const locColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '—'}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span>{r.city ?? '—'}</span> },
    { key: 'area', header: 'Area', render: (r: any) => <span>{r.area ?? '—'}</span> },
    { key: 'lat', header: 'Lat', render: (r: any) => <span>{r.latitude != null ? Number(r.latitude).toFixed(4) : '—'}</span> },
    { key: 'lng', header: 'Lng', render: (r: any) => <span>{r.longitude != null ? Number(r.longitude).toFixed(4) : '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '—'}</span> },
    { key: 'updated', header: 'Updated', render: (r: any) => <span>{r.last_geo_updated_at ? new Date(r.last_geo_updated_at).toLocaleString() : '—'}</span> },
  ];

  const hotspotColumns: Column<any>[] = [
    { key: 'area', header: 'Area', render: (r: any) => <span>{r.area ?? '—'}</span> },
    { key: 'jobs', header: 'Jobs 30d', render: (r: any) => <span>{r.total_jobs_30d ?? 0}</span> },
    { key: 'resp', header: 'Avg Resp (min)', render: (r: any) => <span>{r.avg_response_min ?? 0}</span> },
    { key: 'density', header: 'Density', render: (r: any) => <span>{r.density_score ?? 0}</span> },
    { key: 'cluster', header: 'Rec. Cluster', render: (r: any) => <span>{r.recommended_engineer_cluster ?? 0}</span> },
  ];

  const denseColumns: Column<any>[] = [
    { key: 'area', header: 'Area', render: (r: any) => <span>{r.area ?? '—'}</span> },
    { key: 'density', header: 'Density', render: (r: any) => <span>{r.density_score ?? 0}</span> },
    { key: 'jobs', header: 'Jobs 30d', render: (r: any) => <span>{r.total_jobs_30d ?? 0}</span> },
    { key: 'cluster', header: 'Rec. Cluster', render: (r: any) => <span>{r.recommended_engineer_cluster ?? 0}</span> },
  ];

  const underservedColumns: Column<any>[] = [
    { key: 'area', header: 'Area', render: (r: any) => <span>{r.area ?? '—'}</span> },
    { key: 'density', header: 'Density', render: (r: any) => <span>{r.density_score ?? 0}</span> },
    { key: 'jobs', header: 'Jobs 30d', render: (r: any) => <span>{r.total_jobs_30d ?? 0}</span> },
    { key: 'cluster', header: 'Rec. Cluster', render: (r: any) => <span>{r.recommended_engineer_cluster ?? 0}</span> },
  ];

  const distColumns: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => <span>{r.city ?? '—'}</span> },
    { key: 'total', header: 'Total', render: (r: any) => <span>{r.total_locations ?? 0}</span> },
    { key: 'active', header: 'Active', render: (r: any) => <span>{r.active_locations ?? 0}</span> },
    { key: 'inactive', header: 'Inactive', render: (r: any) => <span>{r.inactive_locations ?? 0}</span> },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Map</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Geographic distribution of service jobs & hotspot detection.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, background: '#f5f5f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Locations</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalLocations}</div>
        </div>
        <div style={{ padding: 16, background: '#f0fdf4', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{activeLocations}</div>
        </div>
        <div style={{ padding: 16, background: '#fef3c7', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Hotspots</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalHotspots}</div>
        </div>
        <div style={{ padding: 16, background: '#fee2e2', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Dense (density &gt;= 50)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{denseCount}</div>
        </div>
        <div style={{ padding: 16, background: '#dbeafe', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Underserved (density &lt; 50)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{underservedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Hospital Locations</h2>
        <DataTable
          rows={locations}
          columns={locColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Hotspots</h2>
        <DataTable
          rows={hotspots}
          columns={hotspotColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Dense Areas (density &gt;= 50)</h2>
        <DataTable
          rows={denseAreas}
          columns={denseColumns}
          rowKey={(r: any, i: number) => String(r.area ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Underserved Areas (density &lt; 50)</h2>
        <DataTable
          rows={underserved}
          columns={underservedColumns}
          rowKey={(r: any, i: number) => String(r.area ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Geo Distribution by City</h2>
        <DataTable
          rows={distribution}
          columns={distColumns}
          rowKey={(r: any, i: number) => String(r.city ?? i)}
        />
      </section>
    </main>
  );
}
