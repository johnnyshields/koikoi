import { create } from 'zustand';
import { chatApi } from '../api/chat';
import type { Conversation, ChatMessage, MemberInfo } from '../types';

interface ChatState {
  conversations: Conversation[];
  currentConversation: Conversation | null;
  messages: Record<string, ChatMessage[]>;
  members: Record<string, MemberInfo[]>;
  unreadCount: number;
  isLoading: boolean;
  error: string | null;

  fetchConversations: () => Promise<void>;
  fetchMessages: (conversationId: string, before?: string) => Promise<void>;
  sendMessage: (conversationId: string, content: string) => Promise<void>;
  markRead: (conversationId: string) => Promise<void>;
  fetchUnreadCount: () => Promise<void>;
  addMessage: (message: ChatMessage) => void;
  setCurrentConversation: (conversation: Conversation | null) => void;
  clearError: () => void;
  createDm: (friendId: string) => Promise<Conversation | null>;
  createGroup: (name: string, memberIds: string[]) => Promise<Conversation | null>;
  createGoukon: (name: string, memberIds: string[], expiresInHours: number) => Promise<Conversation | null>;
  addMembers: (conversationId: string, memberIds: string[]) => Promise<boolean>;
  removeMember: (conversationId: string, userId: string) => Promise<boolean>;
  leaveGroup: (conversationId: string) => Promise<boolean>;
  updateGroup: (conversationId: string, attrs: { name?: string }) => Promise<Conversation | null>;
  fetchMembers: (conversationId: string) => Promise<void>;
}

export const useChatStore = create<ChatState>((set, get) => ({
  conversations: [],
  currentConversation: null,
  messages: {},
  members: {},
  unreadCount: 0,
  isLoading: false,
  error: null,

  fetchConversations: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await chatApi.listConversations();
      set({ conversations: data.conversations, isLoading: false });
    } catch {
      set({ error: 'Failed to load conversations', isLoading: false });
    }
  },

  fetchMessages: async (conversationId, before) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await chatApi.listMessages(conversationId, before);
      const existing = get().messages[conversationId] || [];
      const newMessages = before
        ? [...data.messages, ...existing]
        : data.messages;
      set({
        messages: { ...get().messages, [conversationId]: newMessages },
        isLoading: false,
      });
    } catch {
      set({ error: 'Failed to load messages', isLoading: false });
    }
  },

  sendMessage: async (conversationId, content) => {
    try {
      const { data } = await chatApi.sendMessage(conversationId, content);
      const existing = get().messages[conversationId] || [];
      set({
        messages: {
          ...get().messages,
          [conversationId]: [...existing, data.message],
        },
      });
    } catch {
      set({ error: 'Failed to send message' });
    }
  },

  markRead: async (conversationId) => {
    try {
      await chatApi.markRead(conversationId);
    } catch {
      // silent fail
    }
  },

  fetchUnreadCount: async () => {
    try {
      const { data } = await chatApi.getUnreadCount();
      set({ unreadCount: data.unread_count });
    } catch {
      // silent fail
    }
  },

  addMessage: (message) => {
    const existing = get().messages[message.conversation_id] || [];
    const alreadyExists = existing.some((m) => m.id === message.id);
    if (alreadyExists) return;

    set({
      messages: {
        ...get().messages,
        [message.conversation_id]: [...existing, message],
      },
    });

    // Update conversation's last_message
    const conversations = get().conversations.map((c) =>
      c.id === message.conversation_id
        ? { ...c, last_message: message, last_message_at: message.inserted_at }
        : c,
    );
    set({ conversations });
  },

  setCurrentConversation: (conversation) =>
    set({ currentConversation: conversation }),

  clearError: () => set({ error: null }),

  createDm: async (friendId) => {
    try {
      const { data } = await chatApi.createDm(friendId);
      const conversations = get().conversations;
      const exists = conversations.some((c) => c.id === data.conversation.id);
      if (!exists) {
        set({ conversations: [data.conversation, ...conversations] });
      }
      return data.conversation;
    } catch {
      set({ error: 'Failed to create conversation' });
      return null;
    }
  },

  createGroup: async (name, memberIds) => {
    try {
      const { data } = await chatApi.createGroup(name, memberIds);
      const conversations = get().conversations;
      set({ conversations: [data.conversation, ...conversations] });
      return data.conversation;
    } catch {
      set({ error: 'Failed to create group' });
      return null;
    }
  },

  createGoukon: async (name, memberIds, expiresInHours) => {
    try {
      const { data } = await chatApi.createGoukon(name, memberIds, expiresInHours);
      const conversations = get().conversations;
      set({ conversations: [data.conversation, ...conversations] });
      return data.conversation;
    } catch {
      set({ error: 'Failed to create goukon' });
      return null;
    }
  },

  addMembers: async (conversationId, memberIds) => {
    try {
      await chatApi.addMembers(conversationId, memberIds);
      await get().fetchMembers(conversationId);
      return true;
    } catch {
      set({ error: 'Failed to add members' });
      return false;
    }
  },

  removeMember: async (conversationId, userId) => {
    try {
      await chatApi.removeMember(conversationId, userId);
      const current = get().members[conversationId] || [];
      set({
        members: {
          ...get().members,
          [conversationId]: current.filter((m) => m.user_id !== userId),
        },
      });
      return true;
    } catch {
      set({ error: 'Failed to remove member' });
      return false;
    }
  },

  leaveGroup: async (conversationId) => {
    try {
      await chatApi.leaveGroup(conversationId);
      set({
        conversations: get().conversations.filter((c) => c.id !== conversationId),
      });
      return true;
    } catch {
      set({ error: 'Failed to leave group' });
      return false;
    }
  },

  updateGroup: async (conversationId, attrs) => {
    try {
      const { data } = await chatApi.updateGroup(conversationId, attrs);
      set({
        conversations: get().conversations.map((c) =>
          c.id === conversationId ? data.conversation : c,
        ),
      });
      if (get().currentConversation?.id === conversationId) {
        set({ currentConversation: data.conversation });
      }
      return data.conversation;
    } catch {
      set({ error: 'Failed to update group' });
      return null;
    }
  },

  fetchMembers: async (conversationId) => {
    try {
      const { data } = await chatApi.listMembers(conversationId);
      set({
        members: { ...get().members, [conversationId]: data.members },
      });
    } catch {
      // silent fail
    }
  },
}));
