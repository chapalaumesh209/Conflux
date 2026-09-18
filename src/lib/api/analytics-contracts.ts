export type ProductEventType =
  | "PROFILE_COMPLETED"
  | "PROFILE_UPDATED"
  | "RECOMMENDATION_IMPRESSION"
  | "PROFILE_OPENED"
  | "MEET_STARTED"
  | "MEET_COMPLETED"
  | "CONNECT_CLICKED"
  | "NEXT_CLICKED"
  | "MUTUAL_MATCH"
  | "MESSAGE_SENT"
  | "BUILD_ROOM_CREATED"
  | "BUILD_ROOM_ACTIVE"
  | "SUBSCRIPTION_STARTED";

export type ProductEventInput = {
  type: ProductEventType;
  sourceSurface: string;
  payload: Record<string, string>;
};
