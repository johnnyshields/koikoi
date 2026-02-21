import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { profileApi } from '../../api/profile';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import type { Profile } from '../../types';

export function ProfileViewPage() {
  const { t } = useTranslation('profile');
  const { t: tc } = useTranslation('common');
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activePhotoIndex, setActivePhotoIndex] = useState(0);

  useEffect(() => {
    if (!userId) return;
    setIsLoading(true);
    profileApi
      .getProfile(userId)
      .then(({ data }) => {
        setProfile(data.profile);
        setIsLoading(false);
      })
      .catch((err) => {
        setError(
          (err as { response?: { data?: { error?: string } } }).response?.data
            ?.error || tc('errors.generic')
        );
        setIsLoading(false);
      });
  }, [userId, tc]);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (error || !profile) {
    return (
      <Card>
        <div className="py-8 text-center">
          <p className="mb-4 text-gray-600">{error || tc('errors.notFound')}</p>
          <Button variant="outline" onClick={() => navigate(-1)}>
            {tc('actions.back')}
          </Button>
        </div>
      </Card>
    );
  }

  const primaryPhoto = profile.photos.find((p) => p.is_primary) || profile.photos[0];
  const sortedPhotos = [...profile.photos].sort((a, b) => a.order - b.order);

  return (
    <div className="space-y-4 pb-4">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => navigate(-1)}
          className="rounded-full p-2 text-gray-500 hover:bg-gray-100"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clipRule="evenodd" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">{t('viewProfile')}</h1>
      </div>

      {/* Photo carousel */}
      {sortedPhotos.length > 0 && (
        <div className="relative overflow-hidden rounded-xl">
          <img
            src={sortedPhotos[activePhotoIndex]?.url}
            alt=""
            className="aspect-[3/4] w-full object-cover"
          />
          {sortedPhotos.length > 1 && (
            <>
              <div className="absolute top-2 left-0 right-0 flex justify-center gap-1">
                {sortedPhotos.map((_, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={() => setActivePhotoIndex(i)}
                    className={`h-1 rounded-full transition-all ${
                      i === activePhotoIndex ? 'w-6 bg-white' : 'w-2 bg-white/60'
                    }`}
                  />
                ))}
              </div>
              <button
                type="button"
                onClick={() =>
                  setActivePhotoIndex((prev) =>
                    prev > 0 ? prev - 1 : sortedPhotos.length - 1
                  )
                }
                className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-black/30 p-2 text-white hover:bg-black/50"
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                type="button"
                onClick={() =>
                  setActivePhotoIndex((prev) =>
                    prev < sortedPhotos.length - 1 ? prev + 1 : 0
                  )
                }
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-black/30 p-2 text-white hover:bg-black/50"
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" />
                </svg>
              </button>
            </>
          )}
        </div>
      )}

      {/* Basic info */}
      <Card>
        <div className="flex items-center gap-4">
          {!sortedPhotos.length && (
            <Avatar
              src={primaryPhoto?.thumbnail_url || primaryPhoto?.url}
              name={profile.nickname}
              size="xl"
            />
          )}
          <div className="flex-1">
            <h2 className="text-lg font-semibold text-gray-900">{profile.nickname}</h2>
            {profile.location?.prefecture && (
              <p className="text-sm text-gray-500">
                {profile.location.prefecture}
                {profile.location.city ? ` ${profile.location.city}` : ''}
              </p>
            )}
          </div>
        </div>
      </Card>

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
      {(profile.career?.occupation || profile.career?.education || profile.lifestyle?.drinking || profile.lifestyle?.smoking) && (
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
    </div>
  );
}
