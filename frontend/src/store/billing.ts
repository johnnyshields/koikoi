import { create } from 'zustand';
import { billingApi } from '../api/billing';
import type {
  SubscriptionPlan,
  CreditPackage,
  SubscriptionInfo,
  CreditTransaction,
} from '../types';

interface BillingState {
  plans: SubscriptionPlan[];
  creditPackages: CreditPackage[];
  subscription: SubscriptionInfo | null;
  creditBalance: number;
  transactions: CreditTransaction[];
  isLoading: boolean;
  error: string | null;

  fetchPlans: () => Promise<void>;
  fetchPackages: () => Promise<void>;
  fetchSubscription: () => Promise<void>;
  subscribe: (plan: 'basic' | 'vip') => Promise<string>;
  cancelSubscription: () => Promise<void>;
  purchaseCredits: (pkg: 'small' | 'medium' | 'large') => Promise<string>;
  fetchCredits: () => Promise<void>;
  fetchTransactions: (params?: {
    page?: number;
    limit?: number;
    type?: string;
  }) => Promise<void>;
  clearError: () => void;
}

export const useBillingStore = create<BillingState>((set) => ({
  plans: [],
  creditPackages: [],
  subscription: null,
  creditBalance: 0,
  transactions: [],
  isLoading: false,
  error: null,

  fetchPlans: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await billingApi.getPlans();
      set({ plans: data.plans, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch plans';
      set({ error: message, isLoading: false });
    }
  },

  fetchPackages: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await billingApi.getCreditPackages();
      set({ creditPackages: data.packages, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch packages';
      set({ error: message, isLoading: false });
    }
  },

  fetchSubscription: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await billingApi.getSubscription();
      set({ subscription: data.subscription, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch subscription';
      set({ error: message, isLoading: false });
    }
  },

  subscribe: async (plan) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await billingApi.subscribe(plan);
      set({ isLoading: false });
      return data.checkout_url;
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to subscribe';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  cancelSubscription: async () => {
    set({ isLoading: true, error: null });
    try {
      await billingApi.cancelSubscription();
      set((state) => ({
        subscription: state.subscription
          ? { ...state.subscription, is_active: false }
          : null,
        isLoading: false,
      }));
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to cancel subscription';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  purchaseCredits: async (pkg) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await billingApi.purchaseCredits(pkg);
      set({ isLoading: false });
      return data.checkout_url;
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to purchase credits';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  fetchCredits: async () => {
    try {
      const { data } = await billingApi.getCredits();
      set({ creditBalance: data.credits });
    } catch {
      // silent fail for balance refresh
    }
  },

  fetchTransactions: async (params) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await billingApi.getTransactions(params || {});
      set({ transactions: data.transactions, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch transactions';
      set({ error: message, isLoading: false });
    }
  },

  clearError: () => set({ error: null }),
}));
