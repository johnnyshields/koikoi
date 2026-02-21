import { create } from 'zustand';
import { chatApi } from '../api/chat';
import type { Conversation, ChatMessage } from '../types';

interface ChatState {
  conversations: Conversation[];
  currentConversation: Conversation | null;
  messages: Record<string, ChatMessage[]>;
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
}

export const useChatStore = create<ChatState>((set, get) => ({
  conversations: [],
  currentConversation: null,
  messages: {},
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
}));
