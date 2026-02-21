import apiClient from './client';
import type { Profile, ProfilePhoto, ProfileTag, TagCatalogItem } from '../types';

export const profileApi = {
  getMyProfile: () =>
    apiClient.get<{ profile: Profile | null }>('/profile'),

  updateProfile: (data: Partial<Profile>) =>
    apiClient.put<{ profile: Profile }>('/profile', data),

  getProfile: (userId: string) =>
    apiClient.get<{ profile: Profile }>(`/profiles/${userId}`),

  uploadPhoto: (file: File) => {
    const formData = new FormData();
    formData.append('photo', file);
    return apiClient.post<{ photo: ProfilePhoto }>('/profile/photos', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },

  deletePhoto: (photoId: string) =>
    apiClient.delete<{ message: string }>(`/profile/photos/${photoId}`),

  reorderPhotos: (photoIds: string[]) =>
    apiClient.put<{ photos: ProfilePhoto[] }>('/profile/photos/reorder', { photo_ids: photoIds }),

  setPrimaryPhoto: (photoId: string) =>
    apiClient.put<{ message: string }>(`/profile/photos/${photoId}/primary`),

  addTags: (tags: { category: string; value: string }[]) =>
    apiClient.post<{ tags: ProfileTag[] }>('/profile/tags', { tags }),

  removeTag: (category: string, value: string) =>
    apiClient.delete<{ message: string }>('/profile/tags', { data: { category, value } }),

  searchTags: (params: { category?: string; search?: string; limit?: number }) =>
    apiClient.get<{ tags: TagCatalogItem[] }>('/tags', { params }),
};
