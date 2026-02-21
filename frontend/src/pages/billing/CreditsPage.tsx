import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useBillingStore } from '../../store/billing';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';
import type { CreditTransaction } from '../../types';

type TabFilter = 'all' | 'purchase' | 'spend' | 'bonus';

const TAB_FILTERS: { key: TabFilter; i18nKey: string }[] = [
  { key: 'all', i18nKey: 'all' },
  { key: 'purchase', i18nKey: 'purchase' },
  { key: 'spend', i18nKey: 'spend' },
  { key: 'bonus', i18nKey: 'bonus' },
];

function TransactionIcon({ type }: { type: CreditTransaction['type'] }) {
  if (type === 'purchase' || type === 'bonus') {
    return (
      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-green-100">
        <svg
          className="h-4 w-4 text-green-600"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M12 4v16m8-8H4"
          />
        </svg>
      </div>
    );
  }
  if (type === 'refund') {
    return (
      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100">
        <svg
          className="h-4 w-4 text-blue-600"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M3 10h10a5 5 0 010 10H9m-6-6l3-3m0 0l3 3m-3-3v8"
          />
        </svg>
      </div>
    );
  }
  return (
    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-red-100">
      <svg
        className="h-4 w-4 text-red-600"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M20 12H4"
        />
      </svg>
    </div>
  );
}

function TransactionRow({
  tx,
  lang,
}: {
  tx: CreditTransaction;
  lang: string;
}) {
  const isPositive = tx.amount > 0;
  return (
    <div className="flex items-center gap-3 py-3">
      <TransactionIcon type={tx.type} />
      <div className="flex-1 min-w-0">
        <p className="truncate text-sm font-medium text-gray-900">
          {tx.description}
        </p>
        <p className="text-xs text-gray-500">
          {new Date(tx.inserted_at).toLocaleDateString(
            lang === 'ja' ? 'ja-JP' : 'en-US',
            { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }
          )}
        </p>
      </div>
      <div className="text-right">
        <p
          className={`text-sm font-bold ${
            isPositive ? 'text-green-600' : 'text-red-600'
          }`}
        >
          {isPositive ? '+' : ''}
          {tx.amount}
        </p>
        <p className="text-xs text-gray-400">{tx.balance_after}</p>
      </div>
    </div>
  );
}

export function CreditsPage() {
  const { t } = useTranslation('billing');
  const { i18n } = useTranslation();
  const lang = i18n.language?.startsWith('en') ? 'en' : 'ja';
  const {
    creditPackages,
    creditBalance,
    transactions,
    isLoading,
    fetchPackages,
    fetchCredits,
    fetchTransactions,
    purchaseCredits,
  } = useBillingStore();
  const [activeTab, setActiveTab] = useState<TabFilter>('all');

  useEffect(() => {
    fetchPackages();
    fetchCredits();
    fetchTransactions();
  }, [fetchPackages, fetchCredits, fetchTransactions]);

  const handlePurchase = async (pkg: 'small' | 'medium' | 'large') => {
    try {
      const checkoutUrl = await purchaseCredits(pkg);
      window.location.href = checkoutUrl;
    } catch {
      toast(t('common:errors.generic'), 'error');
    }
  };

  const filteredTransactions =
    activeTab === 'all'
      ? transactions
      : transactions.filter((tx) => tx.type === activeTab);

  if (isLoading && creditPackages.length === 0) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-4">
      <h1 className="text-xl font-bold text-gray-900">{t('credits')}</h1>

      {/* Credit balance */}
      <Card>
        <div className="flex items-center justify-center gap-3 py-2">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-amber-100">
            <svg
              className="h-6 w-6 text-amber-500"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="12" r="10" />
              <text
                x="12"
                y="16"
                textAnchor="middle"
                fontSize="10"
                fill="white"
                fontWeight="bold"
              >
                C
              </text>
            </svg>
          </div>
          <div>
            <p className="text-sm text-gray-500">{t('credit_balance')}</p>
            <p className="text-3xl font-bold text-gray-900">
              {creditBalance.toLocaleString()}
            </p>
          </div>
        </div>
      </Card>

      {/* Credit packages */}
      <h2 className="text-lg font-bold text-gray-900">{t('buy_credits')}</h2>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {creditPackages.map((pkg) => {
          const perCredit = Math.round(pkg.price_jpy / pkg.credits);
          const name = lang === 'ja' ? pkg.name_ja : pkg.name_en;
          return (
            <Card
              key={pkg.id}
              padding="sm"
              className={`relative ${
                pkg.popular ? 'ring-2 ring-rose-500' : ''
              } ${pkg.best_value ? 'ring-2 ring-amber-500' : ''}`}
            >
              {pkg.popular && (
                <span className="absolute -top-2.5 left-1/2 -translate-x-1/2 rounded-full bg-rose-500 px-3 py-0.5 text-xs font-bold text-white">
                  {t('popular')}
                </span>
              )}
              {pkg.best_value && (
                <span className="absolute -top-2.5 left-1/2 -translate-x-1/2 rounded-full bg-amber-500 px-3 py-0.5 text-xs font-bold text-white">
                  {t('best_value')}
                </span>
              )}
              <div className="pt-2 text-center">
                <p className="text-sm font-medium text-gray-600">{name}</p>
                <p className="mt-1 text-2xl font-bold text-gray-900">
                  {pkg.credits.toLocaleString()}
                </p>
                <p className="text-xs text-gray-500">{t('credits')}</p>
                <p className="mt-2 text-lg font-bold text-gray-900">
                  ¥{pkg.price_jpy.toLocaleString()}
                </p>
                <p className="text-xs text-gray-400">
                  {t('per_credit', { price: perCredit })}
                </p>
                <Button
                  fullWidth
                  size="sm"
                  variant={pkg.popular ? 'primary' : 'secondary'}
                  className="mt-3"
                  isLoading={isLoading}
                  onClick={() => handlePurchase(pkg.id as 'small' | 'medium' | 'large')}
                >
                  {t('buy_credits')}
                </Button>
              </div>
            </Card>
          );
        })}
      </div>

      {/* Transaction history */}
      <h2 className="text-lg font-bold text-gray-900">{t('transactions')}</h2>

      {/* Filter tabs */}
      <div className="flex gap-2">
        {TAB_FILTERS.map(({ key, i18nKey }) => (
          <button
            key={key}
            className={`rounded-full px-3 py-1 text-sm font-medium transition-colors ${
              activeTab === key
                ? 'bg-rose-500 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            onClick={() => setActiveTab(key)}
          >
            {t(i18nKey)}
          </button>
        ))}
      </div>

      <Card padding="sm">
        {filteredTransactions.length === 0 ? (
          <p className="py-6 text-center text-sm text-gray-400">
            {t('no_transactions')}
          </p>
        ) : (
          <div className="divide-y divide-gray-100">
            {filteredTransactions.map((tx) => (
              <TransactionRow key={tx.id} tx={tx} lang={lang} />
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
