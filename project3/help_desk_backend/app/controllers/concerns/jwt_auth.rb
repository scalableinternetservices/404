module JwtAuth
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_jwt!
  end

  private

  def authenticate_jwt!
    
    auth_header = request.headers["Authorization"].to_s
    token = auth_header.start_with?("Bearer ") ? auth_header.split(" ", 2).last : nil
    payload = token.present? ? JwtService.decode(token) : nil
    @current_user = payload && User.find_by(id: payload[:user_id])

  
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id].present?
    return if @current_user

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_user
  end
end
