import type {
  AuthService,
  RegisterRequest,
  User,
  AuthServiceConfig,
} from '@/types';
import TokenManager from '@/services/TokenManager';

/**
 * API-based implementation of AuthService
 * Uses fetch for HTTP requests
 */
export class ApiAuthService implements AuthService {
  private baseUrl: string;
  private tokenManager: TokenManager;

  constructor(config: AuthServiceConfig) {
    this.baseUrl = config.baseUrl || 'http://localhost:3000';
    this.tokenManager = TokenManager.getInstance();
  }

  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // TODO: Implement the makeRequest helper method
    // This should:
    // 1. Construct the full URL using this.baseUrl and endpoint
    const url = `${this.baseUrl}${endpoint}`;

    // 2. Set up default headers including 'Content-Type': 'application/json'


    // 3. Use {credentials: 'include'} for session cookies


    // 4. Make the fetch request with the provided options


    // 5. Handle non-ok responses by throwing an error with status and message


    // 6. Return the parsed JSON response
    
    

    throw new Error('makeRequest method not implemented');
  }

  async login(username: string, password: string): Promise<User> {
    // TODO: Implement login method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Store the token using this.tokenManager.setToken(response.token)
    // 3. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

    throw new Error('login method not implemented');
  }

  async register(userData: RegisterRequest): Promise<User> {
    // TODO: Implement register method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Store the token using this.tokenManager.setToken(response.token)
    // 3. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

    throw new Error('register method not implemented');
  }

  async logout(): Promise<void> {
    // TODO: Implement logout method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Handle errors gracefully (continue with logout even if API call fails)
    // 3. Clear the token using this.tokenManager.clearToken()
    //
    // See API_SPECIFICATION.md for endpoint details

    throw new Error('logout method not implemented');
  }

  async refreshToken(): Promise<User> {
    // TODO: Implement refreshToken method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 3. Update the stored token using this.tokenManager.setToken(response.token)
    // 4. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

    throw new Error('refreshToken method not implemented');
  }

  async getCurrentUser(): Promise<User | null> {
    // TODO: Implement getCurrentUser method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the user object if successful
    // 3. If the request fails (e.g., session invalid), clear the token and return null
    //
    // See API_SPECIFICATION.md for endpoint details

    throw new Error('getCurrentUser method not implemented');
  }
}
