declare module 'phoenix' {
  export class Socket {
    constructor(endPoint: string, opts?: {
      params?: Record<string, string> | (() => Record<string, string>);
      timeout?: number;
      heartbeatIntervalMs?: number;
      logger?: (kind: string, msg: string, data: unknown) => void;
      encode?: (payload: object, callback: (encoded: string) => void) => void;
      decode?: (payload: string, callback: (decoded: object) => void) => void;
      reconnectAfterMs?: (tries: number) => number;
      rejoinAfterMs?: (tries: number) => number;
      vsn?: string;
    });
    connect(): void;
    disconnect(callback?: () => void, code?: number, reason?: string): void;
    channel(topic: string, chanParams?: Record<string, unknown>): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: unknown) => void): void;
    isConnected(): boolean;
  }

  export class Channel {
    join(timeout?: number): Push;
    leave(timeout?: number): Push;
    on(event: string, callback: (payload: unknown) => void): number;
    off(event: string, ref?: number): void;
    push(event: string, payload: object, timeout?: number): Push;
    onClose(callback: () => void): void;
    onError(callback: (reason: unknown) => void): void;
  }

  export class Push {
    receive(status: string, callback: (response: unknown) => void): Push;
  }
}
