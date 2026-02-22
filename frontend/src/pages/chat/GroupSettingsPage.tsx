import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useChatStore } from '../../store/chat';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../../components/ui/Avatar';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { MemberPicker } from '../../components/chat/MemberPicker';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';

function formatCountdown(expiresAt: string): string {
  const diff = new Date(expiresAt).getTime() - Date.now();
  if (diff <= 0) return '期限切れ';
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  return `${hours}h ${minutes}m`;
}

export function GroupSettingsPage() {
  const { conversationId } = useParams<{ conversationId: string }>();
  const navigate = useNavigate();
  const { t } = useTranslation('chat');
  const { t: tc } = useTranslation('common');
  const { user } = useAuth();
  const {
    currentConversation,
    members,
    conversations,
    setCurrentConversation,
    fetchMembers,
    updateGroup,
    addMembers,
    removeMember,
    leaveGroup,
  } = useChatStore();

  const [editingName, setEditingName] = useState(false);
  const [nameInput, setNameInput] = useState('');
  const [showAddMember, setShowAddMember] = useState(false);
  const [newMemberIds, setNewMemberIds] = useState<string[]>([]);

  useEffect(() => {
    if (!conversationId) return;
    if (!currentConversation) {
      const conv = conversations.find((c) => c.id === conversationId);
      if (conv) setCurrentConversation(conv);
    }
    fetchMembers(conversationId);
  }, [conversationId, conversations, currentConversation, setCurrentConversation, fetchMembers]);

  const conv = currentConversation;
  const memberList = conversationId ? members[conversationId] || [] : [];
  const isAdmin = conv?.admin_ids?.includes(user?.id || '') || false;

  const handleSaveName = async () => {
    if (!conversationId || !nameInput.trim()) return;
    const result = await updateGroup(conversationId, { name: nameInput.trim() });
    if (result) {
      setEditingName(false);
      toast(tc('status.saving'), 'success');
    }
  };

  const handleAddMembers = async () => {
    if (!conversationId || newMemberIds.length === 0) return;
    const ok = await addMembers(conversationId, newMemberIds);
    if (ok) {
      setShowAddMember(false);
      setNewMemberIds([]);
      toast(t('add_member'), 'success');
    }
  };

  const handleRemoveMember = async (userId: string) => {
    if (!conversationId) return;
    await removeMember(conversationId, userId);
  };

  const handleLeave = async () => {
    if (!conversationId) return;
    const ok = await leaveGroup(conversationId);
    if (ok) {
      navigate('/');
    }
  };

  if (!conv) {
    return (
      <div className="flex items-center justify-center py-20">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-4">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => navigate(`/conversations/${conversationId}`)}
          className="rounded-full p-1 text-gray-500 hover:bg-gray-100"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">{t('group_settings')}</h1>
      </div>

      {/* Group name */}
      <div className="rounded-xl bg-white p-4 shadow-sm">
        <label className="mb-1 block text-xs font-medium text-gray-500">{t('group_name')}</label>
        {editingName ? (
          <div className="flex gap-2">
            <input
              type="text"
              value={nameInput}
              onChange={(e) => setNameInput(e.target.value)}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-rose-500 focus:outline-none"
            />
            <Button size="sm" onClick={handleSaveName}>{tc('actions.save')}</Button>
            <Button size="sm" variant="outline" onClick={() => setEditingName(false)}>{tc('actions.cancel')}</Button>
          </div>
        ) : (
          <div className="flex items-center justify-between">
            <span className="text-base font-medium text-gray-900">{conv.name || '...'}</span>
            {isAdmin && (
              <button
                type="button"
                onClick={() => { setNameInput(conv.name || ''); setEditingName(true); }}
                className="text-sm text-rose-500 hover:underline"
              >
                {tc('actions.edit')}
              </button>
            )}
          </div>
        )}
      </div>

      {/* Goukon expiry */}
      {conv.type === 'goukon' && conv.expires_at && (
        <div className="rounded-xl bg-purple-50 p-4">
          <span className="text-sm font-medium text-purple-700">
            {t('expires_in', { time: formatCountdown(conv.expires_at) })}
          </span>
        </div>
      )}

      {/* Members */}
      <div className="rounded-xl bg-white p-4 shadow-sm">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-base font-semibold text-gray-800">
            {t('members')} ({memberList.length})
          </h2>
          {isAdmin && (
            <Button size="sm" variant="outline" onClick={() => setShowAddMember(true)}>
              {t('add_member')}
            </Button>
          )}
        </div>
        <div className="space-y-2">
          {memberList.map((member) => (
            <div key={member.user_id} className="flex items-center gap-3">
              <Avatar
                name={member.nickname || member.user_id}
                src={member.primary_photo?.thumbnail_url}
                size="md"
              />
              <div className="flex-1 min-w-0">
                <p className="truncate text-sm font-medium text-gray-900">
                  {member.nickname || member.user_id.slice(-6)}
                </p>
                {member.is_admin && (
                  <span className="text-[10px] font-medium text-rose-500">{t('admin')}</span>
                )}
              </div>
              {isAdmin && member.user_id !== user?.id && (
                <button
                  type="button"
                  onClick={() => handleRemoveMember(member.user_id)}
                  className="rounded-full p-1.5 text-gray-400 hover:bg-gray-100 hover:text-red-500"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                  </svg>
                </button>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Leave button */}
      <Button variant="danger" fullWidth onClick={handleLeave}>
        {t('leave_group')}
      </Button>

      {/* Add member modal */}
      <Modal
        isOpen={showAddMember}
        onClose={() => { setShowAddMember(false); setNewMemberIds([]); }}
        title={t('add_member')}
      >
        <MemberPicker
          selectedIds={newMemberIds}
          onToggle={(id) =>
            setNewMemberIds((prev) =>
              prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
            )
          }
          excludeIds={memberList.map((m) => m.user_id)}
        />
        <div className="mt-4">
          <Button
            fullWidth
            onClick={handleAddMembers}
            disabled={newMemberIds.length === 0}
          >
            {t('add_member')} ({newMemberIds.length})
          </Button>
        </div>
      </Modal>
    </div>
  );
}
