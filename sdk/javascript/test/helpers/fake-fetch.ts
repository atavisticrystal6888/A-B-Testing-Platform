export interface RecordedRequest {
  url: string;
  method: string;
  /** Lower-cased header names. */
  headers: Record<string, string>;
  body: unknown;
  signal: AbortSignal | undefined;
}

export interface ScriptedResponse {
  status?: number;
  headers?: Record<string, string>;
  /** Objects are JSON-encoded; strings are sent verbatim; undefined sends an empty body. */
  body?: unknown;
  /** Resolve only after this many ms (aborts early if the signal fires). */
  delayMs?: number;
  /**
   * Headers resolve immediately; the body stream only delivers after this many ms
   * (and errors with the signal's reason if the signal fires first).
   */
  bodyDelayMs?: number;
}

/**
 * A `fetch` stand-in that records every request and replies with the scripted
 * responses in order. Once the script runs out it replies `200 {}`.
 */
export function fakeFetch(...script: ScriptedResponse[]) {
  const requests: RecordedRequest[] = [];
  const queue = [...script];

  const fetch: typeof globalThis.fetch = async (input, init) => {
    const planned = queue.shift() ?? { status: 200, body: {} };
    const headers: Record<string, string> = {};
    new Headers(init?.headers).forEach((value, key) => {
      headers[key.toLowerCase()] = value;
    });
    requests.push({
      url: typeof input === "string" ? input : input instanceof URL ? input.href : input.url,
      method: init?.method ?? "GET",
      headers,
      body: typeof init?.body === "string" && init.body.length > 0 ? JSON.parse(init.body) : undefined,
      signal: init?.signal ?? undefined,
    });

    if (planned.delayMs) {
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(resolve, planned.delayMs);
        init?.signal?.addEventListener(
          "abort",
          () => {
            clearTimeout(timer);
            reject(init?.signal?.reason ?? new DOMException("The operation was aborted.", "AbortError"));
          },
          { once: true },
        );
      });
    }

    const body =
      planned.body === undefined
        ? ""
        : typeof planned.body === "string"
          ? planned.body
          : JSON.stringify(planned.body);
    if (planned.bodyDelayMs) {
      const encoded = new TextEncoder().encode(body);
      const delay = planned.bodyDelayMs;
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          const timer = setTimeout(() => {
            controller.enqueue(encoded);
            controller.close();
          }, delay);
          init?.signal?.addEventListener(
            "abort",
            () => {
              clearTimeout(timer);
              controller.error(init.signal?.reason ?? new DOMException("The operation was aborted.", "AbortError"));
            },
            { once: true },
          );
        },
      });
      return new Response(stream, {
        status: planned.status ?? 200,
        headers: { "content-type": "application/json", ...planned.headers },
      });
    }
    return new Response(body, {
      status: planned.status ?? 200,
      headers: { "content-type": "application/json", ...planned.headers },
    });
  };

  return { fetch, requests };
}
