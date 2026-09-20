"use client";

import {
  CSSProperties,
  FormEvent,
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import {
  ArrowLeft,
  ArrowRight,
  Bell,
  Check,
  CircleAlert,
  Compass,
  ExternalLink,
  FileText,
  Flag,
  FolderKanban,
  Github,
  LockKeyhole,
  MessageCircle,
  Plus,
  RefreshCw,
  Search,
  Settings2,
  ShieldBan,
  Sparkles,
  UserRound,
  UsersRound,
  Wrench,
} from "lucide-react";
import { useParams, usePathname, useRouter } from "next/navigation";
import {
  getSupabaseClient,
  isSupabaseConfigured,
} from "../lib/supabase/client";
import type {
  Candidate,
  Connection,
  Message,
  Profile,
  Project,
  ProjectTask,
} from "../lib/supabase/models";

type Session = { user: { id: string; email?: string } };
type Milestone = {
  id: string;
  project_id: string;
  name: string;
  objective: string | null;
  target_at: string | null;
  status: string;
  created_at: string;
};
type ProjectMessage = {
  id: string;
  project_id: string;
  sender_id: string;
  body: string;
  created_at: string;
};
type ProjectNote = {
  id: string;
  project_id: string;
  author_id: string;
  type: string;
  title: string;
  body: string;
  created_at: string;
};
type DiscoverBuilder = Pick<
  Candidate,
  | "id"
  | "username"
  | "full_name"
  | "headline"
  | "experience_band"
  | "skills"
  | "domains"
  | "goals"
  | "current_build"
  | "looking_for"
  | "avatar_url"
  | "email_verified"
  | "github_verified"
  | "linkedin_verified"
> & { match_reasons: string[]; ranker_version: string };
type DiscoverProject = {
  id: string;
  slug: string;
  name: string;
  summary: string | null;
  idea: string;
  stage: Project["stage"];
  goals: string | null;
  collaboration_enabled: boolean;
  showcase_enabled: boolean;
  showcase_pitch: string | null;
  demo_url: string | null;
  owner_id: string;
  owner_username: string;
  owner_full_name: string;
  match_reasons: string[];
  ranker_version: string;
};
type DirectMeetStatus = "ONLINE_AVAILABLE" | "ONLINE" | "IN_MEET" | "OFFLINE";
const DISCOVER_BUILDERS_PAGE_SIZE = 4;
const DISCOVER_PROJECTS_PAGE_SIZE = 3;
const isMissingDiscoverRanker = (message?: string) =>
  Boolean(
    message?.includes("cf_discover_") && message.includes("schema cache"),
  );
const initials = (name: string) =>
  name
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
const date = (value?: string | null) =>
  value
    ? new Intl.DateTimeFormat(undefined, {
        month: "short",
        day: "numeric",
      }).format(new Date(value))
    : "No date";
const uniqueById = <T extends { id: string }>(items: T[]) =>
  Array.from(new Map(items.map((item) => [item.id, item])).values());

function WorkspaceGate({
  children,
}: {
  children: (context: {
    user: Session["user"];
    profile: Profile;
    supabase: ReturnType<typeof getSupabaseClient>;
  }) => ReactNode;
}) {
  const router = useRouter();
  const supabase = useMemo(
    () => (isSupabaseConfigured() ? getSupabaseClient() : null),
    [],
  );
  const [state, setState] = useState<"loading" | "ready" | "missing">(
    "loading",
  );
  const [user, setUser] = useState<Session["user"] | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  useEffect(() => {
    if (!supabase) {
      setState("missing");
      return;
    }
    let active = true;
    void supabase.auth.getSession().then(async ({ data: { session } }) => {
      if (!active) return;
      if (!session) {
        router.replace("/login");
        return;
      }
      const { data } = await supabase
        .from("cf_profiles")
        .select("*")
        .eq("id", session.user.id)
        .maybeSingle();
      if (!active) return;
      if (!(data as Profile | null)?.onboarding_complete) {
        router.replace("/onboarding");
        return;
      }
      setUser(session.user as Session["user"]);
      setProfile(data as Profile);
      setState("ready");
    });
    return () => {
      active = false;
    };
  }, [router, supabase]);
  if (state === "loading")
    return (
      <main className="cf-loading">
        <span className="cf-pulse" />
        Loading your workspace
      </main>
    );
  if (state === "missing")
    return (
      <main className="cf-gate">
        <section>
          <h1>Connect your data first.</h1>
          <p>
            CONFLUX only shows real members and work. Add the public Supabase
            URL and anon key, then redeploy.
          </p>
        </section>
      </main>
    );
  return (
    <>{user && profile && supabase && children({ user, profile, supabase })}</>
  );
}

function Page({
  title,
  description,
  actions,
  children,
}: {
  title: string;
  description: string;
  actions?: ReactNode;
  children: ReactNode;
}) {
  return (
    <main className="v3-page">
      <header className="v3-heading">
        <div>
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
        {actions}
      </header>
      {children}
    </main>
  );
}
function State({
  icon,
  title,
  body,
  action,
}: {
  icon: ReactNode;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <section className="v3-state">
      {icon}
      <h2>{title}</h2>
      <p>{body}</p>
      {action}
    </section>
  );
}
function Notice({ error }: { error: string }) {
  return error ? (
    <div className="v3-notice">
      <CircleAlert size={18} />
      <span>{error}</span>
    </div>
  ) : null;
}
function Person({
  person,
  action,
}: {
  person: Pick<
    Candidate,
    | "username"
    | "full_name"
    | "headline"
    | "skills"
    | "current_build"
    | "email_verified"
  >;
  action?: ReactNode;
}) {
  return (
    <article className="v3-person">
      <span className="cf-avatar large">{initials(person.full_name)}</span>
      <div className="v3-person-copy">
        <h2>
          {person.full_name}
          {person.email_verified && (
            <Check size={16} aria-label="Email verified" />
          )}
        </h2>
        <p>
          @{person.username} · {person.headline || "Builder"}
        </p>
        <div className="v3-tags">
          {person.skills?.slice(0, 4).map((skill) => (
            <span key={skill}>{skill}</span>
          ))}
        </div>
        {person.current_build && (
          <small>Building: {person.current_build}</small>
        )}
      </div>
      {action && <div className="v3-person-action">{action}</div>}
    </article>
  );
}

export function DiscoverPage() {
  return (
    <WorkspaceGate>
      {({ supabase }) => <DiscoverInner supabase={supabase} />}
    </WorkspaceGate>
  );
}
function DiscoverInner({
  supabase,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
}) {
  const router = useRouter();
  const [builders, setBuilders] = useState<DiscoverBuilder[]>([]);
  const [projects, setProjects] = useState<DiscoverProject[]>([]);
  const [builderOffset, setBuilderOffset] = useState(0);
  const [projectOffset, setProjectOffset] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [startingId, setStartingId] = useState<string | null>(null);
  const [meetStatusById, setMeetStatusById] = useState<
    Record<string, DirectMeetStatus>
  >({});
  const [error, setError] = useState("");

  const load = useCallback(
    async (append = false, nextBuilderOffset = 0, nextProjectOffset = 0) => {
      if (append) setLoadingMore(true);
      else setLoading(true);
      setError("");
      const [builderResult, projectResult] = await Promise.all([
        supabase.rpc("cf_discover_builders_v3", {
          result_limit: DISCOVER_BUILDERS_PAGE_SIZE,
          result_offset: nextBuilderOffset,
        }),
        supabase.rpc("cf_discover_projects_v3", {
          result_limit: DISCOVER_PROJECTS_PAGE_SIZE,
          result_offset: nextProjectOffset,
        }),
      ]);
      if (append) setLoadingMore(false);
      else setLoading(false);
      if (builderResult.error || projectResult.error) {
        if (
          isMissingDiscoverRanker(builderResult.error?.message) &&
          isMissingDiscoverRanker(projectResult.error?.message)
        ) {
          const { data: legacyData, error: legacyError } = await supabase.rpc(
            "cf_discover_profiles",
            { result_limit: 24 },
          );
          if (legacyError) {
            setError(legacyError.message);
            return;
          }
          const eligibleBuilders = (
            (legacyData as Candidate[] | null) ?? []
          ).map((builder) => ({
            ...builder,
            match_reasons: [
              builder.match_reason ||
                "Their public builder context is ready for a focused introduction",
            ],
            ranker_version: "legacy-safe",
          })) as DiscoverBuilder[];
          const ownerIds = eligibleBuilders.map((builder) => builder.id);
          const projectResult = ownerIds.length
            ? await supabase
                .from("cf_projects")
                .select(
                  "id,slug,name,summary,idea,stage,goals,collaboration_enabled,showcase_enabled,showcase_pitch,demo_url,owner_id",
                )
                .eq("is_public", true)
                .is("archived_at", null)
                .in("owner_id", ownerIds)
                .order("updated_at", { ascending: false })
            : { data: [], error: null };
          if (projectResult.error) {
            setError(projectResult.error.message);
            return;
          }
          const owners = new Map(
            eligibleBuilders.map((builder) => [builder.id, builder]),
          );
          const eligibleProjects = (
            (projectResult.data as Array<
              Pick<
                Project,
                | "id"
                | "slug"
                | "name"
                | "summary"
                | "idea"
                | "stage"
                | "goals"
                | "collaboration_enabled"
                | "showcase_enabled"
                | "showcase_pitch"
                | "demo_url"
                | "owner_id"
              >
            > | null) ?? []
          ).flatMap((project) => {
            const owner = owners.get(project.owner_id);
            return owner
              ? [
                  {
                    ...project,
                    showcase_enabled: Boolean(project.showcase_enabled),
                    showcase_pitch: project.showcase_pitch ?? null,
                    demo_url: project.demo_url ?? null,
                    owner_username: owner.username,
                    owner_full_name: owner.full_name,
                    match_reasons: [
                      owner.match_reasons[0] ||
                        "The project owner is eligible for an introduction",
                    ],
                    ranker_version: "legacy-safe",
                  } satisfies DiscoverProject,
                ]
              : [];
          });
          const nextBuilders = eligibleBuilders.slice(
            nextBuilderOffset,
            nextBuilderOffset + DISCOVER_BUILDERS_PAGE_SIZE,
          );
          const nextProjects = eligibleProjects.slice(
            nextProjectOffset,
            nextProjectOffset + DISCOVER_PROJECTS_PAGE_SIZE,
          );
          setBuilders((current) =>
            append ? [...current, ...nextBuilders] : nextBuilders,
          );
          setProjects((current) =>
            append ? [...current, ...nextProjects] : nextProjects,
          );
          setBuilderOffset(nextBuilderOffset + nextBuilders.length);
          setProjectOffset(nextProjectOffset + nextProjects.length);
          setHasMore(
            nextBuilderOffset + nextBuilders.length < eligibleBuilders.length ||
              nextProjectOffset + nextProjects.length < eligibleProjects.length,
          );
          return;
        }
        setError(
          builderResult.error?.message ||
            projectResult.error?.message ||
            "Discovery could not be refreshed.",
        );
        return;
      }
      const nextBuilders =
        (builderResult.data as DiscoverBuilder[] | null) ?? [];
      const nextProjects =
        (projectResult.data as DiscoverProject[] | null) ?? [];
      setBuilders((current) =>
        append ? [...current, ...nextBuilders] : nextBuilders,
      );
      setProjects((current) =>
        append ? [...current, ...nextProjects] : nextProjects,
      );
      setBuilderOffset(nextBuilderOffset + nextBuilders.length);
      setProjectOffset(nextProjectOffset + nextProjects.length);
      setHasMore(
        nextBuilders.length === DISCOVER_BUILDERS_PAGE_SIZE ||
          nextProjects.length === DISCOVER_PROJECTS_PAGE_SIZE,
      );
    },
    [supabase],
  );

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const candidateIds = Array.from(
      new Set([
        ...builders.map((builder) => builder.id),
        ...projects.map((project) => project.owner_id),
      ]),
    );
    if (!candidateIds.length) {
      setMeetStatusById({});
      return;
    }
    let active = true;
    void Promise.all(
      candidateIds.map(async (candidateId) => {
        const { data, error: statusError } = await supabase.rpc(
          "cf_get_direct_meet_status",
          { requested_candidate_id: candidateId },
        );
        const row = Array.isArray(data) ? data[0] : data;
        return [candidateId, statusError ? null : row?.status] as const;
      }),
    ).then((entries) => {
      if (!active) return;
      setMeetStatusById(
        Object.fromEntries(
          entries.filter(
            (entry): entry is readonly [string, DirectMeetStatus] =>
              Boolean(entry[1]),
          ),
        ),
      );
    });
    return () => {
      active = false;
    };
  }, [builders, projects, supabase]);

  const startMeet = async (candidateId: string, source = "DIRECT") => {
    if (startingId) return;
    setStartingId(candidateId);
    setError("");
    let { error: requestError } = await supabase.rpc("cf_open_direct_meet", {
      candidate_id: candidateId,
      requested_source: source,
    });
    // A safe deployment fallback keeps existing ranked introductions working
    // until migration 013 has been applied. It never invents a client-only
    // session or bypasses the server's candidate rules.
    if (requestError?.message.includes("cf_open_direct_meet")) {
      const fallback = await supabase.rpc("cf_open_meet", {
        candidate_id: candidateId,
      });
      requestError = fallback.error;
    }
    setStartingId(null);
    if (requestError) {
      setError(
        requestError.message === "CANDIDATE_UNAVAILABLE"
          ? "This introduction has changed. Refresh to see the current set."
          : requestError.message === "CANDIDATE_IN_MEET"
            ? "They are currently in another Meet. Choose someone else or try again later."
            : requestError.message === "MEET_ALREADY_ACTIVE"
              ? "You already have a Meet invitation open. Continue or cancel it before starting another."
              : requestError.message,
      );
      return;
    }
    router.push("/meet");
  };

  const hasResults = builders.length > 0 || projects.length > 0;
  return (
    <Page
      title="Discovery"
      description="A finite set of relevant builders and public work—with the reason for every introduction."
      actions={
        <button
          className="cf-secondary"
          onClick={() => void load()}
          disabled={loading || loadingMore}
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      }
    >
      <Notice error={error} />
      {loading ? (
        <State
          icon={<RefreshCw size={26} />}
          title="Reading your signal"
          body="Ranking only people and public projects that are eligible for a real introduction."
        />
      ) : hasResults ? (
        <section className="v3-discovery" aria-label="Ranked discovery results">
          {builders.length > 0 && (
            <div className="v3-discovery-lane">
              <div className="v3-discovery-lane-heading">
                <div>
                  <h2>Builders for a better first conversation</h2>
                  <p>
                    Context first. A mutual connection can only happen after you
                    both choose Connect in Meet.
                  </p>
                </div>
                <span>{builders.length} shown</span>
              </div>
              <div className="v3-discovery-builders">
                {builders.map((builder, index) =>
                  (() => {
                    const status = meetStatusById[builder.id];
                    const busy = status === "IN_MEET";
                    const meetLabel = busy
                      ? "In a Meet"
                      : status === "ONLINE_AVAILABLE"
                        ? "Meet now"
                        : status === "ONLINE"
                          ? "Invite to Meet"
                          : "Invite to Meet";
                    const statusLabel = busy
                      ? "Currently in a Meet"
                      : status === "ONLINE_AVAILABLE"
                        ? "Online · available"
                        : status === "ONLINE"
                          ? "Online"
                          : "Offline · invite available";
                    return (
                      <article
                        className="v3-discovery-builder"
                        style={{ "--discover-order": index } as CSSProperties}
                        key={builder.id}
                      >
                        <header>
                          <span className="cf-avatar large">
                            {initials(builder.full_name)}
                          </span>
                          <div>
                            <h3>
                              {builder.full_name}
                              {builder.email_verified && (
                                <Check size={15} aria-label="Email verified" />
                              )}
                            </h3>
                            <p>
                              @{builder.username} ·{" "}
                              {builder.headline || "Builder"}
                              {builder.experience_band
                                ? ` · ${builder.experience_band}`
                                : ""}
                            </p>
                          </div>
                          <span
                            className={`v3-discovery-rank ${busy ? "busy" : status?.startsWith("ONLINE") ? "online" : ""}`}
                          >
                            {statusLabel}
                          </span>
                        </header>
                        <div className="v3-tags">
                          {builder.skills.slice(0, 5).map((skill) => (
                            <span key={skill}>{skill}</span>
                          ))}
                        </div>
                        <div className="v3-discovery-context">
                          {builder.current_build && (
                            <p>
                              <b>Building</b>
                              {builder.current_build}
                            </p>
                          )}
                          {builder.looking_for && (
                            <p>
                              <b>Looking for</b>
                              {builder.looking_for}
                            </p>
                          )}
                        </div>
                        <div className="v3-discovery-why">
                          <b>Why this person</b>
                          {builder.match_reasons.slice(0, 3).map((reason) => (
                            <p key={reason}>{reason}</p>
                          ))}
                        </div>
                        <footer>
                          <button
                            className="cf-secondary"
                            onClick={() =>
                              router.push(`/u/${builder.username}`)
                            }
                          >
                            View profile <ArrowRight size={15} />
                          </button>
                          <button
                            className="cf-primary"
                            onClick={() => void startMeet(builder.id)}
                            disabled={Boolean(startingId) || busy}
                          >
                            {startingId === builder.id ? "Sending…" : meetLabel}
                            <ArrowRight size={15} />
                          </button>
                        </footer>
                      </article>
                    );
                  })(),
                )}
              </div>
            </div>
          )}
          {projects.length > 0 && (
            <div className="v3-discovery-lane v3-discovery-project-lane">
              <div className="v3-discovery-lane-heading">
                <div>
                  <h2>Public projects with shared context</h2>
                  <p>
                    Project details stay public; the room itself remains
                    governed by its access rules.
                  </p>
                </div>
                <span>{projects.length} shown</span>
              </div>
              <div className="v3-discovery-projects">
                {projects.map((project, index) =>
                  (() => {
                    const status = meetStatusById[project.owner_id];
                    const busy = status === "IN_MEET";
                    const meetLabel = busy
                      ? "Owner in a Meet"
                      : status === "ONLINE_AVAILABLE"
                        ? "Join demo"
                        : "Invite to demo";
                    return (
                      <article
                        className="v3-discovery-project"
                        style={{ "--discover-order": index } as CSSProperties}
                        key={project.id}
                      >
                        <header>
                          <span>{project.stage}</span>
                          <small>
                            {project.showcase_enabled
                              ? "Product showcase"
                              : project.collaboration_enabled
                                ? "Collaboration open"
                                : "Public overview"}
                          </small>
                        </header>
                        <h3>{project.name}</h3>
                        <p className="v3-discovery-project-summary">
                          {project.summary || project.idea}
                        </p>
                        {project.showcase_enabled && project.showcase_pitch && (
                          <p className="v3-discovery-project-goal">
                            <b>Product pitch</b>
                            {project.showcase_pitch}
                          </p>
                        )}
                        {project.goals && (
                          <p className="v3-discovery-project-goal">
                            <b>Project focus</b>
                            {project.goals}
                          </p>
                        )}
                        <div className="v3-discovery-why">
                          <b>Why relevant</b>
                          {project.match_reasons.slice(0, 3).map((reason) => (
                            <p key={reason}>{reason}</p>
                          ))}
                        </div>
                        <footer>
                          {project.demo_url && (
                            <a
                              className="cf-secondary"
                              href={project.demo_url}
                              target="_blank"
                              rel="noreferrer"
                            >
                              View demo <ExternalLink size={15} />
                            </a>
                          )}
                          <button
                            className="cf-secondary"
                            onClick={() =>
                              router.push(`/buildroom/${project.slug}`)
                            }
                          >
                            View project <ArrowRight size={15} />
                          </button>
                          <button
                            className="cf-primary"
                            onClick={() =>
                              void startMeet(
                                project.owner_id,
                                project.showcase_enabled
                                  ? "SHOWCASE"
                                  : "DIRECT",
                              )
                            }
                            disabled={Boolean(startingId) || busy}
                          >
                            {startingId === project.owner_id
                              ? "Sending…"
                              : meetLabel}
                            <ArrowRight size={15} />
                          </button>
                        </footer>
                      </article>
                    );
                  })(),
                )}
              </div>
            </div>
          )}
          {hasMore && (
            <div className="v3-discovery-more">
              <button
                className="cf-secondary"
                onClick={() => void load(true, builderOffset, projectOffset)}
                disabled={loadingMore}
              >
                {loadingMore ? "Loading…" : "Load more"}
                <ArrowRight size={15} />
              </button>
              <small>
                Discovery stays finite. You are seeing the next eligible ranked
                set.
              </small>
            </div>
          )}
        </section>
      ) : (
        <State
          icon={<Compass size={28} />}
          title="No introductions right now"
          body="You have already met the available candidates, or no eligible builder or public project currently matches your discovery settings."
          action={
            <button className="cf-primary" onClick={() => router.push("/meet")}>
              Go to Meet
            </button>
          }
        />
      )}
    </Page>
  );
}

