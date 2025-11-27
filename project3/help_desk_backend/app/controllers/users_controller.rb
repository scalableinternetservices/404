class UsersController < ApplicationController
  # POST /users/register
  def register
    user = User.new(user_params)
    if user.save
      # Optional: create a default expert profile, keeps parity with AuthController
      user.create_expert_profile!
      render json: user_payload(user), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(:username, :password)
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
