import { useRef, useState, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import type { ProfilePhoto } from '../../types';
import { LoadingSpinner } from '../ui/LoadingSpinner';

interface PhotoUploadProps {
  photos: ProfilePhoto[];
  maxPhotos?: number;
  onUpload: (file: File) => Promise<void>;
  onDelete: (photoId: string) => Promise<void>;
  onSetPrimary: (photoId: string) => Promise<void>;
  onReorder: (photoIds: string[]) => Promise<void>;
}

export function PhotoUpload({
  photos,
  maxPhotos = 6,
  onUpload,
  onDelete,
  onSetPrimary,
  onReorder,
}: PhotoUploadProps) {
  const { t } = useTranslation('profile');
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);

  const handleFileSelect = useCallback(
    async (files: FileList | null) => {
      if (!files || files.length === 0) return;
      if (photos.length >= maxPhotos) return;

      setUploading(true);
      try {
        await onUpload(files[0]);
      } finally {
        setUploading(false);
        if (fileInputRef.current) fileInputRef.current.value = '';
      }
    },
    [photos.length, maxPhotos, onUpload]
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      if (e.dataTransfer.files.length > 0) {
        handleFileSelect(e.dataTransfer.files);
        return;
      }
      if (draggedIndex !== null && dragOverIndex !== null && draggedIndex !== dragOverIndex) {
        const newOrder = [...photos];
        const [moved] = newOrder.splice(draggedIndex, 1);
        newOrder.splice(dragOverIndex, 0, moved);
        onReorder(newOrder.map((p) => p.id));
      }
      setDraggedIndex(null);
      setDragOverIndex(null);
    },
    [draggedIndex, dragOverIndex, photos, onReorder, handleFileSelect]
  );

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    setDragOverIndex(index);
  };

  const sortedPhotos = [...photos].sort((a, b) => a.order - b.order);

  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <span className="text-sm font-medium text-gray-700">
          {t('photos.title')}
        </span>
        <span className="text-xs text-gray-500">
          {t('photos.photoCount', { count: photos.length, max: maxPhotos })}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-2">
        {sortedPhotos.map((photo, index) => (
          <div
            key={photo.id}
            draggable
            onDragStart={() => setDraggedIndex(index)}
            onDragOver={(e) => handleDragOver(e, index)}
            onDragEnd={() => {
              setDraggedIndex(null);
              setDragOverIndex(null);
            }}
            onDrop={handleDrop}
            className={`group relative aspect-square cursor-grab overflow-hidden rounded-lg border-2 transition-all ${
              dragOverIndex === index
                ? 'border-rose-400 bg-rose-50'
                : 'border-gray-200'
            }`}
          >
            <img
              src={photo.thumbnail_url || photo.url}
              alt=""
              className="h-full w-full object-cover"
            />

            {/* Primary badge */}
            {photo.is_primary && (
              <div className="absolute top-1 left-1 rounded-full bg-rose-500 px-1.5 py-0.5 text-[10px] font-medium text-white">
                {t('photos.primary')}
              </div>
            )}

            {/* Action overlay */}
            <div className="absolute inset-0 flex items-center justify-center gap-1 bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
              {!photo.is_primary && (
                <button
                  type="button"
                  onClick={() => onSetPrimary(photo.id)}
                  className="rounded-full bg-white/90 p-1.5 text-rose-600 hover:bg-white"
                  title={t('photos.setPrimary')}
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                </button>
              )}
              <button
                type="button"
                onClick={() => onDelete(photo.id)}
                className="rounded-full bg-white/90 p-1.5 text-red-600 hover:bg-white"
                title={t('photos.deletePhoto')}
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        ))}

        {/* Upload slot */}
        {photos.length < maxPhotos && (
          <div
            onClick={() => fileInputRef.current?.click()}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              handleFileSelect(e.dataTransfer.files);
            }}
            className="flex aspect-square cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-gray-300 bg-gray-50 transition-colors hover:border-rose-400 hover:bg-rose-50"
          >
            {uploading ? (
              <LoadingSpinner size="sm" />
            ) : (
              <>
                <svg xmlns="http://www.w3.org/2000/svg" className="mb-1 h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
                </svg>
                <span className="text-xs text-gray-500">{t('photos.upload')}</span>
              </>
            )}
          </div>
        )}
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => handleFileSelect(e.target.files)}
      />
    </div>
  );
}
