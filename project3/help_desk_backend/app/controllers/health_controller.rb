class HealthController < ApplicationController
  # GET /health
  def index
    render json: { status: "ok", timestamp: Time.now.utc }
    #   client = BedrockClient.new(
    #   model_id: "anthropic.claude-3-5-haiku-20241022-v1:0",
    #   region: "us-west-2"
    # )
  
    # response = client.call(
    #   system_prompt: "You are a helpful assistant.",
    #   user_prompt:   "Explain how to get a perfect A"
    # )
  
    # puts response[:output_text]
  end
end
