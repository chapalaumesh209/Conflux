export type PlanCode = "FREE" | "PRO";
export type FeatureCode =
  | "ADVANCED_DISCOVERY"
  | "SAVED_SEARCHES"
  | "EXTENDED_MEET"
  | "BUILD_ROOM_CREATION"
  | "SCREEN_SHARE"
  | "RELATIONSHIP_MEMORY";

/** Final access comes from a verified server entitlement, never a checkout UI. */
export type Entitlements = {
  plan: PlanCode;
  features: FeatureCode[];
};
