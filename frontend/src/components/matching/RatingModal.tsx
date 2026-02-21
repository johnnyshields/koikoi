import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';

interface RatingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (rating: number, confidence: string, note?: string) => void;
  isLoading?: boolean;
}

const CONFIDENCE_OPTIONS = ['low', 'medium', 'high'] as const;

export function RatingModal({ isOpen, onClose, onSubmit, isLoading }: RatingModalProps) {
  const { t } = useTranslation('matching');
  const [rating, setRating] = useState(0);
  const [hoveredRating, setHoveredRating] = useState(0);
  const [confidence, setConfidence] = useState<string>('medium');
  const [note, setNote] = useState('');

  const handleSubmit = () => {
    if (rating === 0) return;
    onSubmit(rating, confidence, note || undefined);
    setRating(0);
    setHoveredRating(0);
    setConfidence('medium');
    setNote('');
  };

  const handleClose = () => {
    setRating(0);
    setHoveredRating(0);
    setConfidence('medium');
    setNote('');
    onClose();
  };

  const ratingLabels: Record<number, string> = {
    1: t('rating_1'),
    2: t('rating_2'),
    3: t('rating_3'),
    4: t('rating_4'),
    5: t('rating_5'),
  };

  const confidenceLabels: Record<string, string> = {
    low: t('confidence_low'),
    medium: t('confidence_medium'),
    high: t('confidence_high'),
  };

  const displayRating = hoveredRating || rating;

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title={t('rate_pair')}>
      <div className="space-y-5">
        {/* Star rating */}
        <div className="text-center">
          <div className="mb-2 flex justify-center gap-2">
            {[1, 2, 3, 4, 5].map((star) => (
              <button
                key={star}
                type="button"
                className="transition-transform duration-150 hover:scale-110 active:scale-95"
                onMouseEnter={() => setHoveredRating(star)}
                onMouseLeave={() => setHoveredRating(0)}
                onClick={() => setRating(star)}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className={`h-10 w-10 transition-colors duration-150 ${
                    star <= displayRating
                      ? 'fill-amber-400 text-amber-400'
                      : 'fill-none text-gray-300'
                  }`}
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={1.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                  />
                </svg>
              </button>
            ))}
          </div>
          <p className={`h-5 text-sm font-medium transition-opacity ${
            displayRating ? 'text-amber-600 opacity-100' : 'opacity-0'
          }`}>
            {displayRating ? ratingLabels[displayRating] : ''}
          </p>
        </div>

        {/* Confidence selector */}
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700">
            {t('confidence')}
          </label>
          <div className="flex gap-2">
            {CONFIDENCE_OPTIONS.map((opt) => (
              <button
                key={opt}
                type="button"
                onClick={() => setConfidence(opt)}
                className={`flex-1 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  confidence === opt
                    ? 'bg-rose-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                {confidenceLabels[opt]}
              </button>
            ))}
          </div>
        </div>

        {/* Note */}
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700">
            {t('note')}
          </label>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t('note_placeholder')}
            rows={2}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-900 placeholder-gray-400 transition-colors focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
          />
        </div>

        {/* Submit button */}
        <Button
          fullWidth
          size="lg"
          disabled={rating === 0}
          isLoading={isLoading}
          onClick={handleSubmit}
        >
          {t('submit_rating')}
        </Button>
      </div>
    </Modal>
  );
}
