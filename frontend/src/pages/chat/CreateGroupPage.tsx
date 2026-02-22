import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useChatStore } from '../../store/chat';
import { MemberPicker } from '../../components/chat/MemberPicker';
import { Button } from '../../components/ui/Button';
import { toast } from '../../components/ui/Toast';

const GOUKON_DURATIONS = [2, 6, 12, 24, 48];

export function CreateGroupPage() {
  const { t } = useTranslation('chat');
  const { t: tc } = useTranslation('common');
  const navigate = useNavigate();
  const { createGroup, createGoukon } = useChatStore();

  const [name, setName] = useState('');
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [isGoukon, setIsGoukon] = useState(false);
  const [duration, setDuration] = useState(24);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleToggle = (userId: string) => {
    setSelectedIds((prev) =>
      prev.includes(userId) ? prev.filter((id) => id !== userId) : [...prev, userId],
    );
  };

  const handleSubmit = async () => {
    if (!name.trim() || selectedIds.length === 0) return;

    setIsSubmitting(true);
    const conv = isGoukon
      ? await createGoukon(name.trim(), selectedIds, duration)
      : await createGroup(name.trim(), selectedIds);

    setIsSubmitting(false);

    if (conv) {
      toast(isGoukon ? t('create_goukon') : t('create_group'), 'success');
      navigate(`/conversations/${conv.id}`);
    } else {
      toast(tc('errors.generic'), 'error');
    }
  };

  return (
    <div className="space-y-4 pb-4">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => navigate(-1)}
          className="rounded-full p-1 text-gray-500 hover:bg-gray-100"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">
          {isGoukon ? t('create_goukon') : t('create_group')}
        </h1>
      </div>

      {/* Group name */}
      <div>
        <label className="mb-1 block text-sm font-medium text-gray-700">
          {t('group_name')}
        </label>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-base text-gray-900 placeholder:text-gray-400 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
          placeholder={t('group_name')}
        />
      </div>

      {/* Goukon toggle */}
      <div className="flex items-center justify-between rounded-lg bg-white p-4 shadow-sm">
        <span className="text-sm font-medium text-gray-700">{t('goukon_mode')}</span>
        <button
          type="button"
          onClick={() => setIsGoukon(!isGoukon)}
          className={`relative h-6 w-11 rounded-full transition-colors ${isGoukon ? 'bg-purple-500' : 'bg-gray-300'}`}
        >
          <span
            className={`absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white transition-transform ${isGoukon ? 'translate-x-5' : ''}`}
          />
        </button>
      </div>

      {/* Duration picker for goukon */}
      {isGoukon && (
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-700">
            {t('duration')}
          </label>
          <select
            value={duration}
            onChange={(e) => setDuration(Number(e.target.value))}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-base text-gray-900 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
          >
            {GOUKON_DURATIONS.map((h) => (
              <option key={h} value={h}>
                {h}{t('hours')}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Member picker */}
      <div>
        <label className="mb-1 block text-sm font-medium text-gray-700">
          {t('select_friends')} ({selectedIds.length})
        </label>
        <div className="rounded-lg border border-gray-200 bg-white p-2">
          <MemberPicker
            selectedIds={selectedIds}
            onToggle={handleToggle}
          />
        </div>
      </div>

      {/* Submit */}
      <Button
        fullWidth
        onClick={handleSubmit}
        disabled={!name.trim() || selectedIds.length === 0 || isSubmitting}
        isLoading={isSubmitting}
      >
        {isGoukon ? t('create_goukon') : t('create_group')}
      </Button>
    </div>
  );
}
