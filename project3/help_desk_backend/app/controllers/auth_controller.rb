class AuthController < ApplicationController
  # Register a new user account and create a session
  def register
    user = User.new(username: params[:username], password: params[:password])
    if user.save
      user.create_expert_profile!
      session[:user_id] = user.id
      render json: { user: user_payload(user), token: JwtService.encode(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Login with username and password
  def login
    user = User.find_by(username: params[:username])
    if user&.authenticate(params[:password])
      reset_session
      session[:user_id] = user.id
      render json: { user: user_payload(user), token: JwtService.encode(user) }, status: :ok
    else
      render json: { error: "Invalid username or password" }, status: :unauthorized
    end
  end

  # Logout the current user
  def logout
    reset_session
    # Touch the session so AR store persists the new, empty session row
    session[:_new] = true
    render json: { message: "Logged out successfully" }
  end

  # Refresh JWT using session cookie
  def refresh
    if current_user
      render json: { user: user_payload(current_user), token: JwtService.encode(current_user) }, status: :ok
    else
      render json: { error: "No session found" }, status: :unauthorized
    end
  end

  # Get the current user from the session
  def me
    if current_user
      render json: user_payload(current_user), status: :ok
    else
      render json: { error: "No session found" }, status: :unauthorized
    end
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def user_payload(user)
    {
      id: user.id,
      username: user.username,
      created_at: user.created_at,
      last_active_at: user.updated_at
    }
  end
end
