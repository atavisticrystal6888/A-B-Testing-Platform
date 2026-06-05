import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { connectSocket, disconnectSocket, joinChannel } from '../lib/ws';
import { useAuth } from './AuthContext';

interface WebSocketContextType {
  connected: boolean;
  subscribeToExperiment: (experimentId: string, onUpdate: (data: unknown) => void) => () => void;
}

const WebSocketContext = createContext<WebSocketContextType>({
  connected: false,
  subscribeToExperiment: () => () => {},
});

export function WebSocketProvider({ children }: { children: ReactNode }) {
  const { token } = useAuth();
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    if (token) {
      const socket = connectSocket(token);
      socket.onOpen(() => setConnected(true));
      socket.onClose(() => setConnected(false));

      return () => {
        disconnectSocket();
        setConnected(false);
      };
    }
  }, [token]);

  const subscribeToExperiment = (experimentId: string, onUpdate: (data: unknown) => void) => {
    const channel = joinChannel(`experiment:${experimentId}`);
    if (!channel) return () => {};

    channel.on('results_updated', (data: unknown) => onUpdate(data));
    channel.on('status_changed', (data: unknown) => onUpdate(data));

    return () => {
      channel.leave();
    };
  };

  return (
    <WebSocketContext.Provider value={{ connected, subscribeToExperiment }}>
      {children}
    </WebSocketContext.Provider>
  );
}

export function useWebSocket() {
  return useContext(WebSocketContext);
}
