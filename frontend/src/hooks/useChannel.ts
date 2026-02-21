import type { Channel } from 'phoenix';
import { useSocket } from './useSocket';
import { useEffect, useRef, useCallback } from 'react';

export function useChannel(
  topic: string | null,
  onEvent?: Record<string, (payload: unknown) => void>,
) {
  const { getSocket } = useSocket();
  const channelRef = useRef<Channel | null>(null);

  useEffect(() => {
    const socket = getSocket();
    if (!socket || !topic) return;

    const channel = socket.channel(topic);
    channelRef.current = channel;

    channel
      .join()
      .receive('ok', () => {})
      .receive('error', (resp) =>
        console.error('Failed to join', topic, resp),
      );

    if (onEvent) {
      Object.entries(onEvent).forEach(([event, handler]) => {
        channel.on(event, handler);
      });
    }

    return () => {
      channel.leave();
      channelRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [topic]);

  const push = useCallback((event: string, payload: object) => {
    return channelRef.current?.push(event, payload);
  }, []);

  return { channel: channelRef, push };
}
