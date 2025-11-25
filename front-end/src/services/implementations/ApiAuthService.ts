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
    const url = this.baseUrl + endpoint;
    // 2. Set up default headers including 'Content-Type': 'application/json'
    const defaultHeaders = {"Content-Type": "application/json", ...options.headers};
    options.headers = defaultHeaders;
    // 3. Use {credentials: 'include'} for session cookies
    options.credentials = 'include';
    // 4. Make the fetch request with the provided options
    const response = await fetch(url, options);
    // 5. Handle non-ok responses by throwing an error with status and message
    if(!response.ok) {
      const msg = await response.text();
      throw new Error(`HTTP ${response.status}: ${msg}`);
    }
    // 6. Return the parsed JSON response
    const data = await response.json();
    // console.log(data);
    return data as T;
    // throw new Error('makeRequest method not implemented');
  }

  async login(username: string, password: string): Promise<User> {
    // 1. Make a request to the appropriate endpoint
    const response = await this.makeRequest<{user: User, token: string}>('/auth/login', {method: 'POST', body: 
      JSON.stringify({'username': username, 'password': password})
    });
    // 2. Store the token using this.tokenManager.setToken(response.token)
      this.tokenManager.setToken(response.token);
    // 3. Return the user object
    return response.user;
   
    // See API_SPECIFICATION.md for endpoint details

    // throw new Error('login method not implemented');
  }

  async register(userData: RegisterRequest): Promise<User> {
    // TODO: Implement register method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // console.log(userData);
    const response = await this.makeRequest<{user: User, token: string}>("/auth/register", {method: "POST",
    body: JSON.stringify(userData)})
    // 2. Store the token using this.tokenManager.setToken(response.token)
    this.tokenManager.setToken(response.token)
    // 3. Return the user object
    return response.user;
    // See API_SPECIFICATION.md for endpoint details
    // throw new Error('register method not implemented');
  }

  async logout(): Promise<void> {
    // TODO: Implement logout method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Handle errors gracefully (continue with logout even if API call fails)
    // 3. Clear the token using this.tokenManager.clearToken()
    //
    // See API_SPECIFICATION.md for endpoint details

    try{
    const response = await this.makeRequest<{message:string}>('/auth/logout', 
      {method: 'POST'}
    );
    console.log(response);
    this.tokenManager.clearToken();
    } catch(error: any) {
      this.tokenManager.clearToken();
      }
    // throw new Error('logout method not implemented');
  }

  async refreshToken(): Promise<User> {
    // TODO: Implement refreshToken method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 3. Update the stored token using this.tokenManager.setToken(response.token)
    // 4. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

     const response = await this.makeRequest<{user: User, token: string}>
      ('/auth/refresh', {method: 'POST'});
      this.tokenManager.setToken(response.token);
      return response.user;

    // throw new Error('refreshToken method not implemented');
  }

  async getCurrentUser(): Promise<User | null> {
    // TODO: Implement getCurrentUser method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the user object if successful
    // 3. If the request fails (e.g., session invalid), clear the token and return null
    //
    // See API_SPECIFICATION.md for endpoint details
    
    // const response = await this.makeRequest<User>('/auth/me', {
    //     method:'GET'
    //   });
    //   return response;


    try {
      const response = await this.makeRequest<User>('/auth/me', {
        method:'GET'
      });
      return response;
    } catch (error: any) {
      this.tokenManager.clearToken();
      return null;
    }

    // throw new Error('getCurrentUser method not implemented');
  }
}
