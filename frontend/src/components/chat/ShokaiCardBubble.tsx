import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useShokaiStore } from '../../store/shokai';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../ui/Avatar';
import { Button } from '../ui/Button';
import type { ChatMessage } from '../../types';

interface ShokaiCardBubbleProps {
  message: ChatMessage;
}

export function ShokaiCardBubble({ message }: ShokaiCardBubbleProps) {
  const { t } = useTranslation('shokai');
  const navigate = useNavigate();
  const { user } = useAuth();
  const { pending, sent, respondToShokai } = useShokaiStore();

  const shokai = [...pending, ...sent].find(
    (s) => s.id === message.shokai_card_id,
  );

  const handleRespond = async (response: 'accepted' | 'declined') => {
    if (!message.shokai_card_id) return;
    await respondToShokai(message.shokai_card_id, response);
  };

  const isParty =
    shokai &&
    user &&
    (shokai.person_a_id === user.id || shokai.person_b_id === user.id);
  const isPending = shokai?.status === 'pending';

  return (
    <div className="my-2 flex justify-center">
      <div className="w-full max-w-xs rounded-xl border border-amber-200 bg-amber-50 p-4">
        <div className="mb-2 text-center text-xs font-medium text-amber-700">
          {t('title')}
        </div>

        {shokai ? (
          <>
            <div className="mb-3 flex items-center justify-center gap-3">
              <div className="flex flex-col items-center">
                <Avatar
                  name={shokai.person_a_profile?.nickname || shokai.person_a_id}
                  src={shokai.person_a_profile?.primary_photo?.thumbnail_url}
                  size="lg"
                />
                <span className="mt-1 text-xs text-gray-700">
                  {shokai.person_a_profile?.nickname || shokai.person_a_id.slice(-6)}
                </span>
              </div>
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-amber-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
              <div className="flex flex-col items-center">
                <Avatar
                  name={shokai.person_b_profile?.nickname || shokai.person_b_id}
                  src={shokai.person_b_profile?.primary_photo?.thumbnail_url}
                  size="lg"
                />
                <span className="mt-1 text-xs text-gray-700">
                  {shokai.person_b_profile?.nickname || shokai.person_b_id.slice(-6)}
                </span>
              </div>
            </div>

            {shokai.matchmaker_note && (
              <p className="mb-2 text-center text-xs text-gray-600 italic">
                &ldquo;{shokai.matchmaker_note}&rdquo;
              </p>
            )}

            {shokai.compatibility_hints.shared_tags.length > 0 && (
              <div className="mb-3 flex flex-wrap justify-center gap-1">
                {shokai.compatibility_hints.shared_tags.slice(0, 5).map((tag) => (
                  <span
                    key={tag}
                    className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] text-amber-800"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            )}

            {isPending && isParty ? (
              <div className="flex gap-2">
                <Button
                  size="sm"
                  fullWidth
                  onClick={() => handleRespond('accepted')}
                >
                  {t('accept')}
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  fullWidth
                  onClick={() => handleRespond('declined')}
                >
                  {t('decline')}
                </Button>
              </div>
            ) : (
              <div className="text-center">
                <span
                  className={`inline-block rounded-full px-3 py-1 text-xs font-medium ${
                    shokai.status === 'accepted'
                      ? 'bg-green-100 text-green-700'
                      : shokai.status === 'declined'
                        ? 'bg-red-100 text-red-700'
                        : shokai.status === 'expired'
                          ? 'bg-gray-100 text-gray-500'
                          : 'bg-amber-100 text-amber-700'
                  }`}
                >
                  {t(shokai.status)}
                </span>
              </div>
            )}
          </>
        ) : (
          <button
            type="button"
            onClick={() => message.shokai_card_id && navigate(`/shokai/${message.shokai_card_id}`)}
            className="w-full text-center text-sm text-amber-600 hover:underline"
          >
            {t('title')}
          </button>
        )}
      </div>
    </div>
  );
}
