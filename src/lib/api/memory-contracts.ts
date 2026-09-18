export type RelationshipMemory = {
  id: string;
  connectionId: string;
  summary: string;
  sourceKind: "MEET_METADATA" | "CONNECTION_EVENT" | "BUILD_ROOM_GOAL" | "BUILD_ROOM_NOTE";
  updatedAt: string;
};

export type NextStepSuggestion = {
  type: "GOAL" | "REVIEW" | "FOLLOW_UP" | "CHECK_IN";
  text: string;
};
