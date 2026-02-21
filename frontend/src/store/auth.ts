import { create } from 'zustand';
import { authApi } from '../api/auth';
import type { RegisterParams, LoginParams } from '../api/auth';
import type { User } from '../types';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;

  login: (params: LoginParams) => Promise<void>;
  register: (params: RegisterParams) => Promise<void>;
  logout: () => Promise<void>;
  fetchMe: () => Promise<void>;
  clearError: () => void;
  requestVerificationCode: (phoneNumber: string) => Promise<void>;
  verifyPhone: (phoneNumber: string, code: string) => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isAuthenticated: !!localStorage.getItem('access_token'),
  isLoading: false,
  error: null,

  login: async (params) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await authApi.login(params);
      localStorage.setItem('access_token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      set({ user: data.user, isAuthenticated: true, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Login failed';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  register: async (params) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await authApi.register(params);
      localStorage.setItem('access_token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      set({ user: data.user, isAuthenticated: true, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Registration failed';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  logout: async () => {
    try {
      await authApi.logout();
    } finally {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      set({ user: null, isAuthenticated: false });
    }
  },

  fetchMe: async () => {
    set({ isLoading: true });
    try {
      const { data } = await authApi.me();
      set({ user: data.user, isAuthenticated: true, isLoading: false });
    } catch {
      set({ user: null, isAuthenticated: false, isLoading: false });
    }
  },

  clearError: () => set({ error: null }),

  requestVerificationCode: async (phoneNumber) => {
    await authApi.requestCode(phoneNumber);
  },

  verifyPhone: async (phoneNumber, code) => {
    await authApi.verifyPhone(phoneNumber, code);
    const { data } = await authApi.me();
    set({ user: data.user });
  },
}));
