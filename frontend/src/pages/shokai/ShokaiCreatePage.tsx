import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useShokaiStore } from '../../store/shokai';
import { MemberPicker } from '../../components/chat/MemberPicker';
import { Button } from '../../components/ui/Button';
import { toast } from '../../components/ui/Toast';

export function ShokaiCreatePage() {
  const { t } = useTranslation('shokai');
  const { t: tc } = useTranslation('common');
  const navigate = useNavigate();
  const { createShokai } = useShokaiStore();

  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [personAId, setPersonAId] = useState<string | null>(null);
  const [personBId, setPersonBId] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSelectA = (userId: string) => {
    setPersonAId(userId);
    setStep(2);
  };

  const handleSelectB = (userId: string) => {
    setPersonBId(userId);
    setStep(3);
  };

  const handleSubmit = async () => {
    if (!personAId || !personBId) return;
    setIsSubmitting(true);
    const shokai = await createShokai(personAId, personBId, note || undefined);
    setIsSubmitting(false);

    if (shokai) {
      toast(t('create_success'), 'success');
      navigate(`/shokai/${shokai.id}`);
    } else {
      toast(tc('errors.generic'), 'error');
    }
  };

  return (
    <div className="space-y-4 pb-4">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => {
            if (step === 1) navigate(-1);
            else setStep((s) => (s - 1) as 1 | 2 | 3);
          }}
          className="rounded-full p-1 text-gray-500 hover:bg-gray-100"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">{t('create')}</h1>
      </div>

      {/* Step indicator */}
      <div className="flex items-center justify-center gap-2">
        {[1, 2, 3].map((s) => (
          <div
            key={s}
            className={`h-2 w-8 rounded-full ${
              s <= step ? 'bg-rose-500' : 'bg-gray-200'
            }`}
          />
        ))}
      </div>

      {step === 1 && (
        <div>
          <h2 className="mb-3 text-base font-semibold text-gray-800">
            {t('select_person_a')}
          </h2>
          <div className="rounded-lg border border-gray-200 bg-white p-2">
            <MemberPicker
              selectedIds={personAId ? [personAId] : []}
              onToggle={handleSelectA}
            />
          </div>
        </div>
      )}

      {step === 2 && (
        <div>
          <h2 className="mb-3 text-base font-semibold text-gray-800">
            {t('select_person_b')}
          </h2>
          <div className="rounded-lg border border-gray-200 bg-white p-2">
            <MemberPicker
              selectedIds={personBId ? [personBId] : []}
              onToggle={handleSelectB}
              excludeIds={personAId ? [personAId] : []}
            />
          </div>
        </div>
      )}

      {step === 3 && (
        <div className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">
              {t('add_note')}
            </label>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder={t('note_placeholder')}
              rows={3}
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
            />
          </div>

          <div className="rounded-xl bg-gray-50 p-4">
            <div className="flex items-center justify-center gap-4">
              <div className="text-center">
                <div className="mb-1 flex h-12 w-12 items-center justify-center rounded-full bg-rose-100 text-rose-600 mx-auto">
                  <span className="text-sm font-medium">{personAId?.slice(-4)}</span>
                </div>
              </div>
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
              <div className="text-center">
                <div className="mb-1 flex h-12 w-12 items-center justify-center rounded-full bg-rose-100 text-rose-600 mx-auto">
                  <span className="text-sm font-medium">{personBId?.slice(-4)}</span>
                </div>
              </div>
            </div>
          </div>

          <Button
            fullWidth
            onClick={handleSubmit}
            disabled={isSubmitting}
            isLoading={isSubmitting}
          >
            {t('create')}
          </Button>
        </div>
      )}
    </div>
  );
}
