import type { ChatService } from '@/types';
import type {
  Conversation,
  CreateConversationRequest,
  UpdateConversationRequest,
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

  constructor(config: ApiChatServiceConfig) {
    this.baseUrl = config.baseUrl;
    this.tokenManager = TokenManager.getInstance();
  }

  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // TODO: Implement the makeRequest helper method
    // This should:
    // 1. Construct the full URL using this.baseUrl and endpoint
    const url = this.baseUrl + endpoint;
    // 2. Get the token using this.tokenManager.getToken()
    const token = this.tokenManager.getToken();
    // 3. Set up default headers including 'Content-Type': 'application/json'
    const defaultHeaders: Record<string, string> = {'Content-Type': 'application/json', ... options.headers as Record<string, string>};
    // 4. Add Authorization header with Bearer token if token exists
    if(token) {
       defaultHeaders.Authorization = `Bearer ${token}`;
    }
    options.credentials = 'include';
    options.headers = defaultHeaders;
    // 5. Make the fetch request with the provided options
    const response = await fetch(url, options);
    // 6. Handle non-ok responses by throwing an error with status and message
    if(!response.ok) {
      const errorText = await response.text();
      throw new Error (`HTTP ${response.status}: ${errorText}`);
    }
    // 7. Return the parsed JSON response
    const data = await response.json();
    return data as T;
    // throw new Error('makeRequest method not implemented');
  }

  // Conversations
  async getConversations(): Promise<Conversation[]> {
    // TODO: Implement getConversations method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of conversations
    //
    // See API_SPECIFICATION.md for endpoint details

    return await this.makeRequest<Conversation[]>('/conversations', {method: 'GET'});

    // throw new Error('getConversations method not implemented');
  }

  async getConversation(_id: string): Promise<Conversation> {
    // TODO: Implement getConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the conversation object
    //
    // See API_SPECIFICATION.md for endpoint details
    return await this.makeRequest<Conversation>(`/conversations/${_id}`, {method: 'GET'});

    // throw new Error('getConversation method not implemented');
  }

  async createConversation(
    request: CreateConversationRequest
  ): Promise<Conversation> {
    // TODO: Implement createConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created conversation object
    //
    // See API_SPECIFICATION.md for endpoint details

    return await this.makeRequest<Conversation>('/conversations', {method: 'POST', body: JSON.stringify(request)})
    
    // throw new Error('createConversation method not implemented');
  }

  async updateConversation(
    id: string,
    request: UpdateConversationRequest
  ): Promise<Conversation> {
    // SKIP, not currently used by application

    throw new Error('updateConversation method not implemented');
  }

  async deleteConversation(id: string): Promise<void> {
    // SKIP, not currently used by application

    throw new Error('deleteConversation method not implemented');
  }

  // Messages
  async getMessages(conversationId: string): Promise<Message[]> {
    // TODO: Implement getMessages method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of messages
    //
    // See API_SPECIFICATION.md for endpoint details

    return await this.makeRequest<Message[]>(`/conversations/${conversationId}/messages`, {method: 'GET'});
  
    // throw new Error('getMessages method not implemented');
  }

  async sendMessage(request: SendMessageRequest): Promise<Message> {
    // TODO: Implement sendMessage method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created message object
    //
    // See API_SPECIFICATION.md for endpoint details

    return await this.makeRequest<Message>('/messages',
       {method: 'POST', body: JSON.stringify(request)});

    // throw new Error('sendMessage method not implemented');
  }

  async markMessageAsRead(messageId: string): Promise<void> {
    // SKIP, not currently used by application

    throw new Error('markMessageAsRead method not implemented');
  }

  // Expert-specific operations
  async getExpertQueue(): Promise<ExpertQueue> {
    // TODO: Implement getExpertQueue method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert queue object with waitingConversations and assignedConversations
    //
    // See API_SPECIFICATION.md for endpoint details
    return await this.makeRequest<ExpertQueue>('/expert/queue', {method: 'GET'});
    // throw new Error('getExpertQueue method not implemented');
  }

  async claimConversation(conversationId: string): Promise<void> {
    // TODO: Implement claimConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected)
    //
    // See API_SPECIFICATION.md for endpoint details
    return await this.makeRequest<void>(`/expert/conversations/${conversationId}/claim`, {method: 'POST'});
    // throw new Error('claimConversation method not implemented');
  }

  async unclaimConversation(conversationId: string): Promise<void> {
    // TODO: Implement unclaimConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected)
    //
    // See API_SPECIFICATION.md for endpoint details
    return await this.makeRequest<void>(`/expert/conversations/${conversationId}/unclaim`, {method: 'POST'});
    // throw new Error('unclaimConversation method not implemented');
  }

  async getExpertProfile(): Promise<ExpertProfile> {
    // TODO: Implement getExpertProfile method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert profile object
    //
    // See API_SPECIFICATION.md for endpoint details
    return await this.makeRequest<ExpertProfile>('/expert/profile', {method: 'GET'});
    // throw new Error('getExpertProfile method not implemented');
  }

  async updateExpertProfile(
    request: UpdateExpertProfileRequest
  ): Promise<ExpertProfile> {
    // TODO: Implement updateExpertProfile method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the updated expert profile object
    //
    // See API_SPECIFICATION.md for endpoint details
    return await this.makeRequest<ExpertProfile>('/expert/profile', {method: 'PUT', 
      body: JSON.stringify(request)});
    // throw new Error('updateExpertProfile method not implemented');
  }

  async getExpertAssignmentHistory(): Promise<ExpertAssignment[]> {
    // TODO: Implement getExpertAssignmentHistory method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of expert assignments
    //
    // See API_SPECIFICATION.md for endpoint details

    return await this.makeRequest<ExpertAssignment[]>('/expert/assignments/history', {method: 'GET'});

    // throw new Error('getExpertAssignmentHistory method not implemented');
  }
}
