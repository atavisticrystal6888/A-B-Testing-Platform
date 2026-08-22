import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../../lib/api";

interface SegmentVariantRow {
  variant_key: string;
  sample_size: number;
  conversions: number;
  conversion_rate: number | null;
}

interface SegmentRow {
  segment: string;
  total_sample_size: number;
  variants: SegmentVariantRow[];
}

interface SegmentResponse {
  data: {
    attribute: string;
    metric_key: string;
    metric_name: string;
    note: string;
    segments: SegmentRow[];
  };
}

const SUGGESTED_ATTRIBUTES = ["country", "device"];

const COHORT_CHIPS: { label: string; attribute: string }[] = [
  { label: "Device", attribute: "device" },
  { label: "Country", attribute: "country" },
  { label: "New vs returning", attribute: "new_vs_returning" },
];

export function SegmentBreakdownCard({ experimentId }: { experimentId: string }) {
  // Kept separate from `attribute` (the active query key) so that clicking a
  // canned cohort chip never clobbers whatever the user typed into the
  // custom field — reopening "Custom…" should still show their own text.
  const [customAttributeInput, setCustomAttributeInput] = useState("country");
  const [attribute, setAttribute] = useState<string | null>(null);
  const [showCustomInput, setShowCustomInput] = useState(false);

  const { data, isFetching, isError } = useQuery<SegmentResponse>({
    queryKey: ["segments", experimentId, attribute],
    queryFn: () =>
      api.get<SegmentResponse>(
        `/api/v1/experiments/${experimentId}/segments?attribute=${encodeURIComponent(attribute!)}`,
      ),
    enabled: !!attribute,
  });

  const segments = data?.data.segments ?? [];
  const variantKeys = segments[0]?.variants.map((v) => v.variant_key) ?? [];

  const chipClass = (isActive: boolean) =>
    `rounded-full border px-3 py-1 text-sm ${
      isActive
        ? "bg-indigo-600 text-white border-indigo-600"
        : "bg-white text-gray-700 border-gray-300 hover:bg-gray-50"
    }`;

  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-sm font-semibold text-gray-900">Segment Breakdown</h3>
            <span className="text-xs text-gray-500 border rounded-full px-2 py-0.5">
              descriptive only — no significance claims
            </span>
          </div>
          <p className="text-xs text-gray-500 mt-0.5">
            Descriptive split by assignment attribute — not significance-tested.
          </p>
        </div>
        <div className="flex flex-col items-end gap-2">
          <div className="flex flex-wrap items-center gap-2">
            {COHORT_CHIPS.map((chip) => (
              <button
                key={chip.attribute}
                type="button"
                onClick={() => {
                  setShowCustomInput(false);
                  setAttribute(chip.attribute);
                }}
                className={chipClass(!showCustomInput && attribute === chip.attribute)}
              >
                {chip.label}
              </button>
            ))}
            <button
              type="button"
              onClick={() => setShowCustomInput(true)}
              className={chipClass(showCustomInput)}
            >
              Custom…
            </button>
          </div>
          {showCustomInput && (
            <form
              className="flex items-center gap-2"
              onSubmit={(event) => {
                event.preventDefault();
                if (customAttributeInput.trim()) setAttribute(customAttributeInput.trim());
              }}
            >
              <input
                type="text"
                value={customAttributeInput}
                onChange={(event) => setCustomAttributeInput(event.target.value)}
                list="segment-attributes"
                placeholder="attribute (e.g. country)"
                className="px-3 py-1.5 border border-gray-300 rounded-lg text-xs w-40"
              />
              <datalist id="segment-attributes">
                {SUGGESTED_ATTRIBUTES.map((suggestion) => (
                  <option key={suggestion} value={suggestion} />
                ))}
              </datalist>
              <button
                type="submit"
                disabled={!customAttributeInput.trim() || isFetching}
                className="px-3 py-1.5 text-xs font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
              >
                {isFetching ? "Loading..." : "Break down"}
              </button>
            </form>
          )}
        </div>
      </div>

      {!attribute ? (
        <div className="px-6 py-6 text-center text-sm text-gray-500">
          Pick an attribute your SDK sends with /v1/assign (e.g. country, device) to see
          per-segment results.
        </div>
      ) : isError ? (
        <div className="px-6 py-6 text-center text-sm text-red-600">
          Couldn't load segments for "{attribute}".
        </div>
      ) : segments.length === 0 ? (
        !isFetching && (
          <div className="px-6 py-6 text-center text-sm text-gray-500">
            No assignments recorded yet, so there's nothing to segment.
          </div>
        )
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">
              Descriptive conversion rate by {data?.data.attribute}, split by variant. Not
              significance-tested.
            </caption>
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th scope="col" className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                  {data?.data.attribute}
                </th>
                {variantKeys.map((key) => (
                  <th
                    key={key}
                    scope="col"
                    className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase"
                  >
                    {key}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {segments.map((segment) => (
                <tr key={segment.segment} className="hover:bg-gray-50/50">
                  <th scope="row" className="px-6 py-3 text-left font-medium text-gray-900">
                    {segment.segment}
                    <span className="ml-2 text-xs font-normal text-gray-400 tabular-nums">
                      n={segment.total_sample_size.toLocaleString()}
                    </span>
                  </th>
                  {segment.variants.map((variant) => (
                    <td key={variant.variant_key} className="px-6 py-3 text-right text-gray-700 tabular-nums">
                      {variant.conversion_rate != null
                        ? `${(variant.conversion_rate * 100).toFixed(1)}%`
                        : "—"}
                      <span className="ml-1 text-xs text-gray-400">
                        ({variant.conversions}/{variant.sample_size})
                      </span>
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
