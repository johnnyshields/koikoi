import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfileStore } from '../../store/profile';
import { useAuthStore } from '../../store/auth';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { CompletenessBar } from '../../components/profile/CompletenessBar';

export function MyProfilePage() {
  const { t } = useTranslation('profile');
  const { t: tc } = useTranslation('common');
  const { t: tb } = useTranslation('billing');
  const navigate = useNavigate();
  const { profile, isLoading, fetchProfile } = useProfileStore();
  const user = useAuthStore((s) => s.user);

  useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);

  if (isLoading && !profile) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="space-y-4">
        <Card>
          <div className="py-8 text-center">
            <p className="mb-4 text-gray-600">{t('noProfile')}</p>
            <Button onClick={() => navigate('/profile/edit')}>
              {t('createProfile')}
            </Button>
          </div>
        </Card>
      </div>
    );
  }

  const primaryPhoto = profile.photos.find((p) => p.is_primary) || profile.photos[0];

  return (
    <div className="space-y-4 pb-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-900">{t('myProfile')}</h1>
        <Button variant="outline" size="sm" onClick={() => navigate('/profile/edit')}>
          {tc('actions.edit')}
        </Button>
      </div>

      <CompletenessBar percentage={profile.profile_completeness} />

      {/* Main card with photo + basic info */}
      <Card>
        <div className="flex items-center gap-4">
          <Avatar
            src={primaryPhoto?.thumbnail_url || primaryPhoto?.url}
            name={profile.nickname}
            size="xl"
          />
          <div className="flex-1">
            <h2 className="text-lg font-semibold text-gray-900">{profile.nickname}</h2>
            {profile.location?.prefecture && (
              <p className="text-sm text-gray-500">
                {profile.location.prefecture}
                {profile.location.city ? ` ${profile.location.city}` : ''}
              </p>
            )}
            {profile.hometown && (
              <p className="text-xs text-gray-400">
                {t('fields.hometown')}: {profile.hometown}
              </p>
            )}
          </div>
        </div>
      </Card>

      {/* Photos */}
      {profile.photos.length > 0 && (
        <Card padding="sm">
          <div className="grid grid-cols-3 gap-1">
            {[...profile.photos]
              .sort((a, b) => a.order - b.order)
              .map((photo) => (
                <div key={photo.id} className="relative aspect-square overflow-hidden rounded-lg">
                  <img
                    src={photo.thumbnail_url || photo.url}
                    alt=""
                    className="h-full w-full object-cover"
                  />
                  {photo.is_primary && (
                    <div className="absolute top-1 left-1 rounded-full bg-rose-500 px-1.5 py-0.5 text-[10px] font-medium text-white">
                      {t('photos.primary')}
                    </div>
                  )}
                </div>
              ))}
          </div>
        </Card>
      )}

      {/* Bio */}
      {profile.bio && (
        <Card>
          <h3 className="mb-2 text-sm font-medium text-gray-500">{t('fields.bio')}</h3>
          <p className="whitespace-pre-wrap text-gray-900">{profile.bio}</p>
        </Card>
      )}

      {/* Personality */}
      {profile.personality && (
        <Card>
          <h3 className="mb-2 text-sm font-medium text-gray-500">{t('fields.personality')}</h3>
          <p className="whitespace-pre-wrap text-gray-900">{profile.personality}</p>
        </Card>
      )}

      {/* Physical */}
      {(profile.physical?.height_cm || profile.physical?.body_type || profile.physical?.blood_type) && (
        <Card>
          <div className="grid grid-cols-3 gap-4 text-center">
            {profile.physical.height_cm && (
              <div>
                <p className="text-xs text-gray-500">{t('fields.heightCm')}</p>
                <p className="font-medium text-gray-900">{profile.physical.height_cm}cm</p>
              </div>
            )}
            {profile.physical.body_type && (
              <div>
                <p className="text-xs text-gray-500">{t('fields.bodyType')}</p>
                <p className="font-medium text-gray-900">
                  {t(`options.bodyType.${profile.physical.body_type}`)}
                </p>
              </div>
            )}
            {profile.physical.blood_type && (
              <div>
                <p className="text-xs text-gray-500">{t('fields.bloodType')}</p>
                <p className="font-medium text-gray-900">
                  {t(`options.bloodType.${profile.physical.blood_type}`)}
                </p>
              </div>
            )}
          </div>
        </Card>
      )}

      {/* Career & Lifestyle */}
      {(profile.career?.occupation || profile.career?.education || profile.career?.income_range ||
        profile.lifestyle?.drinking || profile.lifestyle?.smoking) && (
        <Card>
          <div className="space-y-2">
            {profile.career?.occupation && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.occupation')}</span>
                <span className="text-sm font-medium text-gray-900">{profile.career.occupation}</span>
              </div>
            )}
            {profile.career?.education && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.education')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {t(`options.education.${profile.career.education}`)}
                </span>
              </div>
            )}
            {profile.career?.income_range && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.incomeRange')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {t(`options.incomeRange.${profile.career.income_range}`)}
                </span>
              </div>
            )}
            {profile.lifestyle?.drinking && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.drinking')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {t(`options.drinking.${profile.lifestyle.drinking}`)}
                </span>
              </div>
            )}
            {profile.lifestyle?.smoking && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.smoking')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {t(`options.smoking.${profile.lifestyle.smoking}`)}
                </span>
              </div>
            )}
          </div>
        </Card>
      )}

      {/* Relationship */}
      {(profile.relationship?.marriage_intent || profile.relationship?.wants_children) && (
        <Card>
          <div className="space-y-2">
            {profile.relationship.marriage_intent && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.marriageIntent')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {t(`options.marriageIntent.${profile.relationship.marriage_intent}`)}
                </span>
              </div>
            )}
            {profile.relationship.has_children !== null && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.hasChildren')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {profile.relationship.has_children ? 'Yes' : 'No'}
                </span>
              </div>
            )}
            {profile.relationship.wants_children && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">{t('fields.wantsChildren')}</span>
                <span className="text-sm font-medium text-gray-900">
                  {t(`options.wantsChildren.${profile.relationship.wants_children}`)}
                </span>
              </div>
            )}
          </div>
        </Card>
      )}

      {/* Tags */}
      {profile.tags.length > 0 && (
        <Card>
          <h3 className="mb-2 text-sm font-medium text-gray-500">{t('tags.title')}</h3>
          <div className="flex flex-wrap gap-2">
            {profile.tags.map((tag) => (
              <span
                key={`${tag.category}-${tag.value}`}
                className="rounded-full bg-rose-50 px-3 py-1 text-sm text-rose-700"
              >
                {tag.value}
              </span>
            ))}
          </div>
        </Card>
      )}

      {/* Account & Billing */}
      <Card>
        <h3 className="mb-3 text-sm font-medium text-gray-500">{tc('nav.settings')}</h3>
        <div className="space-y-2">
          <button
            className="flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left hover:bg-gray-50 transition-colors"
            onClick={() => navigate('/subscription')}
          >
            <div className="flex items-center gap-3">
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-rose-100">
                <svg className="h-4 w-4 text-rose-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z" />
                </svg>
              </div>
              <div>
                <p className="text-sm font-medium text-gray-900">{tb('go_to_subscription')}</p>
                <p className="text-xs text-gray-500">
                  {user?.subscription?.plan === 'free' || !user?.subscription?.plan
                    ? tb('free_plan')
                    : user.subscription.plan === 'vip'
                      ? tb('vip_plan')
                      : tb('basic_plan')}
                </p>
              </div>
            </div>
            <svg className="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </button>
          <button
            className="flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left hover:bg-gray-50 transition-colors"
            onClick={() => navigate('/credits')}
          >
            <div className="flex items-center gap-3">
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-100">
                <svg className="h-4 w-4 text-amber-600" fill="currentColor" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="10" />
                </svg>
              </div>
              <div>
                <p className="text-sm font-medium text-gray-900">{tb('go_to_credits')}</p>
                <p className="text-xs text-gray-500">
                  {(user?.credits ?? 0).toLocaleString()} {tb('credits')}
                </p>
              </div>
            </div>
            <svg className="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </Card>

      {/* Member since */}
      <p className="text-center text-xs text-gray-400">
        {t('memberSince', {
          date: new Date(profile.inserted_at).toLocaleDateString(),
        })}
      </p>
    </div>
  );
}