export function SearchPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <SearchInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function SearchInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [pro, setPro] = useState(false);
  const [people, setPeople] = useState<Candidate[]>([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    void Promise.all([
      supabase
        .from("cf_entitlements")
        .select("plan,status,expires_at")
        .eq("profile_id", userId)
        .maybeSingle(),
      supabase.rpc("cf_discover_profiles", { result_limit: 24 }),
    ]).then(([entitlement, candidates]) => {
      setPro(
        Boolean(
          entitlement.data &&
          entitlement.data.plan === "PRO" &&
          entitlement.data.status === "ACTIVE",
        ),
      );
      setPeople((candidates.data as Candidate[]) ?? []);
      setLoading(false);
    });
  }, [supabase, userId]);
  if (loading)
    return (
      <main className="cf-loading">
        <span className="cf-pulse" />
        Opening search
      </main>
    );
  if (!pro)
    return (
      <Page
        title="Search"
        description="Use focused search when a specific kind of collaborator is on your mind."
      >
        <State
          icon={<LockKeyhole size={28} />}
          title="Search is a Pro workspace"
          body="Your current account does not have an active Pro entitlement. Billing is not configured in this deployment, so no checkout is shown."
          action={
            <button className="cf-primary" onClick={() => router.push("/pro")}>
              View plan status
            </button>
          }
        />
      </Page>
    );
  const results = people.filter((person) =>
    `${person.full_name} ${person.headline ?? ""} ${person.skills.join(" ")} ${person.domains.join(" ")}`
      .toLowerCase()
      .includes(query.trim().toLowerCase()),
  );
  return (
    <Page
      title="Search"
      description="Search only across people you are currently permitted to discover."
    >
      <label className="v3-search">
        <Search size={18} />
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Skills, focus, or name"
          autoFocus
        />
      </label>
      {results.length ? (
        <div className="v3-people">
          {results.map((person) => (
            <Person
              key={person.id}
              person={person}
              action={
                <button
                  className="cf-secondary"
                  onClick={() => router.push(`/u/${person.username}`)}
                >
                  Open
                </button>
              }
            />
          ))}
        </div>
      ) : (
        <State
          icon={<Search size={28} />}
          title="No matching people"
          body="Try a wider phrase. Search does not invent recommendations beyond your current discovery permissions."
        />
      )}
    </Page>
  );
}

