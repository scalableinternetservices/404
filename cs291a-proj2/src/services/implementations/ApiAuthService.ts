import type {
  AuthService,
  RegisterRequest,
  User,
  AuthServiceConfig,
} from '@/types';
import TokenManager from '@/services/TokenManager';

/**
 * API-based implementation of AuthService
 * Uses fetch for HTTP requests based on API_SPECIFICATION.md
 */
export class ApiAuthService implements AuthService {
  private baseUrl: string;
  private tokenManager: TokenManager;

  constructor(config: AuthServiceConfig) {
    // Note: The specification shows the base URL as http://localhost:3001,
    // but the original code defaults to http://localhost:3000.
    // We will use the provided config/default as the source of truth for the base URL.
    this.baseUrl = config.baseUrl || 'http://localhost:3000';
    this.tokenManager = TokenManager.getInstance();
  }

  /**
   * Helper method to handle fetch requests, URL construction, headers,
   * credentials, and error handling.
   */
  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // 1. Construct the full URL
    const url = `${this.baseUrl}${endpoint}`;

    // 2. Set up default headers including 'Content-Type' and Authorization
    const defaultHeaders = {
      'Content-Type': 'application/json',
      // Add Authorization header if a token exists
      ...(this.tokenManager.getToken() && {
        Authorization: `Bearer ${this.tokenManager.getToken()}`,
      }),
    };

    const finalOptions: RequestInit = {
      ...options,
      headers: {
        ...defaultHeaders,
        // Allow request-specific headers to override defaults
        ...options.headers,
      },
      // 3. Use {credentials: 'include'} for session cookies (required by /auth/refresh)
      credentials: 'include',
    };

    // 4. Make the fetch request
    const response = await fetch(url, finalOptions);

    // 5. Handle non-ok responses
    if (!response.ok) {
      let errorMessage = `HTTP error! Status: ${response.status}`;
      try {
        const errorBody = await response.json();
        // Extract error message from 'error' (401) or 'errors' (422) field
        if (errorBody.error) {
          errorMessage = errorBody.error;
        } else if (errorBody.errors && Array.isArray(errorBody.errors)) {
          errorMessage = errorBody.errors.join('; ');
        }
      } catch (e) {
        // If parsing fails, stick with the generic error message
      }
      // Throw an error with status and message, passing status in the 'cause'
      throw new Error(errorMessage, { cause: response.status });
    }

    // Check for 204 No Content, which doesn't have a body
    if (response.status === 204) {
      return {} as T; // Return an empty object for void/no-content responses
    }

    // 6. Return the parsed JSON response
    return response.json() as Promise<T>;
  }

  // --- Auth Methods Implementation ---

  async login(username: string, password: string): Promise<User> {
    // Endpoint: POST /auth/login, returns { user: User, token: string }
    const response = await this.makeRequest<{ user: User; token: string }>(
      '/auth/login',
      {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      }
    );

    // 2. Store the token
    this.tokenManager.setToken(response.token);

    // 3. Return the user object
    return response.user;
  }

  async register(userData: RegisterRequest): Promise<User> {
    // Endpoint: POST /auth/register, returns { user: User, token: string }
    const response = await this.makeRequest<{ user: User; token: string }>(
      '/auth/register',
      {
        method: 'POST',
        body: JSON.stringify(userData),
      }
    );

    // 2. Store the token
    this.tokenManager.setToken(response.token);

    // 3. Return the user object
    return response.user;
  }

  async logout(): Promise<void> {
    // Endpoint: POST /auth/logout, returns { message: string }
    try {
      // 1. Make a request to the appropriate endpoint
      await this.makeRequest<void>('/auth/logout', { method: 'POST' });
    } catch (error) {
      // 2. Handle errors gracefully (continue with logout even if API call fails)
      console.warn('Logout API call failed, proceeding with local clear:', error);
    }
    // 3. Clear the token
    this.tokenManager.clearToken();
  }

  async refreshToken(): Promise<User> {
    // Endpoint: POST /auth/refresh, returns { user: User, token: string }
    // Authentication relies on the session cookie (credentials: 'include')
    const response = await this.makeRequest<{ user: User; token: string }>(
      '/auth/refresh',
      {
        method: 'POST',
      }
    );

    // 3. Update the stored token
    this.tokenManager.setToken(response.token);

    // 4. Return the user object
    return response.user;
  }

  async getCurrentUser(): Promise<User | null> {
    // Endpoint: GET /auth/me, returns User object directly
    try {
      // 1. Make a request to the appropriate endpoint
      const user = await this.makeRequest<User>('/auth/me', {
        method: 'GET',
      });
      // 2. Return the user object if successful
      return user;
    } catch (error) {
      // 3. If the request fails (e.g., status 401 Unauthorized)
      const errorStatus = (error as Error & { cause?: unknown }).cause;

      if (errorStatus === 401) {
        console.warn('getCurrentUser failed (Unauthorized). Clearing local token.');
        this.tokenManager.clearToken(); // Clear the token
        return null; // Return null
      }

      // Re-throw other unexpected errors (e.g., network issues, 5xx errors)
      throw error;
    }
  }
}