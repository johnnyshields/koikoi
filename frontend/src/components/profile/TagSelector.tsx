import { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { profileApi } from '../../api/profile';
import type { ProfileTag, TagCatalogItem } from '../../types';
import { Input } from '../ui/Input';

const TAG_CATEGORIES = [
  'hobby',
  'lifestyle',
  'values',
  'personality',
  'food',
  'music',
  'sports',
  'travel',
] as const;

interface TagSelectorProps {
  selectedTags: ProfileTag[];
  onAddTags: (tags: { category: string; value: string }[]) => Promise<void>;
  onRemoveTag: (tag: ProfileTag) => Promise<void>;
}

export function TagSelector({ selectedTags, onAddTags, onRemoveTag }: TagSelectorProps) {
  const { t } = useTranslation('profile');
  const [activeCategory, setActiveCategory] = useState<string>(TAG_CATEGORIES[0]);
  const [searchQuery, setSearchQuery] = useState('');
  const [catalogTags, setCatalogTags] = useState<TagCatalogItem[]>([]);
  const [customTag, setCustomTag] = useState('');

  const fetchTags = useCallback(async () => {
    try {
      const { data } = await profileApi.searchTags({
        category: activeCategory,
        search: searchQuery || undefined,
        limit: 50,
      });
      setCatalogTags(data.tags);
    } catch {
      setCatalogTags([]);
    }
  }, [activeCategory, searchQuery]);

  useEffect(() => {
    fetchTags();
  }, [fetchTags]);

  const isSelected = (category: string, value: string) =>
    selectedTags.some((tag) => tag.category === category && tag.value === value);

  const handleToggleTag = async (category: string, value: string) => {
    if (isSelected(category, value)) {
      await onRemoveTag({ category, value });
    } else {
      await onAddTags([{ category, value }]);
    }
  };

  const handleAddCustom = async () => {
    const trimmed = customTag.trim();
    if (!trimmed) return;
    if (isSelected(activeCategory, trimmed)) return;
    await onAddTags([{ category: activeCategory, value: trimmed }]);
    setCustomTag('');
  };

  return (
    <div className="space-y-4">
      {/* Selected tags */}
      {selectedTags.length > 0 && (
        <div>
          <p className="mb-2 text-sm font-medium text-gray-700">
            {t('tags.selected')}
          </p>
          <div className="flex flex-wrap gap-2">
            {selectedTags.map((tag) => (
              <span
                key={`${tag.category}-${tag.value}`}
                className="inline-flex items-center gap-1 rounded-full bg-rose-100 px-3 py-1 text-sm text-rose-700"
              >
                {tag.value}
                <button
                  type="button"
                  onClick={() => onRemoveTag(tag)}
                  className="ml-0.5 text-rose-500 hover:text-rose-700"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                  </svg>
                </button>
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Search */}
      <Input
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        placeholder={t('tags.search')}
        icon={
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        }
      />

      {/* Category tabs */}
      <div className="flex flex-wrap gap-2">
        {TAG_CATEGORIES.map((cat) => (
          <button
            key={cat}
            type="button"
            onClick={() => setActiveCategory(cat)}
            className={`rounded-full px-3 py-1 text-sm font-medium transition-colors ${
              activeCategory === cat
                ? 'bg-rose-500 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {t(`tags.categories.${cat}`)}
          </button>
        ))}
      </div>

      {/* Tag grid */}
      <div className="flex flex-wrap gap-2">
        {catalogTags.map((tag) => {
          const selected = isSelected(tag.category, tag.value);
          return (
            <button
              key={`${tag.category}-${tag.value}`}
              type="button"
              onClick={() => handleToggleTag(tag.category, tag.value)}
              className={`rounded-full px-3 py-1.5 text-sm transition-colors ${
                selected
                  ? 'bg-rose-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-rose-50 hover:text-rose-600'
              }`}
            >
              {tag.value}
            </button>
          );
        })}
        {catalogTags.length === 0 && (
          <p className="text-sm text-gray-500">{t('tags.noResults')}</p>
        )}
      </div>

      {/* Custom tag input */}
      <div className="flex gap-2">
        <Input
          value={customTag}
          onChange={(e) => setCustomTag(e.target.value)}
          placeholder={t('tags.addCustomPlaceholder')}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              handleAddCustom();
            }
          }}
        />
        <button
          type="button"
          onClick={handleAddCustom}
          disabled={!customTag.trim()}
          className="shrink-0 rounded-lg bg-rose-500 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-rose-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {t('tags.addCustom')}
        </button>
      </div>
    </div>
  );
}
