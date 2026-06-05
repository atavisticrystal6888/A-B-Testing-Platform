interface ExportButtonsProps {
  experimentId: string;
}

export function ExportButtons({ experimentId }: ExportButtonsProps) {
  const formats = [
    { key: 'csv', label: 'CSV', icon: '📄' },
    { key: 'json', label: 'JSON', icon: '📋' },
    { key: 'xlsx', label: 'Excel', icon: '📊' },
  ];

  const handleExport = (format: string) => {
    window.open(`/api/v1/experiments/${experimentId}/export/results?format=${format}`, '_blank');
  };

  return (
    <div className="flex items-center gap-2">
      <span className="text-xs text-gray-500 mr-1">Export:</span>
      {formats.map((f) => (
        <button
          key={f.key}
          onClick={() => handleExport(f.key)}
          className="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 hover:border-gray-400 transition-colors"
        >
          <span>{f.icon}</span>
          {f.label}
        </button>
      ))}
    </div>
  );
}
