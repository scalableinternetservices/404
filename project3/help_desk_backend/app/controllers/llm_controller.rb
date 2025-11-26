class LlmController < ApplicationController
  # POST /llm
  # Expected JSON body:
  # {
  #   "system_prompt": "You are a helpful assistant.",
  #   "user_prompt": "Explain eventual consistency." 
  # }
  # Optional ENV vars:
  #   BEDROCK_MODEL_ID (default anthropic.claude-3-5-haiku-20241022-v1:0)
  #   ALLOW_BEDROCK_CALL=true to enable real calls
  # Response example:
  # {
  #   "ok": true,
  #   "message": "Eventual consistency means...",
  #   "model_id": "anthropic.claude-3-5-haiku-20241022-v1:0",
  #   "fake": false,
  #   "usage": { "input_tokens": 42, "output_tokens": 128 },
  #   "latency_ms": 873
  # }
  def create
    sys = params[:system_prompt].to_s.strip
    usr = params[:user_prompt].to_s.strip

    if sys.empty? || usr.empty?
      return render json: { ok: false, error: "system_prompt and user_prompt are required" }, status: :unprocessable_entity
    end

    model_id = ENV["BEDROCK_MODEL_ID"].presence || "anthropic.claude-3-5-haiku-20241022-v1:0"
    client = BedrockClient.new(model_id: model_id)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = client.call(system_prompt: sys, user_prompt: usr)
    finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    raw = result[:raw_response]
    usage = {
      input_tokens: raw&.usage&.input_tokens,
      output_tokens: raw&.usage&.output_tokens,
      total_tokens: raw&.usage&.total_tokens
    }.compact

    render json: {
      ok: true,
      message: result[:output_text],
      model_id: model_id,
      fake: raw.nil?,
      usage: usage.empty? ? nil : usage,
      latency_ms: ((finished - started) * 1000).round
    }
  rescue => e
    render json: { ok: false, error: e.message }, status: :internal_server_error
  end
end
