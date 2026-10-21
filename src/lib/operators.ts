type OperatorInfo = {
  /** Short label for tables and page titles. */
  label: string;
  tooltip: string;
  /** How to name the operator mid-sentence, e.g. in search descriptions. */
  inSentence: string;
};

/** Keyed by the part of routes.operator before the colon, e.g. "LagFerry/Government". */
const OPERATORS: Record<string, OperatorInfo> = {
  "LagFerry/Government": {
    label: "LagFerry",
    tooltip: "Operated by the government",
    inSentence: "LagFerry, the Lagos State Government service",
  },
  "Formal Commercial": {
    label: "Licensed Commercial",
    tooltip: "Licensed commercial operators under the jurisdiction/licensed by LASWA or NIWA",
    inSentence: "licensed commercial operators",
  },
  "Informal Commercial": {
    label: "Unlicensed Commercial",
    tooltip: "Unlicensed commercial operators not under the jurisdiction/licensed by LASWA or NIWA",
    inSentence: "unlicensed commercial operators",
  },
};

/**
 * Display info for a routes.operator value. Matches on the prefix only, so small
 * wording changes after the colon (spacing, punctuation) don't break the lookup.
 */
export function operatorInfo(operator: string | null): OperatorInfo | null {
  if (!operator) return null;
  return OPERATORS[operator.split(":")[0].trim()] ?? null;
}