export function NotificationsPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <NotificationsInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function NotificationsInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const router = useRouter();
  const [items, setItems] = useState<
    Array<{
      id: string;
      kind: string;
      payload: Record<string, string>;
      read_at: string | null;
      created_at: string;
    }>
  >([]);
  const [error, setError] = useState("");
  const load = useCallback(async () => {
    const { data, error: requestError } = await supabase
      .from("cf_notifications")
      .select("*")
      .eq("profile_id", userId)
      .order("created_at", { ascending: false });
    if (requestError) setError(requestError.message);
    else setItems(data ?? []);
  }, [supabase, userId]);
  useEffect(() => {
    void load();
  }, [load]);
  const open = async (item: (typeof items)[number]) => {
    await supabase
      .from("cf_notifications")
      .update({ read_at: new Date().toISOString() })
      .eq("id", item.id);
    if (item.payload?.conversation_id)
      router.push(`/chat/${item.payload.conversation_id}`);
    else if (item.payload?.connection_id)
      router.push(`/connections/${item.payload.connection_id}`);
    else if (item.payload?.project_id) router.push("/buildroom");
    else void load();
  };
  return (
    <Page
      title="Notifications"
      description="Only actions connected to your actual conversations and rooms appear here."
    >
      <Notice error={error} />
      {items.length ? (
        <div className="v3-list">
          {items.map((item) => (
            <button
              key={item.id}
              className={item.read_at ? "" : "unread"}
              onClick={() => void open(item)}
            >
              <Bell size={18} />
              <span>
                <strong>{item.kind.replaceAll("_", " ")}</strong>
                <small>{date(item.created_at)}</small>
              </span>
              <ArrowRight size={16} />
            </button>
          ))}
        </div>
      ) : (
        <State
          icon={<Bell size={28} />}
          title="You are all caught up"
          body="New mutual connections, chat messages, and room requests will appear here."
        />
      )}
    </Page>
  );
}

