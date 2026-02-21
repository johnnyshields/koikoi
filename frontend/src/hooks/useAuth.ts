import { useEffect } from 'react';
import { useAuthStore } from '../store/auth';

export function useAuth() {
  const store = useAuthStore();

  useEffect(() => {
    if (store.isAuthenticated && !store.user) {
      store.fetchMe();
    }
  }, [store.isAuthenticated, store.user, store.fetchMe]);

  return store;
}
