import type { Transport } from "./transport";
import type {
  AssignBatchInput,
  AssignInput,
  Assignment,
  BatchAssignment,
  BatchAssignmentError,
  BatchAssignmentItem,
  RequestOptions,
} from "./types";

interface WireAssignment {
  experiment_key: string;
  experiment_id: string;
  variant_key: string;
  variant_id: string;
  variant_name: string;
  is_control: boolean;
  enrolled: boolean;
  assigned_at: string;
}

type WireBatchItem =
  | {
      experiment_key: string;
      experiment_id: string;
      variant_key: string;
      variant_id: string;
      is_control: boolean;
      enrolled: boolean;
    }
  | { experiment_key: string; error: string };

interface WireBatchAssignment {
  user_id: string;
  assigned_at: string;
  assignments: WireBatchItem[];
}

function fromWireAssignment(raw: WireAssignment): Assignment {
  return {
    experimentKey: raw.experiment_key,
    experimentId: raw.experiment_id,
    variantKey: raw.variant_key,
    variantId: raw.variant_id,
    variantName: raw.variant_name,
    isControl: raw.is_control,
    enrolled: raw.enrolled,
    assignedAt: raw.assigned_at,
  };
}

function fromWireBatchItem(raw: WireBatchItem): BatchAssignmentItem | BatchAssignmentError {
  if ("error" in raw) {
    return { experimentKey: raw.experiment_key, error: raw.error };
  }
  return {
    experimentKey: raw.experiment_key,
    experimentId: raw.experiment_id,
    variantKey: raw.variant_key,
    variantId: raw.variant_id,
    isControl: raw.is_control,
    enrolled: raw.enrolled,
  };
}

export function createAssignMethods(transport: Transport) {
  return {
    async assign(input: AssignInput, options?: RequestOptions): Promise<Assignment> {
      const raw = await transport.post<WireAssignment>(
        "/v1/assign",
        { user_id: input.userId, experiment_key: input.experimentKey, attributes: input.attributes ?? {} },
        options,
      );
      return fromWireAssignment(raw);
    },

    async assignBatch(input: AssignBatchInput, options?: RequestOptions): Promise<BatchAssignment> {
      const raw = await transport.post<WireBatchAssignment>(
        "/v1/assign/batch",
        { user_id: input.userId, experiment_keys: input.experimentKeys, attributes: input.attributes ?? {} },
        options,
      );
      return {
        userId: raw.user_id,
        assignedAt: raw.assigned_at,
        assignments: raw.assignments.map(fromWireBatchItem),
      };
    },
  };
}
