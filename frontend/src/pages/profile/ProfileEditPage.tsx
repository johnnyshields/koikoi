import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfileStore } from '../../store/profile';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { CompletenessBar } from '../../components/profile/CompletenessBar';
import { PhotoUpload } from '../../components/profile/PhotoUpload';
import { TagSelector } from '../../components/profile/TagSelector';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';
import { PREFECTURES } from '../../data/prefectures';
import type { Profile } from '../../types';

const STEPS = ['basic', 'about', 'career', 'relationship', 'photos', 'tags', 'preferences'] as const;

const HEIGHT_OPTIONS = Array.from({ length: 61 }, (_, i) => 140 + i);
const BODY_TYPES = ['slim', 'normal', 'muscular', 'chubby', 'large'] as const;
const BLOOD_TYPES = ['A', 'B', 'O', 'AB'] as const;
const EDUCATION_OPTIONS = ['high_school', 'vocational', 'university', 'graduate'] as const;
const INCOME_OPTIONS = ['under_300', '300_500', '500_700', '700_1000', 'over_1000'] as const;
const DRINKING_OPTIONS = ['never', 'sometimes', 'often'] as const;
const SMOKING_OPTIONS = ['never', 'sometimes', 'often'] as const;
const MARRIAGE_OPTIONS = ['want', 'if_right', 'not_now'] as const;
const WANTS_CHILDREN_OPTIONS = ['want', 'if_right', 'not_want'] as const;
const GENDER_OPTIONS = ['male', 'female', 'other'] as const;

interface FormData {
  nickname: string;
  prefecture: string;
  city: string;
  hometown: string;
  bio: string;
  personality: string;
  height_cm: string;
  body_type: string;
  blood_type: string;
  occupation: string;
  education: string;
  income_range: string;
  drinking: string;
  smoking: string;
  marriage_intent: string;
  has_children: boolean;
  wants_children: string;
  age_min: number;
  age_max: number;
  preferred_genders: string[];
  preferred_prefectures: string[];
}

function buildFormData(profile: Profile | null): FormData {
  return {
    nickname: profile?.nickname || '',
    prefecture: profile?.location?.prefecture || '',
    city: profile?.location?.city || '',
    hometown: profile?.hometown || '',
    bio: profile?.bio || '',
    personality: profile?.personality || '',
    height_cm: profile?.physical?.height_cm?.toString() || '',
    body_type: profile?.physical?.body_type || '',
    blood_type: profile?.physical?.blood_type || '',
    occupation: profile?.career?.occupation || '',
    education: profile?.career?.education || '',
    income_range: profile?.career?.income_range || '',
    drinking: profile?.lifestyle?.drinking || '',
    smoking: profile?.lifestyle?.smoking || '',
    marriage_intent: profile?.relationship?.marriage_intent || '',
    has_children: profile?.relationship?.has_children || false,
    wants_children: profile?.relationship?.wants_children || '',
    age_min: profile?.preferences?.age_range?.min || 18,
    age_max: profile?.preferences?.age_range?.max || 50,
    preferred_genders: profile?.preferences?.preferred_genders || [],
    preferred_prefectures: profile?.preferences?.preferred_prefectures || [],
  };
}

function buildProfilePayload(form: FormData): Partial<Profile> {
  return {
    nickname: form.nickname,
    location: { prefecture: form.prefecture, city: form.city },
    hometown: form.hometown || null,
    bio: form.bio || null,
    personality: form.personality || null,
    physical: {
      height_cm: form.height_cm ? parseInt(form.height_cm, 10) : null,
      body_type: form.body_type || null,
      blood_type: form.blood_type || null,
    },
    career: {
      occupation: form.occupation || null,
      education: form.education || null,
      income_range: form.income_range || null,
    },
    lifestyle: {
      drinking: form.drinking || null,
      smoking: form.smoking || null,
    },
    relationship: {
      marriage_intent: form.marriage_intent || null,
      has_children: form.has_children,
      wants_children: form.wants_children || null,
    },
    preferences: {
      age_range: { min: form.age_min, max: form.age_max },
      preferred_genders: form.preferred_genders,
      preferred_prefectures: form.preferred_prefectures.length > 0 ? form.preferred_prefectures : null,
    },
  };
}

