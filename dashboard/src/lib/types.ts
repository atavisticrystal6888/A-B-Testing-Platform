/** TypeScript types matching Management API response schemas */

export interface Tenant {
  id: string;
  name: string;
  slug: string;
  settings: Record<string, unknown>;
}

export interface User {
  id: string;
  email: string;
  role: "viewer" | "editor" | "admin";
  tenant_id: string;
}

export interface AuthTokens {
  access_token: string;
  token_type?: string;
  refresh_token?: string;
  expires_in?: number;
}

export interface Variant {
  id: string;
  key: string;
  name: string;
  description?: string;
  is_control: boolean;
  traffic_allocation: number;
  sort_order: number;
}

export type ExperimentStatus = "draft" | "running" | "paused" | "concluded";
export type ConclusionDecision = "ship_variant" | "revert_to_control" | "inconclusive";

export interface ExperimentMetricSummary {
  id: string;
  key?: string;
  name?: string;
  metric_type?: "count" | "ratio" | "sum" | "funnel";
  role: "primary" | "secondary" | "guardrail";
  guardrail_threshold?: number;
  guardrail_direction?: "above" | "below";
}

export interface ExperimentSummary {
  id: string;
  key: string;
  name: string;
  status: ExperimentStatus;
  feature_tag?: string;
  variant_count: number;
  started_at?: string;
  inserted_at: string;
}

export interface Experiment {
  id: string;
  key: string;
  name: string;
  hypothesis: string;
  description?: string;
  feature_tag?: string;
  status: ExperimentStatus;
  conclusion_decision?: ConclusionDecision;
  conclusion_rationale?: string;
  experiment_group_id?: string;
  scheduled_start_at?: string;
  scheduled_end_at?: string;
  started_at?: string;
  concluded_at?: string;
  version: number;
  archived: boolean;
  variants: Variant[];
  metrics?: ExperimentMetricSummary[];
  inserted_at: string;
  updated_at: string;
}

export interface ExperimentListResponse {
  data: ExperimentSummary[];
  meta: {
    page: number;
    page_size: number;
    total: number;
    total_pages: number;
  };
}

export interface MetricDefinition {
  id: string;
  key: string;
  name: string;
  description?: string;
  metric_type: "count" | "ratio" | "sum" | "funnel";
  definition: Record<string, unknown>;
}

export interface ExperimentMetric {
  id: string;
  experiment_id: string;
  metric_definition_id: string;
  metric_definition: MetricDefinition;
  role: "primary" | "secondary" | "guardrail";
  guardrail_threshold?: number;
  guardrail_direction?: "above" | "below";
}

export interface ConfidenceInterval {
  lower: number;
  upper: number;
  point_estimate: number;
}

export interface EffectSize {
  absolute: number;
  relative: number;
  cohens_h?: number;
}

export interface FrequentistResult {
  test_method: string;
  p_value: number;
  adjusted_p_value?: number;
  correction_method?: string;
  confidence_level: number;
  confidence_interval: ConfidenceInterval;
  effect_size: EffectSize;
  power_achieved: number;
  is_significant: boolean;
}

export interface SequentialResult {
  spending_function: string;
  information_fraction: number;
  nominal_alpha: number;
  adjusted_critical_value: number;
  observed_z_statistic: number;
  can_reject: boolean;
}

export interface SampleSizeCalc {
  minimum_required: number;
  current_total: number;
  is_sufficient: boolean;
  baseline_rate?: number;
  minimum_detectable_effect?: number;
  power: number;
  significance_level: number;
}

export interface Recommendation {
  action: string;
  winning_variant?: string;
  confidence?: string;
  message: string;
}

export interface VariantStats {
  variant_key: string;
  sample_size: number;
  conversions?: number;
  conversion_rate?: number;
  mean?: number;
  std_dev?: number;
}

export interface MetricResult {
  metric_key: string;
  metric_type?: string;
  role: string;
  variants?: VariantStats[];
  frequentist?: FrequentistResult;
  sequential?: SequentialResult;
  sample_size_calculation?: SampleSizeCalc;
  recommendation?: Recommendation;
  guardrail_status?: {
    threshold: number;
    direction: string;
    current_value: number;
    is_breached: boolean;
  };
}

export interface AnalysisResults {
  experiment_id: string;
  computed_at: string;
  computation_time_ms: number;
  metrics: MetricResult[];
  overall_status: string;
  has_sufficient_data: boolean;
  guardrail_breaches: string[];
}

export interface AssignmentResult {
  experiment_key: string;
  variant_key: string;
  variant_name: string;
  experiment_id: string;
  variant_id: string;
  is_control: boolean;
  enrolled: boolean;
  assigned_at: string;
  reason?: string;
}
