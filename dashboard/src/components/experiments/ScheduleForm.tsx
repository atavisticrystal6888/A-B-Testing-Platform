interface ScheduleFormProps {
  scheduledStartAt?: string;
  scheduledEndAt?: string;
  onChange: (field: string, value: string) => void;
}

export function ScheduleForm({ scheduledStartAt, scheduledEndAt, onChange }: ScheduleFormProps) {
  return (
    <div className="space-y-4 p-4 bg-gray-50 rounded-xl border border-gray-200">
      <h4 className="text-sm font-semibold text-gray-700">Schedule</h4>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">
            Start Date & Time
          </label>
          <input
            type="datetime-local"
            value={scheduledStartAt || ''}
            onChange={(e) => onChange('scheduled_start_at', e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
          <p className="text-xs text-gray-400 mt-1">
            Leave empty to start manually
          </p>
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">
            End Date & Time
          </label>
          <input
            type="datetime-local"
            value={scheduledEndAt || ''}
            onChange={(e) => onChange('scheduled_end_at', e.target.value)}
            min={scheduledStartAt || ''}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
          <p className="text-xs text-gray-400 mt-1">
            Leave empty for no auto-end
          </p>
        </div>
      </div>
    </div>
  );
}
