export type ReportReason =
  | "INAPPROPRIATE_BEHAVIOR"
  | "HARASSMENT_OR_HATE"
  | "SPAM_OR_SCAM"
  | "OTHER";

/** Submissions are private; clients never learn a moderation decision for others. */
export type SafetySubmission = {
  id: string;
  status: "RECEIVED";
};
