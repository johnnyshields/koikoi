import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMatchingStore } from '../../store/matching';
import { PairCard } from '../../components/matching/PairCard';
import { SharedTagsBadge } from '../../components/matching/SharedTagsBadge';
import { RatingModal } from '../../components/matching/RatingModal';
import { Button } from '../../components/ui/Button';
import { toast } from '../../components/ui/Toast';

export function CardDealingPage() {
  const { t } = useTranslation('matching');
  const {
    pairs,
    currentPairIndex,
    isDealingCards,
    isLoading,
    dealCards,
    submitRating,
    skipPair,
    nextPair,
    previousPair,
  } = useMatchingStore();

  const [showRatingModal, setShowRatingModal] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [slideDirection, setSlideDirection] = useState<'left' | 'right' | null>(null);

  useEffect(() => {
    dealCards();
  }, [dealCards]);

  const currentPair = pairs[currentPairIndex];
  const isLastPair = currentPairIndex >= pairs.length - 1;
  const hasNoPairs = !isDealingCards && pairs.length === 0;
  const hasExhaustedPairs = !isDealingCards && pairs.length > 0 && currentPairIndex >= pairs.length;

  const handleRate = async (rating: number, confidence: string, note?: string) => {
    if (!currentPair) return;
    setIsSubmitting(true);
    try {
      const result = await submitRating(
        currentPair.person_a.user_id,
        currentPair.person_b.user_id,
        rating,
        confidence,
        note,
      );
      setShowRatingModal(false);
      if (result.status === 'match_created') {
        toast(t('match_created'), 'success');
      }
      if (!isLastPair) {
        animateTransition('left');
      }
    } catch {
      // error is handled by store
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSkip = async () => {
    if (!currentPair) return;
    try {
      await skipPair(currentPair.person_a.user_id, currentPair.person_b.user_id);
      if (!isLastPair) {
        animateTransition('left');
      }
    } catch {
      // error is handled by store
    }
  };

  const animateTransition = (direction: 'left' | 'right') => {
    setSlideDirection(direction);
    setTimeout(() => setSlideDirection(null), 300);
  };

  const handlePrev = () => {
    if (currentPairIndex > 0) {
      animateTransition('right');
      previousPair();
    }
  };

  const handleNext = () => {
    if (!isLastPair) {
      animateTransition('left');
      nextPair();
    }
  };

  // Dealing cards animation
  if (isDealingCards) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-6">
        <div className="relative">
          {/* Animated card stack */}
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className="absolute h-32 w-24 rounded-xl bg-gradient-to-br from-rose-400 to-rose-600 shadow-lg"
              style={{
                top: `${i * -4}px`,
                left: `${i * 4}px`,
                animation: `deal-card ${0.6 + i * 0.2}s ease-in-out infinite alternate`,
                animationDelay: `${i * 0.15}s`,
                zIndex: 3 - i,
              }}
            />
          ))}
          {/* Invisible spacer for layout */}
          <div className="h-32 w-24 opacity-0" />
        </div>
        <p className="text-lg font-medium text-gray-600">{t('dealing_cards')}</p>
        <style>{`
          @keyframes deal-card {
            0% { transform: translateY(0) rotate(0deg); }
            100% { transform: translateY(-12px) rotate(3deg); }
          }
        `}</style>
      </div>
    );
  }

  // No cards available
  if (hasNoPairs) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 text-center">
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-rose-50">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-10 w-10 text-rose-300"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
            />
          </svg>
        </div>
        <p className="text-gray-500">{t('no_cards')}</p>
        <Button onClick={() => dealCards()}>{t('deal_more')}</Button>
      </div>
    );
  }

  // All pairs exhausted
  if (hasExhaustedPairs || !currentPair) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 text-center">
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-green-50">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-10 w-10 text-green-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
          </svg>
        </div>
        <p className="text-gray-500">{t('no_cards')}</p>
        <Button onClick={() => dealCards()}>{t('deal_more')}</Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3 pb-4">
      {/* Pair counter */}
      <div className="text-center text-sm text-gray-400">
        {t('pair_counter', { current: currentPairIndex + 1, total: pairs.length })}
      </div>

      {/* Card pair display */}
      <div
        className={`transition-transform duration-300 ease-out ${
          slideDirection === 'left'
            ? '-translate-x-2 opacity-95'
            : slideDirection === 'right'
              ? 'translate-x-2 opacity-95'
              : 'translate-x-0'
        }`}
      >
        {/* Mobile: stacked layout */}
        <div className="flex flex-col items-center gap-0 sm:hidden">
          <PairCard person={currentPair.person_a} side="left" />
          <SharedTagsBadge tags={currentPair.shared_tags} />
          <PairCard person={currentPair.person_b} side="right" />
        </div>

        {/* Desktop: side by side */}
        <div className="hidden sm:flex sm:items-center sm:gap-3">
          <PairCard person={currentPair.person_a} side="left" />
          <SharedTagsBadge tags={currentPair.shared_tags} />
          <PairCard person={currentPair.person_b} side="right" />
        </div>
      </div>

      {/* Navigation arrows */}
      <div className="flex items-center justify-between px-2">
        <button
          type="button"
          onClick={handlePrev}
          disabled={currentPairIndex === 0}
          className="rounded-full p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 disabled:opacity-30"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
          </svg>
        </button>

        <button
          type="button"
          onClick={handleNext}
          disabled={isLastPair}
          className="rounded-full p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 disabled:opacity-30"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" />
          </svg>
        </button>
      </div>

      {/* Action buttons */}
      <div className="flex gap-3 px-2">
        <Button
          variant="outline"
          fullWidth
          onClick={handleSkip}
          disabled={isLoading}
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          }
        >
          {t('skip')}
        </Button>
        <Button
          fullWidth
          onClick={() => setShowRatingModal(true)}
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
          }
        >
          {t('rate_pair')}
        </Button>
      </div>

      <RatingModal
        isOpen={showRatingModal}
        onClose={() => setShowRatingModal(false)}
        onSubmit={handleRate}
        isLoading={isSubmitting}
      />
    </div>
  );
}
