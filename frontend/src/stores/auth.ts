import { create } from "zustand";
import { api, type User } from "../lib/api";

interface AuthState {
  user: User | null;
  initialized: boolean;
  init: () => Promise<void>;
  setUser: (u: User | null) => void;
  signOut: () => Promise<void>;
}

export const useAuth = create<AuthState>((set) => ({
  user: null,
  initialized: false,
  init: async () => {
    try {
      const user = await api.me();
      set({ user, initialized: true });
    } catch {
      set({ user: null, initialized: true });
    }
  },
  setUser: (user) => set({ user }),
  signOut: async () => {
    try {
      await api.signOut();
    } finally {
      set({ user: null });
    }
  },
}));

window.addEventListener("auth:unauthorized", () => {
  useAuth.setState({ user: null });
});
