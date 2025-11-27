import type { ChatService } from '@/types';
import type {
  Conversation,
  CreateConversationRequest,
  // UpdateConversationRequest, // Not used
  Message,
  SendMessageRequest,
  ExpertProfile,
  ExpertQueue,
  ExpertAssignment,
  UpdateExpertProfileRequest,
} from '@/types';
import TokenManager from '@/services/TokenManager';

interface ApiChatServiceConfig {
  baseUrl: string;
  timeout: number;
  retryAttempts: number;
}

/**
 * API implementation of ChatService for production use
 * Uses fetch for HTTP requests
 */
export class ApiChatService implements ChatService {
  private baseUrl: string;
  private tokenManager: TokenManager;
  // Note: timeout and retryAttempts are part of the config but aren't implemented in this basic fetch model.

  constructor(config: ApiChatServiceConfig) {
    this.baseUrl = config.baseUrl;
    this.tokenManager = TokenManager.getInstance();
  }

  /**
   * Helper method to handle fetch requests, URL construction, headers,
   * authentication, and error handling.
   */
  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // 1. Construct the full URL
    const url = `${this.baseUrl}${endpoint}`;

    // 2. Get the token
    const token = this.tokenManager.getToken();

    // 3. Set up default headers
    const defaultHeaders = {
      'Content-Type': 'application/json',
    };

    // 4. Add Authorization header with Bearer token if token exists
    const authHeader = token ? { Authorization: `Bearer ${token}` } : {};

    const finalOptions: RequestInit = {
      ...options,
      headers: {
        ...defaultHeaders,
        ...authHeader,
        // Allow request-specific headers to override defaults
        ...options.headers,
      },
      // The API spec mentions session cookies, so credentials: 'include' is helpful
      credentials: 'include',
    };

    // 5. Make the fetch request
    const response = await fetch(url, finalOptions);

    // 6. Handle non-ok responses
    if (!response.ok) {
      let errorMessage = `HTTP error! Status: ${response.status}`;
      try {
        const errorBody = await response.json();
        // Extract error message from 'error' (401/404) or 'errors' (422) field
        if (errorBody.error) {
          errorMessage = errorBody.error;
        } else if (errorBody.errors && Array.isArray(errorBody.errors)) {
          errorMessage = errorBody.errors.join('; ');
        }
      } catch (e) {
        // If parsing fails, stick with the generic error message
      }
      // Throw an error with status and message
      throw new Error(errorMessage, { cause: response.status });
    }

    // Handle 204 No Content/success responses with no body (e.g., claim/unclaim, markMessageAsRead)
    const contentType = response.headers.get('content-type');
    if (response.status === 204 || (contentType && !contentType.includes('application/json'))) {
      return {} as T; // Return an empty object for void responses
    }
    
    // Check if the response is valid JSON before parsing
    if (contentType && contentType.includes('application/json')) {
      // 7. Return the parsed JSON response
      return response.json() as Promise<T>;
    }

    // Fallback for successful status with unexpected content
    return {} as T;
  }

  // --- Conversations ---

  async getConversations(): Promise<Conversation[]> {
    // Endpoint: GET /conversations, returns Conversation[]
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of conversations
    return this.makeRequest<Conversation[]>('/conversations', { method: 'GET' });
  }

  async getConversation(id: string): Promise<Conversation> {
    // Endpoint: GET /conversations/:id, returns Conversation
    // 1. Make a request to the appropriate endpoint
    // 2. Return the conversation object
    return this.makeRequest<Conversation>(`/conversations/${id}`, { method: 'GET' });
  }

  async createConversation(
    request: CreateConversationRequest
  ): Promise<Conversation> {
    // Endpoint: POST /conversations, returns Conversation
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created conversation object
    return this.makeRequest<Conversation>('/conversations', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  async updateConversation(
    _id: string,
    _request: unknown // Type is UpdateConversationRequest
  ): Promise<Conversation> {
    // SKIP, not currently used by application
    throw new Error('updateConversation method not implemented');
  }

  async deleteConversation(_id: string): Promise<void> {
    // SKIP, not currently used by application
    throw new Error('deleteConversation method not implemented');
  }

  // --- Messages ---

  async getMessages(conversationId: string): Promise<Message[]> {
    // Endpoint: GET /conversations/:conversation_id/messages, returns Message[]
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of messages
    return this.makeRequest<Message[]>(
      `/conversations/${conversationId}/messages`,
      { method: 'GET' }
    );
  }

  async sendMessage(request: SendMessageRequest): Promise<Message> {
    // Endpoint: POST /messages, returns Message
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created message object
    return this.makeRequest<Message>('/messages', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  async markMessageAsRead(messageId: string): Promise<void> {
    // Endpoint: PUT /messages/:id/read, returns { success: true }
    // Note: The API spec returns a body, but the `ChatService` interface expects void.
    // We'll treat the successful 200 status as the completion signal.
    return this.makeRequest<void>(`/messages/${messageId}/read`, {
      method: 'PUT',
    });
  }

  // --- Expert-specific operations ---

  async getExpertQueue(): Promise<ExpertQueue> {
    // Endpoint: GET /expert/queue, returns ExpertQueue
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert queue object
    return this.makeRequest<ExpertQueue>('/expert/queue', { method: 'GET' });
  }

  async claimConversation(conversationId: string): Promise<void> {
    // Endpoint: POST /expert/conversations/:conversation_id/claim, returns { success: true }
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected by the service interface)
    await this.makeRequest<void>(
      `/expert/conversations/${conversationId}/claim`,
      { method: 'POST' }
    );
  }

  async unclaimConversation(conversationId: string): Promise<void> {
    // Endpoint: POST /expert/conversations/:conversation_id/unclaim, returns { success: true }
    // 1. Make a request to the appropriate endpoint
    // 2. Return void
    await this.makeRequest<void>(
      `/expert/conversations/${conversationId}/unclaim`,
      { method: 'POST' }
    );
  }

  async getExpertProfile(): Promise<ExpertProfile> {
    // Endpoint: GET /expert/profile, returns ExpertProfile
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert profile object
    return this.makeRequest<ExpertProfile>('/expert/profile', { method: 'GET' });
  }

  async updateExpertProfile(
    request: UpdateExpertProfileRequest
  ): Promise<ExpertProfile> {
    // Endpoint: PUT /expert/profile, returns ExpertProfile
    // 1. Make a request to the appropriate endpoint
    // 2. Return the updated expert profile object
    return this.makeRequest<ExpertProfile>('/expert/profile', {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  async getExpertAssignmentHistory(): Promise<ExpertAssignment[]> {
    // Endpoint: GET /expert/assignments/history, returns ExpertAssignment[]
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of expert assignments
    return this.makeRequest<ExpertAssignment[]>(
      '/expert/assignments/history',
      { method: 'GET' }
    );
  }
}