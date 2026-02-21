import { Socket } from 'phoenix';

let socket: Socket | null = null;

export function useSocket() {
  const getSocket = () => {
    if (!socket) {
      const token = localStorage.getItem('access_token');
      if (!token) return null;

      socket = new Socket('/socket', {
        params: { token },
      });
      socket.connect();
    }
    return socket;
  };

  const disconnect = () => {
    if (socket) {
      socket.disconnect();
      socket = null;
    }
  };

  return { getSocket, disconnect };
}
