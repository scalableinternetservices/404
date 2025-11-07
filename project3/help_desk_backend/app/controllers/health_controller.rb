class HealthController < ApplicationController
  # GET /health
  def index
    render json: { status: "ok", timestamp: Time.now.utc }
  end
end
