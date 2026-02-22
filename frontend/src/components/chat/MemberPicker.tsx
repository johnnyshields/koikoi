import { useEffect } from 'react';
import { useSocialStore } from '../../store/social';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../ui/Avatar';
import type { Connection } from '../../types';

interface MemberPickerProps {
  selectedIds: string[];
  onToggle: (userId: string) => void;
  excludeIds?: string[];
}

function getFriendUserId(connection: Connection, currentUserId: string): string {
  return connection.requester_id === currentUserId
    ? connection.recipient_id
    : connection.requester_id;
}

export function MemberPicker({ selectedIds, onToggle, excludeIds = [] }: MemberPickerProps) {
  const { user } = useAuth();
  const { friends, fetchFriends } = useSocialStore();

  useEffect(() => {
    fetchFriends();
  }, [fetchFriends]);

  const availableFriends = friends.filter((f) => {
    const friendId = user ? getFriendUserId(f, user.id) : f.recipient_id;
    return !excludeIds.includes(friendId);
  });

  return (
    <div className="max-h-60 space-y-1 overflow-y-auto">
      {availableFriends.map((friend) => {
        const friendId = user ? getFriendUserId(friend, user.id) : friend.recipient_id;
        const isSelected = selectedIds.includes(friendId);

        return (
          <button
            key={friend.id}
            type="button"
            onClick={() => onToggle(friendId)}
            className={`flex w-full items-center gap-3 rounded-lg px-3 py-2 transition-colors ${
              isSelected ? 'bg-rose-50' : 'hover:bg-gray-50'
            }`}
          >
            <div className="relative">
              <Avatar name={friendId} size="md" />
              {isSelected && (
                <div className="absolute -bottom-0.5 -right-0.5 flex h-4 w-4 items-center justify-center rounded-full bg-rose-500 text-white">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
              )}
            </div>
            <span className="text-sm font-medium text-gray-900">
              {friendId.slice(-6)}
            </span>
          </button>
        );
      })}
      {availableFriends.length === 0 && (
        <p className="py-4 text-center text-sm text-gray-500">
          No friends available
        </p>
      )}
    </div>
  );
}
