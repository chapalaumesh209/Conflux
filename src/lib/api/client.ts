import type { ApiProblem } from "./contracts";

export class ConfluxApiError extends Error {
  readonly problem: ApiProblem;

  constructor(problem: ApiProblem) {
    super(problem.detail ?? problem.title);
    this.name = "ConfluxApiError";
    this.problem = problem;
  }
}

type RequestOptions = Omit<RequestInit, "body"> & {
  body?: unknown;
};

/**
 * The single boundary for browser-to-service calls. Future phase clients use
 * this instead of embedding fetch calls in screens, so errors and trace ids
 * remain consistent and observable.
 */
export class ConfluxApiClient {
  constructor(private readonly baseUrl = process.env.NEXT_PUBLIC_CONFLUX_API_URL ?? "") {}

  async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const headers = new Headers(options.headers);
    headers.set("Accept", "application/json");
    if (options.body !== undefined) headers.set("Content-Type", "application/json");

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...options,
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      credentials: "include",
    });

    if (!response.ok) {
      const fallback: ApiProblem = {
        status: response.status,
        title: "Request failed",
        traceId: response.headers.get("X-Request-Id") ?? undefined,
      };
      const problem = await response.json().catch(() => fallback) as ApiProblem;
      throw new ConfluxApiError({ ...fallback, ...problem, traceId: problem.traceId ?? fallback.traceId });
    }

    return response.json() as Promise<T>;
  }
}

export const apiClient = new ConfluxApiClient();
