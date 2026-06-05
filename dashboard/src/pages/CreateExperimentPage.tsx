import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCreateExperiment } from '../hooks/useExperiments';
import { TargetingRuleBuilder } from '../components/experiments/TargetingRuleBuilder';
import { ScheduleForm } from '../components/experiments/ScheduleForm';
import { MutualExclusionGroupSelect } from '../components/experiments/MutualExclusionGroupSelect';
import { ApiError } from '../lib/api';

interface Variant {
  key: string;
  name: string;
  is_control: boolean;
  traffic_allocation: number;
}

interface TargetingRule {
  attribute: string;
  operator: string;
  value: string;
}

type FieldErrors = Record<string, string>;

const steps = ['Hypothesis', 'Variants', 'Traffic', 'Settings'];
const keyPattern = /^[a-z0-9][a-z0-9_-]*[a-z0-9]$|^[a-z0-9]$/;

function slugifyExperimentKey(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 100);
}

function normalizeErrorMessages(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.filter((message): message is string => typeof message === 'string');
  }

  if (typeof value === 'string') {
    return [value];
  }

  return [];
}

function parseApiValidationErrors(error: ApiError): {
  formError: string | null;
  fieldErrors: Record<string, string[]>;
} {
  const body = error.body;

  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { formError: error.message, fieldErrors: {} };
  }

  const bodyRecord = body as Record<string, unknown>;
  const rawErrors = bodyRecord.errors;
  const fieldErrors: Record<string, string[]> = {};

  if (rawErrors && typeof rawErrors === 'object' && !Array.isArray(rawErrors)) {
    for (const [field, value] of Object.entries(rawErrors)) {
      const messages = normalizeErrorMessages(value);

      if (messages.length > 0) {
        fieldErrors[field] = messages;
      }
    }
  }

  return {
    formError: typeof bodyRecord.message === 'string' ? bodyRecord.message : error.message,
    fieldErrors,
  };
}

function getFieldStep(field: string): number {
  if (field === 'variants' || field.startsWith('variants.')) {
    return 2;
  }

  if (field === 'traffic') {
    return 3;
  }

  if (
    field === 'scheduled_start_at' ||
    field === 'scheduled_end_at' ||
    field === 'targeting_rules' ||
    field === 'experiment_group_id'
  ) {
    return 4;
  }

  return 1;
}

function firstInvalidStep(errors: FieldErrors): number {
  const stepsWithErrors = Object.keys(errors).map(getFieldStep);

  return stepsWithErrors.length > 0 ? Math.min(...stepsWithErrors) : 1;
}

function formatErrorLabel(field: string): string {
  const labels: Record<string, string> = {
    name: 'Experiment name',
    key: 'Experiment key',
    feature_tag: 'Feature tag',
    hypothesis: 'Hypothesis',
    variants: 'Variants',
    traffic: 'Traffic allocation',
    scheduled_start_at: 'Start date',
    scheduled_end_at: 'End date',
    targeting_rules: 'Targeting rules',
    experiment_group_id: 'Mutual exclusion group',
  };

  const variantMatch = field.match(/^variants\.(\d+)\.(key|name|traffic_allocation)$/);

  if (variantMatch) {
    const variantIndex = Number.parseInt(variantMatch[1], 10) + 1;
    const variantFieldLabels: Record<string, string> = {
      key: 'key',
      name: 'name',
      traffic_allocation: 'traffic',
    };

    return `Variant ${variantIndex} ${variantFieldLabels[variantMatch[2]]}`;
  }

  return labels[field] ?? field.replace(/_/g, ' ');
}

