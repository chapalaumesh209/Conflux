export type BuildRoomStatus = "ACTIVE" | "ARCHIVED";
export type BuildRoomGoalStatus = "OPEN" | "COMPLETED";

export type BuildRoom = {
  id: string;
  connectionId: string | null;
  name: string;
  objective: string;
  status: BuildRoomStatus;
  visibility: "PUBLIC" | "CONNECTIONS" | "PRIVATE";
  stage: "IDEA" | "PLANNING" | "BUILDING" | "BETA" | "LIVE" | "PAUSED" | "COMPLETED";
};

/** The server keeps ownership free and gates active collaboration in other rooms. */
export type BuildRoomAccess = {
  allowed: boolean;
  reason: string;
};
