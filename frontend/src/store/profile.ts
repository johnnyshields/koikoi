import { create } from 'zustand';
import { profileApi } from '../api/profile';
import type { Profile, ProfilePhoto, ProfileTag } from '../types';

interface ProfileState {
  profile: Profile | null;
  isLoading: boolean;
  error: string | null;

  fetchProfile: () => Promise<void>;
  updateProfile: (data: Partial<Profile>) => Promise<void>;
  uploadPhoto: (file: File) => Promise<ProfilePhoto>;
  deletePhoto: (photoId: string) => Promise<void>;
  reorderPhotos: (photoIds: string[]) => Promise<void>;
  setPrimaryPhoto: (photoId: string) => Promise<void>;
  addTags: (tags: { category: string; value: string }[]) => Promise<void>;
  removeTag: (tag: ProfileTag) => Promise<void>;
  clearError: () => void;
}

export const useProfileStore = create<ProfileState>((set, get) => ({
  profile: null,
  isLoading: false,
  error: null,

  fetchProfile: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await profileApi.getMyProfile();
      set({ profile: data.profile, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch profile';
      set({ error: message, isLoading: false });
    }
  },

  updateProfile: async (profileData) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await profileApi.updateProfile(profileData);
      set({ profile: data.profile, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to update profile';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  uploadPhoto: async (file) => {
    set({ error: null });
    try {
      const { data } = await profileApi.uploadPhoto(file);
      const profile = get().profile;
      if (profile) {
        set({ profile: { ...profile, photos: [...profile.photos, data.photo] } });
      }
      return data.photo;
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to upload photo';
      set({ error: message });
      throw err;
    }
  },

  deletePhoto: async (photoId) => {
    set({ error: null });
    try {
      await profileApi.deletePhoto(photoId);
      const profile = get().profile;
      if (profile) {
        set({ profile: { ...profile, photos: profile.photos.filter((p) => p.id !== photoId) } });
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to delete photo';
      set({ error: message });
      throw err;
    }
  },

  reorderPhotos: async (photoIds) => {
    set({ error: null });
    try {
      const { data } = await profileApi.reorderPhotos(photoIds);
      const profile = get().profile;
      if (profile) {
        set({ profile: { ...profile, photos: data.photos } });
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to reorder photos';
      set({ error: message });
      throw err;
    }
  },

  setPrimaryPhoto: async (photoId) => {
    set({ error: null });
    try {
      await profileApi.setPrimaryPhoto(photoId);
      const profile = get().profile;
      if (profile) {
        set({
          profile: {
            ...profile,
            photos: profile.photos.map((p) => ({ ...p, is_primary: p.id === photoId })),
          },
        });
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to set primary photo';
      set({ error: message });
      throw err;
    }
  },

  addTags: async (tags) => {
    set({ error: null });
    try {
      const { data } = await profileApi.addTags(tags);
      const profile = get().profile;
      if (profile) {
        set({ profile: { ...profile, tags: data.tags } });
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to add tags';
      set({ error: message });
      throw err;
    }
  },

  removeTag: async (tag) => {
    set({ error: null });
    try {
      await profileApi.removeTag(tag.category, tag.value);
      const profile = get().profile;
      if (profile) {
        set({
          profile: {
            ...profile,
            tags: profile.tags.filter(
              (t) => !(t.category === tag.category && t.value === tag.value)
            ),
          },
        });
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to remove tag';
      set({ error: message });
      throw err;
    }
  },

  clearError: () => set({ error: null }),
}));
