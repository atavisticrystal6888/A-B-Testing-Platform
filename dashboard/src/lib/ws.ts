import { Socket, Channel } from 'phoenix';
import { getWebSocketUrl } from './api';

const WS_URL = getWebSocketUrl();

let socket: Socket | null = null;
let socketToken: string | null = null;
let consumerCount = 0;
let disconnectTimer: ReturnType<typeof setTimeout> | null = null;

export function connectSocket(token: string): Socket {
  consumerCount += 1;

  if (disconnectTimer) {
    clearTimeout(disconnectTimer);
    disconnectTimer = null;
  }

  if (socket && socketToken === token) return socket;

  if (socket) {
    socket.disconnect();
    socket = null;
  }

  socket = new Socket(WS_URL, {
    params: { token },
  });
  socketToken = token;

  socket.connect();
  return socket;
}

export function disconnectSocket(): void {
  consumerCount = Math.max(consumerCount - 1, 0);

  if (!socket || consumerCount > 0 || disconnectTimer) return;

  // Delay final disconnect long enough to absorb React.StrictMode remounts in dev.
  disconnectTimer = setTimeout(() => {
    if (socket && consumerCount === 0) {
      socket.disconnect();
      socket = null;
      socketToken = null;
    }

    disconnectTimer = null;
  }, 0);
}

export function joinChannel(topic: string): Channel | null {
  if (!socket) return null;

  const channel = socket.channel(topic, {});
  channel.join()
    .receive('ok', () => console.log(`Joined ${topic}`))
    .receive('error', (reason: unknown) => console.error(`Failed to join ${topic}:`, reason));

  return channel;
}

export function getSocket(): Socket | null {
  return socket;
}
