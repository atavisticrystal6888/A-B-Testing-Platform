import { useState, useEffect } from 'react';
import { TimelineChart } from '../components/charts/TimelineChart';

function fetchTimeline(featureTag: string) {
  const params = featureTag ? `?feature_tag=${encodeURIComponent(featureTag)}` : '';

  return fetch(`/api/v1/analytics/timeline${params}`)
    .then((response) => response.json())
    .then((data) => data.data || []);
}

interface TimelineExperiment {
  id: string;
  name: string;
  status: string;
  started_at: string;
  ended_at?: string;
  feature_tag: string;
}

export function ExperimentTimelinePage() {
  const [experiments, setExperiments] = useState<TimelineExperiment[]>([]);
  const [featureTag, setFeatureTag] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const loadTimeline = () => {
    setIsLoading(true);
    fetchTimeline(featureTag)
      .then((data) => setExperiments(data))
      .catch(() => {})
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    setIsLoading(true);
    fetchTimeline('')
      .then((data) => setExperiments(data))
      .catch(() => {})
      .finally(() => setIsLoading(false));
  }, []);

  return (
    <div className="max-w-6xl mx-auto py-8 px-4">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Experiment Timeline</h1>

      <div className="flex gap-3 mb-6">
        <input
          type="text"
          value={featureTag}
          onChange={(e) => setFeatureTag(e.target.value)}
          placeholder="Filter by feature tag..."
          className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
        />
        <button
          onClick={loadTimeline}
          className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700"
        >
          Search
        </button>
      </div>

      {isLoading ? (
        <div className="text-center py-12 text-gray-500">Loading timeline...</div>
      ) : experiments.length === 0 ? (
        <div className="text-center py-12 text-gray-500">No experiments found for this feature tag.</div>
      ) : (
        <TimelineChart experiments={experiments} />
      )}
    </div>
  );
}
