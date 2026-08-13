import { useEffect, useState } from "react";
import {
  useCreateMetricDefinition,
  useDeleteMetricDefinition,
  useMetricDefinition,
  useUpdateMetricDefinition,
} from "../../hooks/useMetricDefinitions";
import { describeApiError } from "../../lib/api";
import type { MetricDefinition } from "../../lib/types";

type MetricType = MetricDefinition["metric_type"];

type MetricDefinitionPanelProps =
  | { mode: "create"; onClose: () => void }
  | { mode: "edit"; id: string; onClose: () => void };

const METRIC_TYPES: Array<{ value: MetricType; label: string; description: string }> = [
  { value: "count", label: "Count", description: "Counts of a single event (e.g. signups)." },
  { value: "ratio", label: "Ratio", description: "One event count divided by another (e.g. conversion rate)." },
  { value: "sum", label: "Sum", description: "Sum of a numeric field on an event (e.g. revenue)." },
  { value: "funnel", label: "Funnel", description: "Completion of an ordered sequence of events." },
];

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function stepsFromDefinition(definition: Record<string, unknown> | undefined): string[] {
  const steps = definition?.steps;
  if (Array.isArray(steps) && steps.every((step) => typeof step === "string") && steps.length > 0) {
    return steps as string[];
  }
  return [""];
}

