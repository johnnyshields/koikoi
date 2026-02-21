import apiClient from './client';
import type { User } from '../types';

export interface RegisterParams {
  phone_number: string;
  password: string;
  gender: 'male' | 'female' | 'other';
  date_of_birth: string;
}

export interface LoginParams {
  phone_number: string;
  password: string;
}

export interface AuthResponse {
  user: User;
  access_token: string;
  refresh_token: string;
}

export const authApi = {
  register: (params: RegisterParams) =>
    apiClient.post<AuthResponse>('/auth/register', params),

  login: (params: LoginParams) =>
    apiClient.post<AuthResponse>('/auth/login', params),

  refresh: (refreshToken: string) =>
    apiClient.post<{ access_token: string; refresh_token: string }>(
      '/auth/refresh',
      { refresh_token: refreshToken }
    ),

  requestCode: (phoneNumber: string) =>
    apiClient.post('/auth/request-code', { phone_number: phoneNumber }),

  verifyPhone: (phoneNumber: string, code: string) =>
    apiClient.post('/auth/verify-phone', { phone_number: phoneNumber, code }),

  me: () => apiClient.get<{ user: User }>('/auth/me'),

  logout: () => apiClient.post('/auth/logout'),
};