export function ProPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <ProInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function ProInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const [item, setItem] = useState<{
    plan: string;
    status: string;
    expires_at: string | null;
  } | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    void supabase
      .from("cf_entitlements")
      .select("plan,status,expires_at")
      .eq("profile_id", userId)
      .maybeSingle()
      .then(({ data }) => {
        setItem(data);
        setLoading(false);
      });
  }, [supabase, userId]);
  return (
    <Page
      title="Your plan"
      description="Your entitlement is always read from the live account record."
    >
      {loading ? (
        <State
          icon={<RefreshCw size={26} />}
          title="Checking your account"
          body="Reading your current plan status."
        />
      ) : item?.plan === "PRO" && item.status === "ACTIVE" ? (
        <section className="v3-plan active">
          <Sparkles size={25} />
          <h2>Pro is active</h2>
          <p>
            {item.expires_at
              ? `Renews or expires ${date(item.expires_at)}.`
              : "Your account has an active Pro entitlement."}
          </p>
        </section>
      ) : (
        <section className="v3-plan">
          <LockKeyhole size={25} />
          <h2>Free account</h2>
          <p>
            Meet, mutual chat, and your own Build Rooms remain available. Pro
            unlocks intentional member search and private-room join requests.
          </p>
          <small>
            Checkout is unavailable until a verified billing provider is
            configured on the server.
          </small>
        </section>
      )}
    </Page>
  );
}

export function SettingsPage() {
  return (
    <WorkspaceGate>
      {({ supabase, profile }) => (
        <SettingsInner supabase={supabase} profile={profile} />
      )}
    </WorkspaceGate>
  );
}
function SettingsInner({
  supabase,
  profile,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  profile: Profile;
}) {
  const [available, setAvailable] = useState(profile.is_discoverable);
  const [github, setGithub] = useState("");
  const [linkedin, setLinkedin] = useState("");
  const [portfolio, setPortfolio] = useState("");
  const [showLinks, setShowLinks] = useState(true);
  const [message, setMessage] = useState("");
  useEffect(() => {
    void supabase
      .from("cf_profile_contacts")
      .select("*")
      .eq("profile_id", profile.id)
      .then(({ data }) => {
        (data ?? []).forEach(
          (contact: {
            type: string;
            value: string;
            links_visible_to_connections: boolean;
          }) => {
            if (contact.type === "GITHUB") setGithub(contact.value);
            if (contact.type === "LINKEDIN") setLinkedin(contact.value);
            if (contact.type === "PORTFOLIO") setPortfolio(contact.value);
            setShowLinks(contact.links_visible_to_connections);
          },
        );
      });
  }, [profile.id, supabase]);
  const save = async (event: FormEvent) => {
    event.preventDefault();
    setMessage("");
    const profileResult = await supabase
      .from("cf_profiles")
      .update({ is_discoverable: available })
      .eq("id", profile.id);
    if (profileResult.error) {
      setMessage(profileResult.error.message);
      return;
    }
    const rows = [
      ["GITHUB", github],
      ["LINKEDIN", linkedin],
      ["PORTFOLIO", portfolio],
    ]
      .filter(([, value]) => value.trim())
      .map(([type, value]) => ({
        profile_id: profile.id,
        type,
        value: value.trim(),
        links_visible_to_connections: showLinks,
      }));
    if (rows.length) {
      const result = await supabase
        .from("cf_profile_contacts")
        .upsert(rows, { onConflict: "profile_id,type" });
      if (result.error) {
        setMessage(result.error.message);
        return;
      }
    }
    setMessage("Settings saved.");
  };
  return (
    <Page
      title="Settings"
      description="Control your availability and what mutual connections can see."
    >
      <form className="v3-form" onSubmit={save}>
        <label className="cf-switch">
          <input
            type="checkbox"
            checked={available}
            onChange={(event) => setAvailable(event.target.checked)}
          />
          <span />
          <b>Available for discovery</b>
          <small>
            Pausing hides you from new Meet suggestions. Existing relationships
            remain available.
          </small>
        </label>
        <div className="v3-form-grid">
          <label>
            <span>GitHub</span>
            <input
              value={github}
              onChange={(event) => setGithub(event.target.value)}
              placeholder="https://github.com/you"
            />
          </label>
          <label>
            <span>LinkedIn</span>
            <input
              value={linkedin}
              onChange={(event) => setLinkedin(event.target.value)}
              placeholder="https://linkedin.com/in/you"
            />
          </label>
          <label>
            <span>
              Portfolio <em>optional</em>
            </span>
            <input
              value={portfolio}
              onChange={(event) => setPortfolio(event.target.value)}
              placeholder="https://your-site.com"
            />
          </label>
        </div>
        <label className="cf-switch">
          <input
            type="checkbox"
            checked={showLinks}
            onChange={(event) => setShowLinks(event.target.checked)}
          />
          <span />
          <b>Share links with mutual connections</b>
          <small>Links are never exposed to strangers in discovery.</small>
        </label>
        <button className="cf-primary">
          Save changes <Check size={16} />
        </button>
        {message && <p className="v3-form-message">{message}</p>}
      </form>
    </Page>
  );
}

export function BlockedPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <BlockedInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function BlockedInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const [items, setItems] = useState<
    Array<{
      blocked_id: string;
      username: string;
      full_name: string;
      created_at: string;
    }>
  >([]);
  const load = useCallback(async () => {
    const { data } = await supabase.rpc("cf_list_my_blocks");
    setItems(data ?? []);
  }, [supabase]);
  useEffect(() => {
    void load();
  }, [load]);
  const unblock = async (id: string) => {
    await supabase
      .from("cf_blocks")
      .delete()
      .eq("blocker_id", userId)
      .eq("blocked_id", id);
    void load();
  };
  return (
    <Page
      title="Blocked people"
      description="Blocking immediately removes a person from discovery, Meets, and mutual access."
    >
      {items.length ? (
        <div className="v3-list">
          {items.map((item) => (
            <div key={item.blocked_id}>
              <ShieldBan size={18} />
              <span>
                <strong>{item.full_name}</strong>
                <small>
                  @{item.username} · blocked {date(item.created_at)}
                </small>
              </span>
              <button
                className="cf-secondary"
                onClick={() => void unblock(item.blocked_id)}
              >
                Unblock
              </button>
            </div>
          ))}
        </div>
      ) : (
        <State
          icon={<ShieldBan size={28} />}
          title="No one is blocked"
          body="Safety controls are available inside every Meet."
        />
      )}
    </Page>
  );
}

