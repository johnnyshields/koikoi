import apiClient from './client';
import type {
  SubscriptionPlan,
  CreditPackage,
  SubscriptionInfo,
  CreditTransaction,
} from '../types';

export const billingApi = {
  getPlans: () =>
    apiClient.get<{ plans: SubscriptionPlan[] }>('/billing/plans'),

  getCreditPackages: () =>
    apiClient.get<{ packages: CreditPackage[] }>('/billing/credit-packages'),

  getSubscription: () =>
    apiClient.get<{ subscription: SubscriptionInfo }>('/billing/subscription'),

  subscribe: (plan: 'basic' | 'vip') =>
    apiClient.post<{ checkout_url: string }>('/billing/subscribe', { plan }),

  cancelSubscription: () =>
    apiClient.post<{ message: string }>('/billing/cancel-subscription'),

  purchaseCredits: (pkg: 'small' | 'medium' | 'large') =>
    apiClient.post<{ checkout_url: string }>('/billing/purchase-credits', {
      package: pkg,
    }),

  getCredits: () =>
    apiClient.get<{ credits: number }>('/billing/credits'),

  getTransactions: (params: { page?: number; limit?: number; type?: string }) =>
    apiClient.get<{ transactions: CreditTransaction[] }>(
      '/billing/transactions',
      { params }
    ),
};
