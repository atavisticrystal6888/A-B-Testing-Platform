interface TimelineExperiment {
  id: string;
  name: string;
  status: string;
  started_at: string;
  ended_at?: string;
  feature_tag: string;
}

interface TimelineChartProps {
  experiments: TimelineExperiment[];
}

const statusColors: Record<string, string> = {
  running: '#10B981',
  paused: '#F59E0B',
  concluded: '#6366F1',
  draft: '#9CA3AF',
};

export function TimelineChart({ experiments }: TimelineChartProps) {
  const now = Date.now();

  const data = experiments.map((exp) => {
    const start = new Date(exp.started_at).getTime();
    const end = exp.ended_at ? new Date(exp.ended_at).getTime() : now;
    return {
      name: exp.name,
      start,
      end,
      duration: end - start,
      status: exp.status,
    };
  });

  // Detect overlaps
  const overlaps: Array<{ start: number; end: number }> = [];
  for (let i = 0; i < data.length; i++) {
    for (let j = i + 1; j < data.length; j++) {
      const overlapStart = Math.max(data[i].start, data[j].start);
      const overlapEnd = Math.min(data[i].end, data[j].end);
      if (overlapStart < overlapEnd) {
        overlaps.push({ start: overlapStart, end: overlapEnd });
      }
    }
  }

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6">
      <h3 className="text-sm font-semibold text-gray-600 uppercase tracking-wider mb-4">
        Experiment Timeline
      </h3>

      <div className="space-y-2">
        {data.map((exp, i) => {
          const minTime = Math.min(...data.map((d) => d.start));
          const maxTime = Math.max(...data.map((d) => d.end));
          const range = maxTime - minTime || 1;
          const left = ((exp.start - minTime) / range) * 100;
          const width = (exp.duration / range) * 100;

          return (
            <div key={i} className="flex items-center gap-3">
              <div className="w-32 text-sm text-gray-700 truncate text-right" title={exp.name}>
                {exp.name}
              </div>
              <div className="flex-1 h-8 relative bg-gray-50 rounded">
                <div
                  className="absolute h-full rounded transition-all"
                  style={{
                    left: `${left}%`,
                    width: `${Math.max(width, 1)}%`,
                    backgroundColor: statusColors[exp.status] || '#9CA3AF',
                    opacity: 0.8,
                  }}
                />
              </div>
            </div>
          );
        })}
      </div>

      {overlaps.length > 0 && (
        <div className="mt-3 p-2 bg-amber-50 border border-amber-200 rounded-lg">
          <p className="text-xs text-amber-700 font-medium">
            ⚠ {overlaps.length} overlapping period{overlaps.length > 1 ? 's' : ''} detected
          </p>
        </div>
      )}
    </div>
  );
}
