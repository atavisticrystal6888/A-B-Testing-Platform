declare module 'phoenix' {
  export class Push {
    receive(event: string, callback: (payload?: unknown) => void): Push;
  }

  export class Channel {
    join(): Push;
    on(event: string, callback: (payload: unknown) => void): void;
    leave(): void;
  }

  export class Socket {
    constructor(endpoint: string, opts?: { params?: Record<string, unknown> });
    connect(): void;
    disconnect(): void;
    isConnected(): boolean;
    channel(topic: string, params?: Record<string, unknown>): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
  }
}