function collectValidationErrors({
  name,
  key,
  featureTag,
  variants,
  targetingRules,
  scheduledStartAt,
  scheduledEndAt,
}: {
  name: string;
  key: string;
  featureTag: string;
  variants: Variant[];
  targetingRules: TargetingRule[];
  scheduledStartAt: string;
  scheduledEndAt: string;
}): FieldErrors {
  const errors: FieldErrors = {};

  if (!name.trim()) {
    errors.name = 'Experiment name is required.';
  }

  if (!key.trim()) {
    errors.key = 'Experiment key is required.';
  } else if (!keyPattern.test(key.trim())) {
    errors.key = 'Experiment key must be lowercase and URL-safe.';
  }

  if (featureTag.trim().length > 100) {
    errors.feature_tag = 'Feature tag must be 100 characters or fewer.';
  }

  if (variants.length < 2) {
    errors.variants = 'Add at least a control and one treatment variant.';
  }

  if (variants.filter((variant) => variant.is_control).length !== 1) {
    errors.variants = 'Exactly one variant must be marked as the control.';
  }

  const variantKeys = new Set<string>();

  variants.forEach((variant, index) => {
    const trimmedKey = variant.key.trim();
    const trimmedName = variant.name.trim();

    if (!trimmedKey) {
      errors[`variants.${index}.key`] = 'Variant key is required.';
    } else if (!keyPattern.test(trimmedKey)) {
      errors[`variants.${index}.key`] = 'Variant key must be lowercase and URL-safe.';
    } else if (variantKeys.has(trimmedKey)) {
      errors[`variants.${index}.key`] = 'Variant keys must be unique.';
    } else {
      variantKeys.add(trimmedKey);
    }

    if (!trimmedName) {
      errors[`variants.${index}.name`] = 'Variant name is required.';
    }

    if (variant.traffic_allocation < 0 || variant.traffic_allocation > 10_000) {
      errors[`variants.${index}.traffic_allocation`] = 'Traffic must stay between 0% and 100%.';
    }
  });

  const totalTraffic = variants.reduce((sum, variant) => sum + variant.traffic_allocation, 0);

  if (totalTraffic !== 10_000) {
    errors.traffic = 'Traffic allocation must total 100%.';
  }

  if (
    targetingRules.some(
      (rule) => !rule.attribute.trim() || !rule.operator.trim() || !rule.value.trim(),
    )
  ) {
    errors.targeting_rules = 'Complete or remove every targeting rule before submitting.';
  }

  const parsedStartAt = scheduledStartAt ? Date.parse(scheduledStartAt) : Number.NaN;
  const parsedEndAt = scheduledEndAt ? Date.parse(scheduledEndAt) : Number.NaN;

  if (scheduledStartAt && Number.isNaN(parsedStartAt)) {
    errors.scheduled_start_at = 'Start date is invalid.';
  }

  if (scheduledEndAt && Number.isNaN(parsedEndAt)) {
    errors.scheduled_end_at = 'End date is invalid.';
  }

  if (!Number.isNaN(parsedStartAt) && !Number.isNaN(parsedEndAt) && parsedEndAt <= parsedStartAt) {
    errors.scheduled_end_at = 'End date must be after the start date.';
  }

  return errors;
}

