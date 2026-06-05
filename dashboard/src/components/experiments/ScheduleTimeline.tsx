interface ScheduleTimelineProps {
  scheduledStartAt?: string;
  scheduledEndAt?: string;
  startedAt?: string;
  endedAt?: string;
  status: string;
}

export function ScheduleTimeline({
  scheduledStartAt,
  scheduledEndAt,
  startedAt,
  endedAt,
  status,
}: ScheduleTimelineProps) {
  const events = [
    scheduledStartAt && { label: 'Scheduled Start', date: scheduledStartAt, type: 'scheduled' },
    startedAt && { label: 'Actual Start', date: startedAt, type: 'actual' },
    scheduledEndAt && { label: 'Scheduled End', date: scheduledEndAt, type: 'scheduled' },
    endedAt && { label: 'Actual End', date: endedAt, type: 'actual' },
  ].filter(Boolean) as Array<{ label: string; date: string; type: string }>;

  if (events.length === 0) return null;

  return (
    <div className="p-4 bg-gray-50 rounded-xl border border-gray-200">
      <h4 className="text-sm font-semibold text-gray-700 mb-3">Timeline</h4>
      <div className="relative">
        <div className="absolute left-3 top-0 bottom-0 w-0.5 bg-gray-200" />
        <div className="space-y-4">
          {events.map((event, i) => (
            <div key={i} className="relative flex items-center gap-3 pl-8">
              <div
                className={`absolute left-1.5 w-3 h-3 rounded-full border-2 ${
                  event.type === 'actual'
                    ? 'bg-indigo-500 border-indigo-500'
                    : 'bg-white border-gray-400'
                }`}
              />
              <div>
                <p className="text-sm font-medium text-gray-900">{event.label}</p>
                <p className="text-xs text-gray-500">
                  {new Date(event.date).toLocaleString()}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-3 pt-3 border-t border-gray-200">
        <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
          status === 'running' ? 'bg-emerald-100 text-emerald-700' :
          status === 'concluded' ? 'bg-blue-100 text-blue-700' :
          'bg-gray-100 text-gray-600'
        }`}>
          {status}
        </span>
      </div>
    </div>
  );
}
