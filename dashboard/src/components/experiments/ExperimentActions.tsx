interface ExperimentActionsProps {
  status: string;
  onStart: () => void;
  onPause: () => void;
  onResume: () => void;
  onConclude: () => void;
}

export function ExperimentActions({ status, onStart, onPause, onResume, onConclude }: ExperimentActionsProps) {
  return (
    <div className="flex items-center gap-2">
      {status === 'draft' && (
        <button
          onClick={onStart}
          className="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-lg hover:bg-emerald-700 transition-colors shadow-sm"
        >
          Launch Experiment
        </button>
      )}

      {status === 'running' && (
        <>
          <button
            onClick={onPause}
            className="px-4 py-2 text-sm font-medium text-amber-700 bg-amber-100 rounded-lg hover:bg-amber-200 transition-colors"
          >
            Pause
          </button>
          <button
            onClick={onConclude}
            className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 transition-colors shadow-sm"
          >
            Conclude
          </button>
        </>
      )}

      {status === 'paused' && (
        <>
          <button
            onClick={onResume}
            className="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-lg hover:bg-emerald-700 transition-colors shadow-sm"
          >
            Resume
          </button>
          <button
            onClick={onConclude}
            className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 transition-colors shadow-sm"
          >
            Conclude
          </button>
        </>
      )}
    </div>
  );
}