export function ReportPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <ReportInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function ReportInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const [subject, setSubject] = useState("");
  const [reason, setReason] = useState("Harassment or abusive behavior");
  const [detail, setDetail] = useState("");
  const [status, setStatus] = useState("");
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!subject) {
      setStatus("Choose the person you need to report.");
      return;
    }
    const { error } = await supabase.from("cf_reports").insert({
      reporter_id: userId,
      subject_id: subject,
      reason,
      detail: detail.trim() || null,
    });
    setStatus(
      error
        ? error.message
        : "Report received. It has been recorded for review.",
    );
  };
  return (
    <Page
      title="Report a problem"
      description="Reports are private. Share only the context that will help a reviewer understand the issue."
    >
      <form className="v3-form" onSubmit={submit}>
        <label>
          <span>Person&apos;s profile ID</span>
          <input
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            required
            placeholder="Paste the profile ID from the Meet or connection"
          />
        </label>
        <label>
          <span>Reason</span>
          <select
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          >
            <option>Harassment or abusive behavior</option>
            <option>Spam or scam</option>
            <option>Impersonation</option>
            <option>Other safety concern</option>
          </select>
        </label>
        <label>
          <span>
            What happened? <em>optional</em>
          </span>
          <textarea
            value={detail}
            onChange={(event) => setDetail(event.target.value)}
            maxLength={2000}
          />
        </label>
        <button className="cf-primary">
          Send report <Flag size={16} />
        </button>
        {status && <p className="v3-form-message">{status}</p>}
      </form>
    </Page>
  );
}

export function PublicProfilePage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <PublicProfileInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function PublicProfileInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const { username } = useParams<{ username: string }>();
  const router = useRouter();
  const [person, setPerson] = useState<Profile | null>(null);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    void supabase
      .from("cf_profiles")
      .select("*")
      .eq("username", username)
      .maybeSingle()
      .then(async ({ data }) => {
        setPerson(data as Profile | null);
        if (data) {
          const result = await supabase
            .from("cf_projects")
            .select("*")
            .eq("owner_id", (data as Profile).id)
            .eq("is_public", true)
            .is("archived_at", null);
          setProjects((result.data as Project[]) ?? []);
        }
        setLoading(false);
      });
  }, [supabase, username]);
  if (loading)
    return (
      <main className="cf-loading">
        <span className="cf-pulse" />
        Opening profile
      </main>
    );
  if (!person)
    return (
      <Page
        title="Profile unavailable"
        description="This profile is no longer discoverable or you do not have permission to view it."
      >
        <State
          icon={<UserRound size={28} />}
          title="No profile to show"
          body="Try returning to discovery."
          action={
            <button
              className="cf-primary"
              onClick={() => router.push("/discover")}
            >
              Discovery
            </button>
          }
        />
      </Page>
    );
  const mine = person.id === userId;
  return (
    <Page
      title={person.full_name}
      description={person.headline || "Builder on CONFLUX."}
      actions={
        <button
          className="cf-secondary"
          onClick={() => router.push(mine ? "/profile" : "/meet")}
        >
          {mine ? "Edit profile" : "Meet people"}
        </button>
      }
    >
      <section className="v3-profile-view">
        <span className="cf-avatar xl">{initials(person.full_name)}</span>
        <div>
          <div className="v3-tags">
            {person.skills.map((skill) => (
              <span key={skill}>{skill}</span>
            ))}
          </div>
          <p>
            {person.current_build || person.bio || "No current build shared."}
          </p>
          <p>
            <b>Looking for:</b>{" "}
            {person.looking_for || "Thoughtful builder conversations."}
          </p>
        </div>
      </section>
      <section className="v3-subsection">
        <h2>Public Build Rooms</h2>
        {projects.length ? (
          <div className="v3-projects">
            {projects.map((project) => (
              <button
                key={project.id}
                onClick={() => router.push(`/buildroom/${project.slug}`)}
              >
                <span>{project.stage}</span>
                <strong>{project.name}</strong>
                <small>{project.summary || project.idea}</small>
                <ArrowRight size={16} />
              </button>
            ))}
          </div>
        ) : (
          <State
            icon={<FolderKanban size={24} />}
            title="No public rooms"
            body="Private work stays inside its Build Room."
          />
        )}
      </section>
    </Page>
  );
}

export function ConnectionDetailPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <ConnectionDetailInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function ConnectionDetailInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [connection, setConnection] = useState<Connection | null>(null);
  const [other, setOther] = useState<Profile | null>(null);
  const [conversation, setConversation] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [requestingMeet, setRequestingMeet] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    void supabase
      .from("cf_connections")
      .select("*")
      .eq("id", id)
      .maybeSingle()
      .then(async ({ data }) => {
        const row = data as Connection | null;
        setConnection(row);
        if (row) {
          const otherId =
            row.low_profile_id === userId
              ? row.high_profile_id
              : row.low_profile_id;
          const [profileResult, conversationResult] = await Promise.all([
            supabase
              .from("cf_profiles")
              .select("*")
              .eq("id", otherId)
              .maybeSingle(),
            supabase
              .from("cf_conversations")
              .select("id")
              .eq("connection_id", id)
              .maybeSingle(),
          ]);
          setOther(profileResult.data as Profile | null);
          setConversation(conversationResult.data?.id ?? null);
        }
        setLoading(false);
      });
  }, [id, supabase, userId]);
  if (loading)
    return (
      <main className="cf-loading">
        <span className="cf-pulse" />
        Opening connection
      </main>
    );
  if (!connection || !other)
    return (
      <Page
        title="Connection unavailable"
        description="This connection is private to its two participants."
      >
        <State
          icon={<UsersRound size={28} />}
          title="Nothing to open"
          body="Return to your mutual connections."
          action={
            <button
              className="cf-primary"
              onClick={() => router.push("/connections")}
            >
              Connections
            </button>
          }
        />
      </Page>
    );
  return (
    <Page
      title="Your connection"
      description={`You both chose Connect on ${date(connection.created_at)}.`}
    >
      <Notice error={error} />
      <Person
        person={other}
        action={
          <button
            className="cf-primary"
            onClick={() => conversation && router.push(`/chat/${conversation}`)}
          >
            Open chat <MessageCircle size={16} />
          </button>
        }
      />
      <section className="v3-connection-actions">
        <button
          className="cf-secondary"
          onClick={() => router.push(`/u/${other.username}`)}
        >
          View profile
        </button>
        <button
          className="cf-secondary"
          disabled={requestingMeet}
          onClick={async () => {
            setRequestingMeet(true);
            setError("");
            const { error: requestError } = await supabase.rpc(
              "cf_open_direct_meet",
              {
                candidate_id: other.id,
                requested_source: "CONNECTION",
              },
            );
            setRequestingMeet(false);
            if (requestError) {
              setError(
                requestError.message === "CANDIDATE_IN_MEET"
                  ? "They are currently in another Meet. Try again later."
                  : requestError.message,
              );
              return;
            }
            router.push("/meet");
          }}
        >
          {requestingMeet ? "Sending…" : "Meet again"} <ArrowRight size={16} />
        </button>
        <button
          className="cf-secondary"
          onClick={() => router.push("/buildroom/new")}
        >
          Start a Build Room <Wrench size={16} />
        </button>
      </section>
    </Page>
  );
}