export function CreateExperimentPage() {
  const navigate = useNavigate();
  const createExperiment = useCreateExperiment();

  const [step, setStep] = useState(1);
  const [name, setName] = useState('');
  const [key, setKey] = useState('');
  const [isKeyDirty, setIsKeyDirty] = useState(false);
  const [hypothesis, setHypothesis] = useState('');
  const [featureTag, setFeatureTag] = useState('');
  const [variants, setVariants] = useState<Variant[]>([
    { key: 'control', name: 'Control', is_control: true, traffic_allocation: 5000 },
    { key: 'treatment', name: 'Treatment', is_control: false, traffic_allocation: 5000 },
  ]);
  const [targetingRules, setTargetingRules] = useState<TargetingRule[]>([]);
  const [scheduledStartAt, setScheduledStartAt] = useState('');
  const [scheduledEndAt, setScheduledEndAt] = useState('');
  const [selectedGroupId, setSelectedGroupId] = useState<string | undefined>();
  const [validationErrors, setValidationErrors] = useState<FieldErrors>({});
  const [serverFieldErrors, setServerFieldErrors] = useState<Record<string, string[]>>({});
  const [submissionError, setSubmissionError] = useState<string | null>(null);

  useEffect(() => {
    if (!isKeyDirty) {
      setKey(slugifyExperimentKey(name));
    }
  }, [isKeyDirty, name]);

  const totalTraffic = variants.reduce((sum, v) => sum + v.traffic_allocation, 0);

  const allValidationErrors = collectValidationErrors({
    name,
    key,
    featureTag,
    variants,
    targetingRules,
    scheduledStartAt,
    scheduledEndAt,
  });

  const currentStepErrors = Object.fromEntries(
    Object.entries(allValidationErrors).filter(([field]) => getFieldStep(field) === step),
  );

  const combinedFieldError = (field: string) => validationErrors[field] ?? serverFieldErrors[field]?.[0];

  const summaryEntries = [
    ...Object.entries(validationErrors),
    ...Object.entries(serverFieldErrors)
      .filter(([field]) => !(field in validationErrors))
      .map(([field, messages]) => [field, messages[0]] as const),
  ];

  const resetSubmissionState = () => {
    if (Object.keys(serverFieldErrors).length > 0) {
      setServerFieldErrors({});
    }

    if (submissionError) {
      setSubmissionError(null);
    }
  };

  const handleNextStep = (nextStep: number) => {
    resetSubmissionState();

    if (Object.keys(currentStepErrors).length > 0) {
      setValidationErrors(currentStepErrors);
      return;
    }

    setValidationErrors({});
    setStep(nextStep);
  };

  const handleSubmit = () => {
    resetSubmissionState();

    if (Object.keys(allValidationErrors).length > 0) {
      setValidationErrors(allValidationErrors);
      setStep(firstInvalidStep(allValidationErrors));
      return;
    }

    createExperiment.mutate(
      {
        name: name.trim(),
        key: key.trim(),
        hypothesis: hypothesis.trim() || undefined,
        feature_tag: featureTag.trim() || undefined,
        experiment_group_id: selectedGroupId,
        variants: variants.map((variant, index) => ({
          ...variant,
          key: variant.key.trim(),
          name: variant.name.trim(),
          sort_order: index,
        })),
        targeting_rules:
          targetingRules.length > 0
            ? targetingRules.map((rule) => ({
                attribute: rule.attribute.trim(),
                operator: rule.operator,
                value: rule.value.trim(),
              }))
            : undefined,
        scheduled_start_at: scheduledStartAt || undefined,
        scheduled_end_at: scheduledEndAt || undefined,
      },
      {
        onSuccess: (experiment) => {
          setValidationErrors({});
          navigate(`/experiments/${experiment.id}`);
        },
        onError: (error) => {
          if (error instanceof ApiError) {
            const parsed = parseApiValidationErrors(error);
            const flattenedFieldErrors = Object.fromEntries(
              Object.entries(parsed.fieldErrors).map(([field, messages]) => [field, messages[0]]),
            );

            setServerFieldErrors(parsed.fieldErrors);
            setSubmissionError(parsed.formError);

            if (Object.keys(flattenedFieldErrors).length > 0) {
              setStep(firstInvalidStep(flattenedFieldErrors));
            }

            return;
          }

          setSubmissionError(error instanceof Error ? error.message : 'Failed to create experiment.');
        },
      }
    );
  };

  return (
    <div className="max-w-3xl mx-auto py-8 px-4">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Create Experiment</h1>

      {(submissionError || summaryEntries.length > 0) && (
        <div className="mb-6 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {submissionError && <p className="font-medium">{submissionError}</p>}
          {summaryEntries.length > 0 && (
            <ul className="mt-2 space-y-1">
              {summaryEntries.map(([field, message]) => (
                <li key={`${field}-${message}`}>
                  {formatErrorLabel(field)}: {message}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* Step indicator */}
      <div className="flex items-center mb-8">
        {steps.map((s, i) => (
          <div key={s} className="flex items-center">
            <button
              onClick={() => {
                if (i + 1 <= step) {
                  setStep(i + 1);
                  setValidationErrors({});
                }
              }}
              className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium transition-colors ${
                step === i + 1
                  ? 'bg-indigo-600 text-white'
                  : step > i + 1
                  ? 'bg-indigo-100 text-indigo-600'
                  : 'bg-gray-100 text-gray-400'
              }`}
            >
              {i + 1}
            </button>
            <span className="ml-2 text-sm text-gray-600">{s}</span>
            {i < steps.length - 1 && <div className="w-12 h-0.5 bg-gray-200 mx-3" />}
          </div>
        ))}
      </div>

      {/* Step 1: Hypothesis */}
      {step === 1 && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Experiment Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                resetSubmissionState();
              }}
              className={`w-full px-3 py-2 border rounded-lg text-sm ${combinedFieldError('name') ? 'border-red-300 bg-red-50' : 'border-gray-300'}`}
              placeholder="Checkout Button Color"
            />
            {combinedFieldError('name') && <p className="mt-1 text-xs text-red-600">{combinedFieldError('name')}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Key</label>
            <input
              type="text"
              value={key}
              onChange={(e) => {
                setKey(e.target.value);
                setIsKeyDirty(true);
                resetSubmissionState();
              }}
              className={`w-full px-3 py-2 border rounded-lg text-sm font-mono ${combinedFieldError('key') ? 'border-red-300 bg-red-50' : 'border-gray-300'}`}
              placeholder="checkout-button-color"
            />
            {combinedFieldError('key') ? (
              <p className="mt-1 text-xs text-red-600">{combinedFieldError('key')}</p>
            ) : (
              <p className="mt-1 text-xs text-gray-400">Lowercase letters, numbers, hyphens, and underscores only.</p>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Hypothesis</label>
            <textarea
              value={hypothesis}
              onChange={(e) => {
                setHypothesis(e.target.value);
                resetSubmissionState();
              }}
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              placeholder="Changing the button color to green will increase conversions by 5%..."
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Feature Tag</label>
            <input
              type="text"
              value={featureTag}
              onChange={(e) => {
                setFeatureTag(e.target.value);
                resetSubmissionState();
              }}
              className={`w-full px-3 py-2 border rounded-lg text-sm ${combinedFieldError('feature_tag') ? 'border-red-300 bg-red-50' : 'border-gray-300'}`}
              placeholder="checkout-page"
            />
            {combinedFieldError('feature_tag') && (
              <p className="mt-1 text-xs text-red-600">{combinedFieldError('feature_tag')}</p>
            )}
          </div>
          <button
            onClick={() => handleNextStep(2)}
            className="px-6 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700"
          >
            Next
          </button>
        </div>
      )}

      {/* Step 2: Variants */}
      {step === 2 && (
        <div className="space-y-4">
          {combinedFieldError('variants') && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {combinedFieldError('variants')}
            </div>
          )}
          {variants.map((v, i) => (
            <div key={i} className="p-4 border border-gray-200 rounded-lg space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-700">Variant {i + 1} {v.is_control && '(Control)'}</span>
                {!v.is_control && variants.length > 2 && (
                  <button
                    onClick={() => {
                      setVariants(variants.filter((_, j) => j !== i));
                      resetSubmissionState();
                    }}
                    className="text-xs text-red-500"
                  >
                    Remove
                  </button>
                )}
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <input
                    type="text"
                    value={v.key}
                    onChange={(e) => {
                      const nextVariants = [...variants];
                      nextVariants[i] = { ...v, key: e.target.value };
                      setVariants(nextVariants);
                      resetSubmissionState();
                    }}
                    placeholder="Key"
                    className={`w-full px-3 py-2 border rounded-lg text-sm ${combinedFieldError(`variants.${i}.key`) ? 'border-red-300 bg-red-50' : 'border-gray-300'}`}
                  />
                  {combinedFieldError(`variants.${i}.key`) && (
                    <p className="mt-1 text-xs text-red-600">{combinedFieldError(`variants.${i}.key`)}</p>
                  )}
                </div>
                <div>
                  <input
                    type="text"
                    value={v.name}
                    onChange={(e) => {
                      const nextVariants = [...variants];
                      nextVariants[i] = { ...v, name: e.target.value };
                      setVariants(nextVariants);
                      resetSubmissionState();
                    }}
                    placeholder="Name"
                    className={`w-full px-3 py-2 border rounded-lg text-sm ${combinedFieldError(`variants.${i}.name`) ? 'border-red-300 bg-red-50' : 'border-gray-300'}`}
                  />
                  {combinedFieldError(`variants.${i}.name`) && (
                    <p className="mt-1 text-xs text-red-600">{combinedFieldError(`variants.${i}.name`)}</p>
                  )}
                </div>
              </div>
            </div>
          ))}
          <button
            onClick={() => {
              setVariants([...variants, { key: '', name: '', is_control: false, traffic_allocation: 0 }]);
              resetSubmissionState();
            }}
            className="text-sm text-indigo-600 hover:text-indigo-700"
          >
            + Add Variant
          </button>
          <div className="flex gap-3">
            <button
              onClick={() => {
                setStep(1);
                setValidationErrors({});
              }}
              className="px-6 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg"
            >
              Back
            </button>
            <button
              onClick={() => handleNextStep(3)}
              className="px-6 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {/* Step 3: Traffic */}
      {step === 3 && (
        <div className="space-y-4">
          {variants.map((v, i) => (
            <div key={i} className="flex items-center gap-4">
              <span className="w-32 text-sm text-gray-700">{v.name || v.key}</span>
              <input
                type="range"
                min={0}
                max={10000}
                step={100}
                value={v.traffic_allocation}
                onChange={(e) => {
                  const nextVariants = [...variants];
                  nextVariants[i] = { ...v, traffic_allocation: Number.parseInt(e.target.value, 10) };
                  setVariants(nextVariants);
                  resetSubmissionState();
                }}
                className="flex-1"
              />
              <span className="w-16 text-sm font-mono text-right">{(v.traffic_allocation / 100).toFixed(0)}%</span>
            </div>
          ))}
          <p className={`text-sm ${combinedFieldError('traffic') ? 'text-red-600' : 'text-emerald-600'}`}>
            Total: {(totalTraffic / 100).toFixed(0)}% {combinedFieldError('traffic') ? '(must be 100%)' : ''}
          </p>
          {combinedFieldError('traffic') && <p className="text-xs text-red-600">{combinedFieldError('traffic')}</p>}
          <div className="flex gap-3">
            <button
              onClick={() => {
                setStep(2);
                setValidationErrors({});
              }}
              className="px-6 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg"
            >
              Back
            </button>
            <button
              onClick={() => handleNextStep(4)}
              className="px-6 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {/* Step 4: Settings */}
      {step === 4 && (
        <div className="space-y-6">
          <ScheduleForm
            scheduledStartAt={scheduledStartAt}
            scheduledEndAt={scheduledEndAt}
            onChange={(field, value) => {
              if (field === 'scheduled_start_at') {
                setScheduledStartAt(value);
              } else {
                setScheduledEndAt(value);
              }

              resetSubmissionState();
            }}
          />
          {(combinedFieldError('scheduled_start_at') || combinedFieldError('scheduled_end_at')) && (
            <div className="-mt-3 text-xs text-red-600">
              {combinedFieldError('scheduled_start_at') || combinedFieldError('scheduled_end_at')}
            </div>
          )}
          <TargetingRuleBuilder
            rules={targetingRules}
            onChange={(rules) => {
              setTargetingRules(rules);
              resetSubmissionState();
            }}
          />
          {combinedFieldError('targeting_rules') && (
            <p className="-mt-3 text-xs text-red-600">{combinedFieldError('targeting_rules')}</p>
          )}
          <MutualExclusionGroupSelect
            selectedGroupId={selectedGroupId}
            onChange={(groupId) => {
              setSelectedGroupId(groupId);
              resetSubmissionState();
            }}
          />
          {combinedFieldError('experiment_group_id') && (
            <p className="-mt-3 text-xs text-red-600">{combinedFieldError('experiment_group_id')}</p>
          )}
          <div className="flex gap-3">
            <button
              onClick={() => {
                setStep(3);
                setValidationErrors({});
              }}
              className="px-6 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg"
            >
              Back
            </button>
            <button onClick={handleSubmit} disabled={createExperiment.isPending} className="px-6 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50">
              {createExperiment.isPending ? 'Creating...' : 'Create Experiment'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