function SelectField({
  label,
  value,
  onChange,
  placeholder,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
  options: { value: string; label: string }[];
}) {
  return (
    <div className="w-full">
      <label className="mb-1 block text-sm font-medium text-gray-700">{label}</label>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 transition-colors duration-150 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
      >
        <option value="">{placeholder}</option>
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}

export function ProfileEditPage() {
  const { t } = useTranslation('profile');
  const { t: tc } = useTranslation('common');
  const navigate = useNavigate();
  const {
    profile,
    isLoading,
    fetchProfile,
    updateProfile,
    uploadPhoto,
    deletePhoto,
    reorderPhotos,
    setPrimaryPhoto,
    addTags,
    removeTag,
  } = useProfileStore();

  const [currentStep, setCurrentStep] = useState(0);
  const [form, setForm] = useState<FormData>(() => buildFormData(null));
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);

  useEffect(() => {
    if (profile) {
      setForm(buildFormData(profile));
    }
  }, [profile]);

  const updateField = useCallback(<K extends keyof FormData>(key: K, value: FormData[K]) => {
    setForm((prev) => ({ ...prev, [key]: value }));
  }, []);

  const handleSave = async () => {
    setSaving(true);
    try {
      await updateProfile(buildProfilePayload(form));
      toast(tc('status.saving'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleNext = async () => {
    await handleSave();
    if (currentStep < STEPS.length - 1) {
      setCurrentStep((s) => s + 1);
    } else {
      navigate('/profile');
    }
  };

  const handlePrevious = () => {
    if (currentStep > 0) setCurrentStep((s) => s - 1);
  };

  const handleSkip = () => {
    if (currentStep < STEPS.length - 1) {
      setCurrentStep((s) => s + 1);
    } else {
      navigate('/profile');
    }
  };

  if (isLoading && !profile) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  const step = STEPS[currentStep];

  return (
    <div className="space-y-4 pb-4">
      {/* Header */}
      <h1 className="text-xl font-bold text-gray-900">{t('editProfile')}</h1>

      {/* Completeness */}
      {profile && <CompletenessBar percentage={profile.profile_completeness} />}

      {/* Step indicator */}
      <div className="flex gap-1">
        {STEPS.map((s, i) => (
          <button
            key={s}
            type="button"
            onClick={() => setCurrentStep(i)}
            className={`flex-1 rounded-full py-1 text-center text-xs font-medium transition-colors ${
              i === currentStep
                ? 'bg-rose-500 text-white'
                : i < currentStep
                  ? 'bg-rose-200 text-rose-700'
                  : 'bg-gray-200 text-gray-500'
            }`}
          >
            <span className="hidden sm:inline">{t(`steps.${s}`)}</span>
            <span className="sm:hidden">{i + 1}</span>
          </button>
        ))}
      </div>

      {/* Step title */}
      <h2 className="text-lg font-semibold text-gray-800">
        {t(`steps.${step}`)}
      </h2>

      {/* Step content */}
      <Card>
        {step === 'basic' && (
          <div className="space-y-4">
            <Input
              label={t('fields.nickname')}
              value={form.nickname}
              onChange={(e) => updateField('nickname', e.target.value)}
              placeholder={t('fields.nicknamePlaceholder')}
            />
            <SelectField
              label={t('fields.prefecture')}
              value={form.prefecture}
              onChange={(v) => updateField('prefecture', v)}
              placeholder={t('fields.prefecturePlaceholder')}
              options={PREFECTURES.map((p) => ({ value: p, label: p }))}
            />
            <Input
              label={t('fields.city')}
              value={form.city}
              onChange={(e) => updateField('city', e.target.value)}
              placeholder={t('fields.cityPlaceholder')}
            />
            <Input
              label={t('fields.hometown')}
              value={form.hometown}
              onChange={(e) => updateField('hometown', e.target.value)}
              placeholder={t('fields.hometownPlaceholder')}
            />
          </div>
        )}

        {step === 'about' && (
          <div className="space-y-4">
            <div className="w-full">
              <label className="mb-1 block text-sm font-medium text-gray-700">
                {t('fields.bio')}
              </label>
              <textarea
                value={form.bio}
                onChange={(e) => updateField('bio', e.target.value.slice(0, 500))}
                placeholder={t('fields.bioPlaceholder')}
                rows={4}
                className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 placeholder:text-gray-400 transition-colors duration-150 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
              />
              <p className="mt-1 text-right text-xs text-gray-500">
                {t('fields.bioCount', { count: form.bio.length })}
              </p>
            </div>
            <div className="w-full">
              <label className="mb-1 block text-sm font-medium text-gray-700">
                {t('fields.personality')}
              </label>
              <textarea
                value={form.personality}
                onChange={(e) => updateField('personality', e.target.value)}
                placeholder={t('fields.personalityPlaceholder')}
                rows={3}
                className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 placeholder:text-gray-400 transition-colors duration-150 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
              />
            </div>
            <SelectField
              label={t('fields.heightCm')}
              value={form.height_cm}
              onChange={(v) => updateField('height_cm', v)}
              placeholder={t('fields.heightPlaceholder')}
              options={HEIGHT_OPTIONS.map((h) => ({ value: h.toString(), label: `${h}cm` }))}
            />
            <SelectField
              label={t('fields.bodyType')}
              value={form.body_type}
              onChange={(v) => updateField('body_type', v)}
              placeholder={t('fields.bodyTypePlaceholder')}
              options={BODY_TYPES.map((bt) => ({
                value: bt,
                label: t(`options.bodyType.${bt}`),
              }))}
            />
            <SelectField
              label={t('fields.bloodType')}
              value={form.blood_type}
              onChange={(v) => updateField('blood_type', v)}
              placeholder={t('fields.bloodTypePlaceholder')}
              options={BLOOD_TYPES.map((bt) => ({
                value: bt,
                label: t(`options.bloodType.${bt}`),
              }))}
            />
          </div>
        )}

        {step === 'career' && (
          <div className="space-y-4">
            <Input
              label={t('fields.occupation')}
              value={form.occupation}
              onChange={(e) => updateField('occupation', e.target.value)}
              placeholder={t('fields.occupationPlaceholder')}
            />
            <SelectField
              label={t('fields.education')}
              value={form.education}
              onChange={(v) => updateField('education', v)}
              placeholder={t('fields.educationPlaceholder')}
              options={EDUCATION_OPTIONS.map((e) => ({
                value: e,
                label: t(`options.education.${e}`),
              }))}
            />
            <SelectField
              label={t('fields.incomeRange')}
              value={form.income_range}
              onChange={(v) => updateField('income_range', v)}
              placeholder={t('fields.incomeRangePlaceholder')}
              options={INCOME_OPTIONS.map((i) => ({
                value: i,
                label: t(`options.incomeRange.${i}`),
              }))}
            />
            <SelectField
              label={t('fields.drinking')}
              value={form.drinking}
              onChange={(v) => updateField('drinking', v)}
              placeholder={t('fields.drinkingPlaceholder')}
              options={DRINKING_OPTIONS.map((d) => ({
                value: d,
                label: t(`options.drinking.${d}`),
              }))}
            />
            <SelectField
              label={t('fields.smoking')}
              value={form.smoking}
              onChange={(v) => updateField('smoking', v)}
              placeholder={t('fields.smokingPlaceholder')}
              options={SMOKING_OPTIONS.map((s) => ({
                value: s,
                label: t(`options.smoking.${s}`),
              }))}
            />
          </div>
        )}

        {step === 'relationship' && (
          <div className="space-y-4">
            <SelectField
              label={t('fields.marriageIntent')}
              value={form.marriage_intent}
              onChange={(v) => updateField('marriage_intent', v)}
              placeholder={t('fields.marriageIntentPlaceholder')}
              options={MARRIAGE_OPTIONS.map((m) => ({
                value: m,
                label: t(`options.marriageIntent.${m}`),
              }))}
            />
            <div className="w-full">
              <label className="mb-1 block text-sm font-medium text-gray-700">
                {t('fields.hasChildren')}
              </label>
              <button
                type="button"
                onClick={() => updateField('has_children', !form.has_children)}
                className={`relative h-6 w-11 rounded-full transition-colors ${
                  form.has_children ? 'bg-rose-500' : 'bg-gray-300'
                }`}
              >
                <span
                  className={`absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white transition-transform ${
                    form.has_children ? 'translate-x-5' : ''
                  }`}
                />
              </button>
            </div>
            <SelectField
              label={t('fields.wantsChildren')}
              value={form.wants_children}
              onChange={(v) => updateField('wants_children', v)}
              placeholder={t('fields.wantsChildrenPlaceholder')}
              options={WANTS_CHILDREN_OPTIONS.map((w) => ({
                value: w,
                label: t(`options.wantsChildren.${w}`),
              }))}
            />
          </div>
        )}

        {step === 'photos' && (
          <PhotoUpload
            photos={profile?.photos || []}
            maxPhotos={6}
            onUpload={async (file) => {
              await uploadPhoto(file);
            }}
            onDelete={deletePhoto}
            onSetPrimary={setPrimaryPhoto}
            onReorder={reorderPhotos}
          />
        )}

        {step === 'tags' && (
          <TagSelector
            selectedTags={profile?.tags || []}
            onAddTags={addTags}
            onRemoveTag={removeTag}
          />
        )}

        {step === 'preferences' && (
          <div className="space-y-4">
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700">
                {t('fields.ageRange')}
              </label>
              <div className="flex items-center gap-3">
                <div className="flex-1">
                  <label className="mb-1 block text-xs text-gray-500">{t('fields.ageMin')}</label>
                  <input
                    type="number"
                    min={18}
                    max={form.age_max}
                    value={form.age_min}
                    onChange={(e) => updateField('age_min', parseInt(e.target.value, 10) || 18)}
                    className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
                  />
                </div>
                <span className="mt-5 text-gray-400">-</span>
                <div className="flex-1">
                  <label className="mb-1 block text-xs text-gray-500">{t('fields.ageMax')}</label>
                  <input
                    type="number"
                    min={form.age_min}
                    max={100}
                    value={form.age_max}
                    onChange={(e) => updateField('age_max', parseInt(e.target.value, 10) || 50)}
                    className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
                  />
                </div>
              </div>
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700">
                {t('fields.preferredGenders')}
              </label>
              <div className="flex flex-wrap gap-2">
                {GENDER_OPTIONS.map((g) => {
                  const selected = form.preferred_genders.includes(g);
                  return (
                    <button
                      key={g}
                      type="button"
                      onClick={() => {
                        if (selected) {
                          updateField(
                            'preferred_genders',
                            form.preferred_genders.filter((v) => v !== g)
                          );
                        } else {
                          updateField('preferred_genders', [...form.preferred_genders, g]);
                        }
                      }}
                      className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
                        selected
                          ? 'bg-rose-500 text-white'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                    >
                      {t(`options.gender.${g}`)}
                    </button>
                  );
                })}
              </div>
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700">
                {t('fields.preferredPrefectures')}
              </label>
              <div className="max-h-48 overflow-y-auto rounded-lg border border-gray-200 p-2">
                <label className="mb-2 flex items-center gap-2 border-b border-gray-100 pb-2">
                  <input
                    type="checkbox"
                    checked={form.preferred_prefectures.length === 0}
                    onChange={() => updateField('preferred_prefectures', [])}
                    className="h-4 w-4 rounded border-gray-300 text-rose-500 focus:ring-rose-500"
                  />
                  <span className="text-sm font-medium text-gray-700">{t('fields.selectAll')}</span>
                </label>
                <div className="grid grid-cols-2 gap-1">
                  {PREFECTURES.map((pref) => {
                    const checked = form.preferred_prefectures.includes(pref);
                    return (
                      <label key={pref} className="flex items-center gap-2 rounded px-1 py-0.5 hover:bg-gray-50">
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={() => {
                            if (checked) {
                              updateField(
                                'preferred_prefectures',
                                form.preferred_prefectures.filter((p) => p !== pref)
                              );
                            } else {
                              updateField('preferred_prefectures', [...form.preferred_prefectures, pref]);
                            }
                          }}
                          className="h-4 w-4 rounded border-gray-300 text-rose-500 focus:ring-rose-500"
                        />
                        <span className="text-sm text-gray-700">{pref}</span>
                      </label>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        )}
      </Card>

      {/* Navigation buttons */}
      <div className="flex items-center gap-2">
        {currentStep > 0 && (
          <Button variant="outline" onClick={handlePrevious}>
            {t('previous')}
          </Button>
        )}
        <div className="flex-1" />
        <Button variant="ghost" onClick={handleSkip}>
          {t('skip')}
        </Button>
        <Button onClick={handleNext} isLoading={saving}>
          {currentStep < STEPS.length - 1 ? tc('actions.next') : t('finish')}
        </Button>
      </div>
    </div>
  );
}