export function ChatPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <ChatInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function ChatInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const { conversationId } = useParams<{ conversationId: string }>();
  const router = useRouter();
  const [messages, setMessages] = useState<Message[]>([]);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const load = useCallback(async () => {
    setLoading(true);
    const { data, error: requestError } = await supabase
      .from("cf_messages")
      .select("*")
      .eq("conversation_id", conversationId)
      .is("deleted_at", null)
      .order("created_at");
    setLoading(false);
    if (requestError) setError(requestError.message);
    else {
      setMessages((data as Message[]) ?? []);
      void supabase.rpc("cf_mark_conversation_read", {
        requested_conversation_id: conversationId,
      });
    }
  }, [conversationId, supabase]);
  useEffect(() => {
    void load();
    const channel = supabase
      .channel(`v3-chat:${conversationId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "cf_messages",
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload) =>
          setMessages((current) =>
            current.some((item) => item.id === (payload.new as Message).id)
              ? current
              : [...current, payload.new as Message],
          ),
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [conversationId, load, supabase]);
  const send = async (event: FormEvent) => {
    event.preventDefault();
    const body = draft.trim();
    if (!body) return;
    setDraft("");
    const { data, error: requestError } = await supabase.rpc(
      "cf_send_message",
      {
        requested_conversation_id: conversationId,
        requested_body: body,
        requested_client_message_id: crypto.randomUUID(),
      },
    );
    if (requestError) {
      setDraft(body);
      setError(requestError.message);
    } else
      setMessages((current) =>
        current.some((item) => item.id === (data as Message).id)
          ? current
          : [...current, data as Message],
      );
  };
  return (
    <Page
      title="Private chat"
      description="Persistent chat opens only after a mutual Connect."
      actions={
        <button
          className="cf-secondary"
          onClick={() => router.push("/connections")}
        >
          <ArrowLeft size={16} />
          Connections
        </button>
      }
    >
      <Notice error={error} />
      {loading ? (
        <State
          icon={<RefreshCw size={28} />}
          title="Loading conversation"
          body="Checking your secure access to this thread."
        />
      ) : (
        <section className="v3-chat">
          <div className="cf-chat">
            {messages.length ? (
              messages.map((message) => (
                <p
                  className={message.sender_id === userId ? "mine" : "theirs"}
                  key={message.id}
                >
                  {message.body}
                </p>
              ))
            ) : (
              <State
                icon={<MessageCircle size={24} />}
                title="Start the thread"
                body="You both chose this conversation. Pick up with a useful next step."
              />
            )}
          </div>
          <form className="cf-compose" onSubmit={send}>
            <input
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              maxLength={4000}
              placeholder="Write a message"
            />
            <button aria-label="Send message">
              <ArrowRight size={18} />
            </button>
          </form>
        </section>
      )}
    </Page>
  );
}

export function NewBuildRoomPage() {
  return (
    <WorkspaceGate>
      {({ supabase, user }) => (
        <NewBuildRoomInner supabase={supabase} userId={user.id} />
      )}
    </WorkspaceGate>
  );
}
function NewBuildRoomInner({
  supabase,
  userId,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
}) {
  const router = useRouter();
  const [form, setForm] = useState({
    name: "",
    idea: "",
    stage: "IDEA",
    is_public: false,
    collaboration_enabled: false,
  });
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const create = async (event: FormEvent) => {
    event.preventDefault();
    setSaving(true);
    setError("");
    const { data, error: requestError } = await supabase.rpc(
      "cf_create_build_room",
      {
        requested_name: form.name,
        requested_idea: form.idea,
        requested_stage: form.stage,
        requested_is_public: form.is_public,
        requested_collaboration_enabled: form.collaboration_enabled,
      },
    );
    setSaving(false);
    if (requestError) {
      setError(
        requestError.message.includes("FREE_BUILD_ROOM_LIMIT_REACHED")
          ? "Your Free plan includes one active Build Room. Archive it or upgrade to Pro to start another."
          : requestError.message,
      );
    } else router.push(`/buildroom/${(data as Project).slug}`);
  };
  return (
    <Page
      title="Start a Build Room"
      description="Your Free plan includes one active room. Pro unlocks additional rooms."
      actions={
        <button
          className="cf-secondary"
          onClick={() => router.push("/buildroom")}
        >
          <ArrowLeft size={16} />
          Build Rooms
        </button>
      }
    >
      <form className="v3-form" onSubmit={create}>
        <label>
          <span>Room name</span>
          <input
            required
            maxLength={160}
            value={form.name}
            onChange={(event) => setForm({ ...form, name: event.target.value })}
            placeholder="What are you building?"
          />
        </label>
        <label>
          <span>What problem are you moving?</span>
          <textarea
            required
            maxLength={280}
            value={form.idea}
            onChange={(event) => setForm({ ...form, idea: event.target.value })}
            placeholder="A clear, concise promise is enough to begin."
          />
        </label>
        <label>
          <span>Stage</span>
          <select
            value={form.stage}
            onChange={(event) =>
              setForm({ ...form, stage: event.target.value })
            }
          >
            <option>IDEA</option>
            <option>PLANNING</option>
            <option>BUILDING</option>
            <option>BETA</option>
            <option>LIVE</option>
          </select>
        </label>
        <label className="cf-switch">
          <input
            type="checkbox"
            checked={form.is_public}
            onChange={(event) =>
              setForm({ ...form, is_public: event.target.checked })
            }
          />
          <span />
          <b>Show this room publicly</b>
          <small>
            Only its public overview is visible. Tasks, discussion, notes, and
            files remain member-only.
          </small>
        </label>
        <label className="cf-switch">
          <input
            type="checkbox"
            checked={form.collaboration_enabled}
            onChange={(event) =>
              setForm({ ...form, collaboration_enabled: event.target.checked })
            }
          />
          <span />
          <b>Accept collaboration requests</b>
          <small>
            Connected Pro members can request to join after a mutual connection.
          </small>
        </label>
        <button className="cf-primary" disabled={saving}>
          {saving ? "Creating…" : "Create room"} <ArrowRight size={16} />
        </button>
        <Notice error={error} />
      </form>
    </Page>
  );
}

export function BuildRoomWorkspacePage() {
  return (
    <WorkspaceGate>
      {({ supabase, user, profile }) => (
        <BuildRoomWorkspaceInner
          supabase={supabase}
          userId={user.id}
          profile={profile}
        />
      )}
    </WorkspaceGate>
  );
}
function BuildRoomWorkspaceInner({
  supabase,
  userId,
  profile,
}: {
  supabase: ReturnType<typeof getSupabaseClient>;
  userId: string;
  profile: Profile;
}) {
  const { slug } = useParams<{ slug: string }>();
  const pathname = usePathname();
  const router = useRouter();
  const section =
    pathname.split("/").at(-1) === slug
      ? "overview"
      : (pathname.split("/").at(-1) ?? "overview");
  const [project, setProject] = useState<Project | null>(null);
  const [member, setMember] = useState(false);
  const [tasks, setTasks] = useState<ProjectTask[]>([]);
  const [milestones, setMilestones] = useState<Milestone[]>([]);
  const [notes, setNotes] = useState<ProjectNote[]>([]);
  const [messages, setMessages] = useState<ProjectMessage[]>([]);
  const [members, setMembers] = useState<
    Array<{ profile_id: string; role: string; profile?: Profile }>
  >([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState("");
  const [requestingMeet, setRequestingMeet] = useState(false);
  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    const { data: room, error: roomError } = await supabase
      .from("cf_projects")
      .select("*")
      .eq("slug", slug)
      .maybeSingle();
    if (roomError || !room) {
      setError(roomError?.message || "This Build Room is unavailable.");
      setLoading(false);
      return;
    }
    const projectData = room as Project;
    setProject(projectData);
    const [
      memberResult,
      tasksResult,
      milestonesResult,
      notesResult,
      messagesResult,
      membersResult,
    ] = await Promise.all([
      supabase
        .from("cf_project_members")
        .select("profile_id,role")
        .eq("project_id", projectData.id)
        .eq("profile_id", userId)
        .maybeSingle(),
      supabase
        .from("cf_project_tasks")
        .select("*")
        .eq("project_id", projectData.id)
        .order("created_at"),
      supabase
        .from("cf_project_milestones")
        .select("*")
        .eq("project_id", projectData.id)
        .order("target_at"),
      supabase
        .from("cf_project_notes")
        .select("*")
        .eq("project_id", projectData.id)
        .order("updated_at", { ascending: false }),
      supabase
        .from("cf_project_messages")
        .select("*")
        .eq("project_id", projectData.id)
        .order("created_at"),
      supabase
        .from("cf_project_members")
        .select("profile_id,role")
        .eq("project_id", projectData.id),
    ]);
    setMember(Boolean(memberResult.data));
    setTasks((tasksResult.data as ProjectTask[]) ?? []);
    setMilestones((milestonesResult.data as Milestone[]) ?? []);
    setNotes((notesResult.data as ProjectNote[]) ?? []);
    setMessages(uniqueById((messagesResult.data as ProjectMessage[]) ?? []));
    const memberRows =
      (membersResult.data as Array<{ profile_id: string; role: string }>) ?? [];
    if (memberRows.length) {
      const profiles = await supabase
        .from("cf_profiles")
        .select("*")
        .in(
          "id",
          memberRows.map((row) => row.profile_id),
        );
      const map = new Map(
        ((profiles.data as Profile[]) ?? []).map((person) => [
          person.id,
          person,
        ]),
      );
      setMembers(
        memberRows.map((row) => ({ ...row, profile: map.get(row.profile_id) })),
      );
    }
    setLoading(false);
  }, [slug, supabase, userId]);
  useEffect(() => {
    void load();
  }, [load]);
  useEffect(() => {
    if (!project) return;
    const channel = supabase
      .channel(`room:${project.id}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "cf_project_messages",
          filter: `project_id=eq.${project.id}`,
        },
        (payload) =>
          setMessages((current) =>
            uniqueById([...current, payload.new as ProjectMessage]),
          ),
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [project, supabase]);
  const addTask = async (event: FormEvent) => {
    event.preventDefault();
    if (!project || !draft.trim()) return;
    const { error: requestError } = await supabase
      .from("cf_project_tasks")
      .insert({
        project_id: project.id,
        title: draft.trim(),
        status: "TODO",
        priority: "MEDIUM",
      });
    if (requestError) setError(requestError.message);
    else {
      setDraft("");
      void load();
    }
  };
  const addMilestone = async () => {
    if (!project) return;
    const title = window.prompt("Milestone name");
    if (!title?.trim()) return;
    const result = await supabase
      .from("cf_project_milestones")
      .insert({ project_id: project.id, name: title.trim(), status: "OPEN" });
    if (result.error) setError(result.error.message);
    else void load();
  };
  const addNote = async () => {
    if (!project) return;
    const title = window.prompt("Note title");
    if (!title?.trim()) return;
    const body = window.prompt("Note") ?? "";
    const result = await supabase.from("cf_project_notes").insert({
      project_id: project.id,
      author_id: userId,
      title: title.trim(),
      body,
    });
    if (result.error) setError(result.error.message);
    else void load();
  };
  const sendMessage = async (event: FormEvent) => {
    event.preventDefault();
    if (!project || !draft.trim()) return;
    const body = draft.trim();
    setDraft("");
    const { data, error: requestError } = await supabase.rpc(
      "cf_send_project_message",
      {
        requested_project_id: project.id,
        requested_body: body,
        requested_client_message_id: crypto.randomUUID(),
      },
    );
    if (requestError) {
      setDraft(body);
      setError(requestError.message);
    } else
      setMessages((current) =>
        current.some((message) => message.id === (data as ProjectMessage).id)
          ? current
          : [...current, data as ProjectMessage],
      );
  };
  const requestJoin = async () => {
    if (!project) return;
    const { error: requestError } = await supabase.rpc(
      "cf_request_project_join",
      { project: project.id, note: null },
    );
    if (requestError)
      setError(
        requestError.message.includes("MUTUAL_CONNECTION_REQUIRED")
          ? "Connect with this room owner first, then upgrade to Pro to request access."
          : requestError.message.includes("FORBIDDEN_PRO_REQUIRED")
            ? "An active Pro plan is required to request access to another member’s Build Room."
            : requestError.message,
      );
    else setError("Your join request was sent to the room owner.");
  };
  const requestMeet = async () => {
    if (!project || requestingMeet) return;
    setRequestingMeet(true);
    setError("");
    const { error: requestError } = await supabase.rpc("cf_open_direct_meet", {
      candidate_id: project.owner_id,
      requested_source: "BUILD_ROOM",
    });
    setRequestingMeet(false);
    if (requestError) {
      setError(
        requestError.message === "CANDIDATE_IN_MEET"
          ? "The builder is currently in another Meet. Try again later."
          : requestError.message,
      );
      return;
    }
    router.push("/meet");
  };
  if (loading)
    return (
      <main className="cf-loading">
        <span className="cf-pulse" />
        Opening Build Room
      </main>
    );
  if (!project)
    return (
      <Page
        title="Room unavailable"
        description="You may not have access to this Build Room."
      >
        <State
          icon={<FolderKanban size={28} />}
          title="Nothing to open"
          body={error || "Return to your rooms."}
          action={
            <button
              className="cf-primary"
              onClick={() => router.push("/buildroom")}
            >
              Build Rooms
            </button>
          }
        />
      </Page>
    );
  const nav = [
    ["overview", "Overview"],
    ["tasks", "Tasks"],
    ["milestones", "Milestones"],
    ["members", "Members"],
    ["discussion", "Discussion"],
    ["notes", "Notes"],
    ["files", "Files"],
    ["github", "GitHub"],
    ["settings", "Settings"],
  ] as const;
  const url = (item: string) =>
    item === "overview" ? `/buildroom/${slug}` : `/buildroom/${slug}/${item}`;
  const isLead = project.owner_id === userId;
  return (
    <Page
      title={project.name}
      description={project.summary || project.idea}
      actions={
        <button
          className="cf-secondary"
          onClick={() => router.push("/buildroom")}
        >
          <ArrowLeft size={16} />
          Rooms
        </button>
      }
    >
      <Notice error={error} />
      <nav className="v3-room-nav" aria-label="Build Room sections">
        {nav.map(([key, label]) => (
          <button
            key={key}
            className={section === key ? "active" : ""}
            onClick={() => router.push(url(key))}
          >
            {label}
          </button>
        ))}
      </nav>
      {!member && (
        <section className="v3-access">
          <LockKeyhole size={20} />
          <div>
            <strong>Member access required</strong>
            <p>
              This room&apos;s work surfaces are private.{" "}
              {project.collaboration_enabled
                ? "If you have an active Pro plan, you can request to join."
                : "The owner is not accepting collaboration requests."}
            </p>
          </div>
          {project.collaboration_enabled && (
            <button className="cf-primary" onClick={() => void requestJoin()}>
              Request to join
            </button>
          )}
          {project.owner_id !== userId && (
            <button
              className="cf-secondary"
              onClick={() => void requestMeet()}
              disabled={requestingMeet}
            >
              {requestingMeet ? "Sending…" : "Meet builder"}
              <ArrowRight size={16} />
            </button>
          )}
        </section>
      )}
      {member && (
        <section className="v3-room-panel">
          {section === "overview" && (
            <>
              <div className="v3-room-summary">
                <span>{project.stage}</span>
                <p>{project.problem || project.idea}</p>
                <div className="v3-tags">
                  {project.is_public && <span>Public overview</span>}
                  {project.collaboration_enabled && (
                    <span>Collaboration open</span>
                  )}
                </div>
              </div>
              <div className="v3-room-columns">
                <section>
                  <h2>Next tasks</h2>
                  {tasks.slice(0, 5).map((task) => (
                    <p className="v3-task" key={task.id}>
                      <i className={task.status === "DONE" ? "done" : ""} />
                      {task.title}
                    </p>
                  )) || <p>No tasks yet.</p>}
                </section>
                <section>
                  <h2>Milestones</h2>
                  {milestones.slice(0, 4).map((item) => (
                    <p className="v3-task" key={item.id}>
                      <i />
                      {item.name}
                    </p>
                  )) || <p>No milestones yet.</p>}
                </section>
              </div>
            </>
          )}
          {section === "tasks" && (
            <>
              <div className="v3-section-action">
                <h2>Tasks</h2>
                {isLead && (
                  <button className="cf-secondary" onClick={() => setDraft("")}>
                    Add below
                  </button>
                )}
              </div>
              {tasks.length ? (
                <div className="v3-task-list">
                  {tasks.map((task) => (
                    <button
                      key={task.id}
                      onClick={async () => {
                        if (!isLead) return;
                        const next = task.status === "DONE" ? "TODO" : "DONE";
                        const result = await supabase
                          .from("cf_project_tasks")
                          .update({ status: next })
                          .eq("id", task.id);
                        if (result.error) setError(result.error.message);
                        else void load();
                      }}
                    >
                      <i className={task.status === "DONE" ? "done" : ""}>
                        {task.status === "DONE" && <Check size={12} />}
                      </i>
                      <span>
                        <strong>{task.title}</strong>
                        <small>
                          {task.status} · {task.priority}
                        </small>
                      </span>
                    </button>
                  ))}
                </div>
              ) : (
                <State
                  icon={<Check size={25} />}
                  title="No tasks yet"
                  body="Keep the first step small and concrete."
                />
              )}
              {isLead && (
                <form className="cf-add-task" onSubmit={addTask}>
                  <input
                    value={draft}
                    onChange={(event) => setDraft(event.target.value)}
                    placeholder="Add the next step"
                  />
                  <button aria-label="Add task">
                    <Plus size={18} />
                  </button>
                </form>
              )}
            </>
          )}
          {section === "milestones" && (
            <>
              <div className="v3-section-action">
                <h2>Milestones</h2>
                {isLead && (
                  <button
                    className="cf-primary"
                    onClick={() => void addMilestone()}
                  >
                    <Plus size={16} />
                    Add
                  </button>
                )}
              </div>
              {milestones.length ? (
                <div className="v3-milestones">
                  {milestones.map((item) => (
                    <article key={item.id}>
                      <strong>{item.name}</strong>
                      <p>{item.objective || "No description yet."}</p>
                      <small>
                        {item.status} · {date(item.target_at)}
                      </small>
                    </article>
                  ))}
                </div>
              ) : (
                <State
                  icon={<Sparkles size={25} />}
                  title="No milestones yet"
                  body="Milestones turn the room's next horizon into shared context."
                />
              )}
            </>
          )}
          {section === "members" && (
            <>
              <h2>Members</h2>
              <div className="v3-members">
                {members.map((item) => (
                  <div key={item.profile_id}>
                    <span className="cf-avatar">
                      {initials(item.profile?.full_name || "?")}
                    </span>
                    <span>
                      <strong>
                        {item.profile?.full_name || "Private member"}
                      </strong>
                      <small>{item.role}</small>
                    </span>
                  </div>
                ))}
              </div>
            </>
          )}
          {section === "discussion" && (
            <>
              <h2>Discussion</h2>
              <div className="cf-chat">
                {messages.length ? (
                  messages.map((message) => (
                    <p
                      className={
                        message.sender_id === userId ? "mine" : "theirs"
                      }
                      key={message.id}
                    >
                      {message.body}
                    </p>
                  ))
                ) : (
                  <State
                    icon={<MessageCircle size={24} />}
                    title="No discussion yet"
                    body="Use this room thread to keep decisions close to the work."
                  />
                )}
              </div>
              <form className="cf-compose" onSubmit={sendMessage}>
                <input
                  value={draft}
                  onChange={(event) => setDraft(event.target.value)}
                  maxLength={4000}
                  placeholder="Write to the room"
                />
                <button aria-label="Send message">
                  <ArrowRight size={18} />
                </button>
              </form>
            </>
          )}
          {section === "notes" && (
            <>
              <div className="v3-section-action">
                <h2>Notes</h2>
                <button className="cf-primary" onClick={() => void addNote()}>
                  <Plus size={16} />
                  New note
                </button>
              </div>
              {notes.length ? (
                <div className="v3-notes">
                  {notes.map((note) => (
                    <article key={note.id}>
                      <small>{note.type}</small>
                      <h3>{note.title}</h3>
                      <p>{note.body || "No additional detail."}</p>
                    </article>
                  ))}
                </div>
              ) : (
                <State
                  icon={<FileText size={25} />}
                  title="No notes yet"
                  body="Capture decisions and useful context in the room."
                />
              )}
            </>
          )}
          {section === "files" && (
            <State
              icon={<FileText size={28} />}
              title="File storage is not configured"
              body="The room is ready for file metadata, but an authenticated Supabase Storage bucket and upload policy must be configured before uploads are enabled."
            />
          )}
          {section === "github" && (
            <State
              icon={<Github size={28} />}
              title="GitHub sync is not configured"
              body="Connect a verified server-side GitHub integration before importing repositories or showing pull request data."
            />
          )}
          {section === "settings" && (
            <>
              <h2>Room settings</h2>
              {isLead ? (
                <form
                  className="v3-form"
                  onSubmit={async (event) => {
                    event.preventDefault();
                    const result = await supabase
                      .from("cf_projects")
                      .update({
                        is_public: project.is_public,
                        collaboration_enabled: project.collaboration_enabled,
                        showcase_enabled: project.showcase_enabled ?? false,
                        showcase_pitch: project.showcase_pitch?.trim() || null,
                        demo_url: project.demo_url?.trim() || null,
                      })
                      .eq("id", project.id);
                    if (result.error) setError(result.error.message);
                    else setError("Room settings saved.");
                  }}
                >
                  <label className="cf-switch">
                    <input
                      type="checkbox"
                      checked={project.is_public}
                      onChange={(event) =>
                        setProject({
                          ...project,
                          is_public: event.target.checked,
                        })
                      }
                    />
                    <span />
                    <b>Public overview</b>
                    <small>Does not open tasks, notes, or chat.</small>
                  </label>
                  <label className="cf-switch">
                    <input
                      type="checkbox"
                      checked={project.collaboration_enabled}
                      onChange={(event) =>
                        setProject({
                          ...project,
                          collaboration_enabled: event.target.checked,
                        })
                      }
                    />
                    <span />
                    <b>Accept join requests</b>
                    <small>Pro members can request private-room access.</small>
                  </label>
                  <label className="cf-switch">
                    <input
                      type="checkbox"
                      checked={project.showcase_enabled ?? false}
                      onChange={(event) =>
                        setProject({
                          ...project,
                          showcase_enabled: event.target.checked,
                        })
                      }
                    />
                    <span />
                    <b>Present this product in Discover</b>
                    <small>
                      Your public overview and optional pitch can be ranked for
                      relevant builders. Private room work remains private.
                    </small>
                  </label>
                  {project.showcase_enabled && (
                    <>
                      <label>
                        <span>Product pitch</span>
                        <textarea
                          maxLength={500}
                          value={project.showcase_pitch ?? ""}
                          onChange={(event) =>
                            setProject({
                              ...project,
                              showcase_pitch: event.target.value,
                            })
                          }
                          placeholder="What are you presenting, and who would benefit from seeing it?"
                        />
                      </label>
                      <label>
                        <span>Demo link</span>
                        <input
                          type="url"
                          maxLength={2048}
                          value={project.demo_url ?? ""}
                          onChange={(event) =>
                            setProject({
                              ...project,
                              demo_url: event.target.value,
                            })
                          }
                          placeholder="https://your-product.example"
                        />
                      </label>
                    </>
                  )}
                  <button className="cf-primary">Save settings</button>
                </form>
              ) : (
                <State
                  icon={<Settings2 size={28} />}
                  title="Owner settings"
                  body="Only the room owner can change visibility and collaboration access."
                />
              )}
            </>
          )}
        </section>
      )}
    </Page>
  );
}
