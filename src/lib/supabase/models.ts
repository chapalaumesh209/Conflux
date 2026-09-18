export type Profile = {
  id: string;
  username: string;
  full_name: string;
  headline: string | null;
  bio: string | null;
  city: string | null;
  experience_band: string | null;
  skills: string[];
  domains: string[];
  goals: string[];
  current_build: string | null;
  looking_for: string | null;
  can_offer: string | null;
  avatar_url: string | null;
  is_discoverable: boolean;
  onboarding_complete: boolean;
  email_verified: boolean;
  github_verified: boolean;
  linkedin_verified: boolean;
  created_at: string;
  updated_at: string;
};

export type Candidate = Pick<Profile,
  "id" | "username" | "full_name" | "headline" | "city" | "experience_band" | "skills" | "domains" | "goals" | "current_build" | "looking_for" | "avatar_url" | "email_verified" | "github_verified" | "linkedin_verified"
> & { match_reason: string | null };

export type Connection = {
  id: string;
  low_profile_id: string;
  high_profile_id: string;
  created_at: string;
  conversation_id?: string;
  other?: Profile;
};

export type Message = {
  id: string;
  connection_id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  client_message_id: string | null;
  created_at: string;
};

export type Project = {
  id: string;
  owner_id: string;
  slug: string;
  name: string;
  idea: string;
  summary: string | null;
  problem: string | null;
  goals: string | null;
  stage: "IDEA" | "PLANNING" | "BUILDING" | "BETA" | "LIVE" | "PAUSED" | "COMPLETED";
  is_public: boolean;
  collaboration_enabled: boolean;
  live_url: string | null;
  repository_url: string | null;
  created_at: string;
  updated_at: string;
};

export type ProjectTask = {
  id: string;
  project_id: string;
  title: string;
  status: "BACKLOG" | "TODO" | "IN_PROGRESS" | "BLOCKED" | "DONE" | "CANCELLED";
  priority: "LOW" | "MEDIUM" | "HIGH";
  due_at: string | null;
  created_at: string;
};
