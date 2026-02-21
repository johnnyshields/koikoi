import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useSocialStore } from '../../store/social';
import { useAuth } from '../../hooks/useAuth';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';

export function InvitePage() {
  const { t } = useTranslation('social');
  const { t: tc } = useTranslation('common');
  const { user } = useAuth();
  const { inviteStats, fetchInviteStats, redeemInvite } = useSocialStore();
  const [redeemCode, setRedeemCode] = useState('');
  const [isRedeeming, setIsRedeeming] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchInviteStats().finally(() => setIsLoading(false));
  }, [fetchInviteStats]);

  const inviteCode = inviteStats?.invite_code || user?.invite_code || '';

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(inviteCode);
      toast(t('invite.copied'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleShare = async () => {
    const shareUrl = `${window.location.origin}/register?invite=${inviteCode}`;
    if (navigator.share) {
      try {
        await navigator.share({ title: tc('appName'), url: shareUrl });
      } catch {
        // User cancelled share
      }
    } else {
      await navigator.clipboard.writeText(shareUrl);
      toast(t('invite.copied'), 'success');
    }
  };

  const handleRedeem = async () => {
    const code = redeemCode.trim();
    if (!code) return;
    setIsRedeeming(true);
    try {
      await redeemInvite(code);
      setRedeemCode('');
      toast(t('pending.accept'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    } finally {
      setIsRedeeming(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-4">
      <h1 className="text-xl font-bold text-gray-900">{t('invite.title')}</h1>

      {/* Invite code */}
      <Card>
        <h2 className="mb-3 text-base font-semibold text-gray-800">
          {t('invite.yourCode')}
        </h2>
        <div className="mb-3 flex items-center gap-2 rounded-lg bg-gray-50 px-4 py-3">
          <span className="flex-1 font-mono text-lg font-bold tracking-wider text-gray-900">
            {inviteCode}
          </span>
          <button
            type="button"
            onClick={handleCopy}
            className="rounded-full p-2 text-gray-500 hover:bg-gray-200 hover:text-gray-700"
            title={t('invite.copy')}
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
          </button>
        </div>
        <div className="flex gap-2">
          <Button fullWidth variant="outline" onClick={handleCopy}>
            {t('invite.copy')}
          </Button>
          <Button fullWidth onClick={handleShare}>
            {t('invite.share')}
          </Button>
        </div>
      </Card>

      {/* Redeem code */}
      <Card>
        <h2 className="mb-3 text-base font-semibold text-gray-800">
          {t('invite.redeem')}
        </h2>
        <div className="flex gap-2">
          <Input
            value={redeemCode}
            onChange={(e) => setRedeemCode(e.target.value)}
            placeholder={t('invite.redeemPlaceholder')}
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleRedeem();
            }}
          />
          <Button
            onClick={handleRedeem}
            isLoading={isRedeeming}
            disabled={!redeemCode.trim()}
            className="shrink-0"
          >
            {t('invite.redeemButton')}
          </Button>
        </div>
      </Card>

      {/* Stats */}
      {inviteStats && (
        <Card>
          <h2 className="mb-2 text-base font-semibold text-gray-800">
            {t('invite.stats')}
          </h2>
          <p className="text-sm text-gray-600">
            {t('invite.sent', { count: inviteStats.invites_sent })}
          </p>
        </Card>
      )}
    </div>
  );
}