export function MetricDefinitionPanel(props: MetricDefinitionPanelProps) {
  const { onClose } = props;
  const isEdit = props.mode === "edit";

  const { data: existing, isLoading: isLoadingExisting } = useMetricDefinition(
    isEdit ? props.id : undefined,
  );

  const [key, setKey] = useState("");
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [metricType, setMetricType] = useState<MetricType>("count");
  const [eventName, setEventName] = useState("");
  const [numerator, setNumerator] = useState("");
  const [denominator, setDenominator] = useState("");
  const [valueField, setValueField] = useState("");
  const [steps, setSteps] = useState<string[]>([""]);
  const [initialized, setInitialized] = useState(!isEdit);

  useEffect(() => {
    if (!existing || initialized) return;

    setKey(existing.key);
    setName(existing.name);
    setDescription(existing.description ?? "");
    setMetricType(existing.metric_type);
    setEventName(asString(existing.definition.event_name));
    setNumerator(asString(existing.definition.numerator));
    setDenominator(asString(existing.definition.denominator));
    setValueField(asString(existing.definition.value_field));
    setSteps(stepsFromDefinition(existing.definition));
    setInitialized(true);
  }, [existing, initialized]);

  const createMutation = useCreateMetricDefinition();
  const updateMutation = useUpdateMetricDefinition();
  const deleteMutation = useDeleteMetricDefinition();

  const saveMutation = isEdit ? updateMutation : createMutation;

  const buildDefinition = (): Record<string, unknown> => {
    const definition: Record<string, unknown> = {};
    if (eventName.trim()) definition.event_name = eventName.trim();

    if (metricType === "ratio") {
      if (numerator.trim()) definition.numerator = numerator.trim();
      if (denominator.trim()) definition.denominator = denominator.trim();
    } else if (metricType === "sum") {
      if (valueField.trim()) definition.value_field = valueField.trim();
    } else if (metricType === "funnel") {
      const cleanSteps = steps.map((step) => step.trim()).filter(Boolean);
      if (cleanSteps.length > 0) definition.steps = cleanSteps;
    }

    return definition;
  };

  const handleSubmit = () => {
    const definition = buildDefinition();

    if (isEdit) {
      updateMutation.mutate(
        { id: props.id, name, description: description || undefined, metric_type: metricType, definition },
        { onSuccess: onClose },
      );
    } else {
      createMutation.mutate(
        { key, name, description: description || undefined, metric_type: metricType, definition },
        { onSuccess: onClose },
      );
    }
  };

  const handleDelete = () => {
    if (!isEdit) return;
    if (!window.confirm(`Delete the "${name}" metric? This can't be undone.`)) return;

    deleteMutation.mutate(props.id, { onSuccess: onClose });
  };

  const canSubmit = key.trim().length > 0 && name.trim().length > 0 && !saveMutation.isPending;
  const showLoadingState = isEdit && (isLoadingExisting || !initialized);

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div
        role="dialog"
        aria-label={isEdit ? "Edit metric definition" : "Create metric definition"}
        className="h-full w-full max-w-md overflow-y-auto bg-white shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-start justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-semibold text-gray-900">
            {isEdit ? "Edit Metric" : "Create Metric"}
          </h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-gray-400 hover:text-gray-600 text-xl leading-none"
          >
            &times;
          </button>
        </div>

        {showLoadingState ? (
          <div className="px-6 py-12 text-center text-sm text-gray-500">Loading metric...</div>
        ) : (
          <div className="px-6 py-5 space-y-5">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Key</label>
                <input
                  type="text"
                  value={key}
                  onChange={(event) => setKey(event.target.value)}
                  disabled={isEdit}
                  placeholder="checkout_conversion"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm disabled:bg-gray-50 disabled:text-gray-500"
                />
                {!isEdit && (
                  <p className="mt-1 text-xs text-gray-400">Lowercase, url-safe. Can't be changed later.</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input
                  type="text"
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  placeholder="Checkout Conversion"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                rows={2}
                placeholder="What this metric measures and why it matters."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
              <select
                value={metricType}
                onChange={(event) => setMetricType(event.target.value as MetricType)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              >
                {METRIC_TYPES.map((type) => (
                  <option key={type.value} value={type.value}>
                    {type.label}
                  </option>
                ))}
              </select>
              <p className="mt-1 text-xs text-gray-400">
                {METRIC_TYPES.find((type) => type.value === metricType)?.description}
              </p>
            </div>

            {metricType !== "funnel" && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Event Name</label>
                <input
                  type="text"
                  value={eventName}
                  onChange={(event) => setEventName(event.target.value)}
                  placeholder="checkout_completed"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                />
              </div>
            )}

            {metricType === "ratio" && (
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Numerator</label>
                  <input
                    type="text"
                    value={numerator}
                    onChange={(event) => setNumerator(event.target.value)}
                    placeholder="conversion"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Denominator</label>
                  <input
                    type="text"
                    value={denominator}
                    onChange={(event) => setDenominator(event.target.value)}
                    placeholder="assignment"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                  />
                </div>
              </div>
            )}

            {metricType === "sum" && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Value Field</label>
                <input
                  type="text"
                  value={valueField}
                  onChange={(event) => setValueField(event.target.value)}
                  placeholder="value"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                />
              </div>
            )}

            {metricType === "funnel" && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Funnel Steps</label>
                {steps.map((step, index) => (
                  <div key={index} className="flex items-center gap-2 mb-2">
                    <span className="text-sm text-gray-500 w-6">{index + 1}.</span>
                    <input
                      type="text"
                      value={step}
                      onChange={(event) => {
                        const next = [...steps];
                        next[index] = event.target.value;
                        setSteps(next);
                      }}
                      placeholder="Event name"
                      className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    />
                    {steps.length > 1 && (
                      <button
                        onClick={() => setSteps(steps.filter((_, i) => i !== index))}
                        aria-label={`Remove step ${index + 1}`}
                        className="p-1.5 text-red-500 hover:text-red-700 rounded"
                      >
                        &times;
                      </button>
                    )}
                  </div>
                ))}
                <button
                  onClick={() => setSteps([...steps, ""])}
                  className="text-sm text-indigo-600 hover:text-indigo-700"
                >
                  + Add Step
                </button>
              </div>
            )}

            {saveMutation.isError && (
              <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                {describeApiError(saveMutation.error, "Unable to save this metric right now.")}
              </p>
            )}

            {deleteMutation.isError && (
              <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                {describeApiError(deleteMutation.error, "Unable to delete this metric right now.")}
              </p>
            )}

            <div className="flex items-center justify-between pt-4 border-t border-gray-100">
              {isEdit ? (
                <button
                  onClick={handleDelete}
                  disabled={deleteMutation.isPending}
                  className="px-4 py-2 text-sm font-medium text-red-600 hover:text-red-700 disabled:opacity-50"
                >
                  {deleteMutation.isPending ? "Deleting..." : "Delete"}
                </button>
              ) : (
                <span />
              )}
              <button
                onClick={handleSubmit}
                disabled={!canSubmit}
                className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saveMutation.isPending ? "Saving..." : isEdit ? "Save Changes" : "Create Metric"}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
