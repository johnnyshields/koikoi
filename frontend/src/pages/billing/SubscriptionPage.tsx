import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useBillingStore } from '../../store/billing';
import { useAuthStore } from '../../store/auth';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';
import type { SubscriptionPlan } from '../../types';

function formatPrice(price: number): string {
  return price === 0 ? '' : `¥${price.toLocaleString()}`;
}

function PlanCard({
  plan,
  currentPlan,
  isVip,
  isLoading,
  onSubscribe,
  t,
  lang,
}: {
  plan: SubscriptionPlan;
  currentPlan: string;
  isVip: boolean;
  isLoading: boolean;
  onSubscribe: (planId: 'basic' | 'vip') => void;
  t: (key: string, options?: Record<string, unknown>) => string;
  lang: string;
}) {
  const isCurrent = plan.id === currentPlan;
  const name = lang === 'ja' ? plan.name_ja : plan.name_en;
  const features = lang === 'ja' ? plan.features_ja : plan.features_en;

  return (
    <Card
      padding="none"
      className={`flex flex-col overflow-hidden ${
        isVip ? 'ring-2 ring-rose-500' : ''
      }`}
    >
      {isVip && (
        <div className="bg-rose-500 px-3 py-1 text-center text-xs font-bold text-white">
          {t('recommended')}
        </div>
      )}
      <div className="flex flex-1 flex-col p-4">
        <h3 className="text-lg font-bold text-gray-900">{name}</h3>
        <div className="mt-2">
          {plan.price_jpy === 0 ? (
            <span className="text-2xl font-bold text-gray-900">
              {t('price_free')}
            </span>
          ) : (
            <>
              <span className="text-2xl font-bold text-gray-900">
                {formatPrice(plan.price_jpy)}
              </span>
              <span className="text-sm text-gray-500">{t('per_month')}</span>
            </>
          )}
        </div>
        <ul className="mt-4 flex-1 space-y-2">
          {features.map((feature, i) => (
            <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
              <svg
                className="mt-0.5 h-4 w-4 shrink-0 text-rose-500"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M5 13l4 4L19 7"
                />
              </svg>
              {feature}
            </li>
          ))}
        </ul>
        <div className="mt-4">
          {isCurrent ? (
            <div className="rounded-lg bg-gray-100 py-2 text-center text-sm font-medium text-gray-600">
              {t('current')}
            </div>
          ) : plan.price_jpy > 0 ? (
            <Button
              fullWidth
              variant={isVip ? 'primary' : 'secondary'}
              isLoading={isLoading}
              onClick={() => onSubscribe(plan.id as 'basic' | 'vip')}
            >
              {currentPlan === 'free' ? t('subscribe') : t('upgrade')}
            </Button>
          ) : null}
        </div>
      </div>
    </Card>
  );
}

export function SubscriptionPage() {
  const { t } = useTranslation('billing');
  const { i18n } = useTranslation();
  const lang = i18n.language?.startsWith('en') ? 'en' : 'ja';
  const user = useAuthStore((s) => s.user);
  const {
    plans,
    subscription,
    isLoading,
    fetchPlans,
    fetchSubscription,
    subscribe,
    cancelSubscription,
  } = useBillingStore();
  const [showCancelModal, setShowCancelModal] = useState(false);
  const [cancelling, setCancelling] = useState(false);

  useEffect(() => {
    fetchPlans();
    fetchSubscription();
  }, [fetchPlans, fetchSubscription]);

  const currentPlan = subscription?.plan || 'free';
  const isWoman = user?.gender === 'female';

  const handleSubscribe = async (plan: 'basic' | 'vip') => {
    try {
      const checkoutUrl = await subscribe(plan);
      window.location.href = checkoutUrl;
    } catch {
      toast(t('common:errors.generic'), 'error');
    }
  };

  const handleCancel = async () => {
    setCancelling(true);
    try {
      await cancelSubscription();
      setShowCancelModal(false);
      toast(t('cancel_subscription'), 'success');
    } catch {
      toast(t('common:errors.generic'), 'error');
    } finally {
      setCancelling(false);
    }
  };

  if (isLoading && plans.length === 0) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  // Build display plans: always show free + fetched plans
  const freePlan: SubscriptionPlan = {
    id: 'free',
    name_ja: '無料プラン',
    name_en: 'Free Plan',
    price_jpy: 0,
    features_ja: ['プロフィール作成', '基本マッチング', '1日のいいね数制限あり'],
    features_en: [
      'Create profile',
      'Basic matching',
      'Limited daily likes',
    ],
  };
  const displayPlans = [freePlan, ...plans];

  return (
    <div className="space-y-4 pb-4">
      <h1 className="text-xl font-bold text-gray-900">{t('subscription')}</h1>

      {/* Women free banner */}
      {isWoman && (
        <div className="rounded-lg bg-pink-50 px-4 py-3 text-center text-sm font-medium text-pink-700">
          {t('women_free')}
        </div>
      )}

      {/* Current subscription status */}
      {subscription && currentPlan !== 'free' && (
        <Card>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">{t('current_plan')}</p>
              <p className="text-lg font-bold text-gray-900">
                {currentPlan === 'vip' ? t('vip_plan') : t('basic_plan')}
              </p>
              {subscription.expires_at && (
                <p className="text-xs text-gray-500">
                  {t('expires_at', {
                    date: new Date(subscription.expires_at).toLocaleDateString(
                      lang === 'ja' ? 'ja-JP' : 'en-US'
                    ),
                  })}
                </p>
              )}
            </div>
            {subscription.is_active && (
              <span className="rounded-full bg-green-100 px-3 py-1 text-xs font-medium text-green-700">
                {t('active')}
              </span>
            )}
            {!subscription.is_active && (
              <span className="rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-600">
                {t('expired')}
              </span>
            )}
          </div>
        </Card>
      )}

      {/* Plan cards */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {displayPlans.map((plan) => (
          <PlanCard
            key={plan.id}
            plan={plan}
            currentPlan={currentPlan}
            isVip={plan.id === 'vip'}
            isLoading={isLoading}
            onSubscribe={handleSubscribe}
            t={t}
            lang={lang}
          />
        ))}
      </div>

      {/* Cancel subscription */}
      {subscription?.is_active && currentPlan !== 'free' && (
        <div className="text-center">
          <button
            className="text-sm text-gray-400 underline hover:text-gray-600"
            onClick={() => setShowCancelModal(true)}
          >
            {t('cancel_subscription')}
          </button>
        </div>
      )}

      {/* Cancel confirmation modal */}
      <Modal
        isOpen={showCancelModal}
        onClose={() => setShowCancelModal(false)}
        title={t('cancel_subscription')}
      >
        <p className="mb-6 text-sm text-gray-600">{t('cancel_confirm')}</p>
        <div className="flex gap-3">
          <Button
            variant="outline"
            fullWidth
            onClick={() => setShowCancelModal(false)}
          >
            {t('common:actions.cancel')}
          </Button>
          <Button
            variant="danger"
            fullWidth
            isLoading={cancelling}
            onClick={handleCancel}
          >
            {t('cancel_subscription')}
          </Button>
        </div>
      </Modal>
    </div>
  );
}
