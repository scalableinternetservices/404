class LlmService
  MODEL_ID = "anthropic.claude-3-5-haiku-20241022-v1:0"

  def self.get_expert(conversation)
    prompt = build_prompt_for_exper_user(conversation)

    client = BedrockClient.new(model_id: MODEL_ID)

    puts prompt

    response = client.call(
      system_prompt: "You are an assistant that selects the best expert for a conversation.",
      user_prompt: prompt
    )

    llm_output = response[:output_text].to_s.strip

    # Example: "bob" → find the expert user
    expert = User.find_by(username: llm_output)

    expert

    # response[:output_text]   # <-- return only the LLM conclusion
  end

  def self.summarize_conversation(conversation)
    messages = conversation.messages.order(:created_at)

    prompt = build_prompt_for_summary(conversation, messages)
    
    puts prompt

    client = BedrockClient.new(model_id: MODEL_ID)

    response = client.call(
      system_prompt: "You are a helpful assistant that produces short and accurate summaries.",
      user_prompt: prompt
    )

    summary = response[:output_text].to_s.strip
    summary
  end

  private

  def self.build_prompt_for_exper_user(conversation)
    experts = ExpertProfile.includes(:user).all

    expert_list = experts.map do |e|
      "Expert: #{e.user.username}, KB Links: #{Array(e.knowledge_base_links).join(", ")}, Bio: #{Array(e.bio).join(", ")}"
    end.join("\n")

    <<~PROMPT
    A new conversation has been created.

    Title: "#{conversation.title}"
    
    Available Experts:
    #{expert_list}

    Based on the topic, recommend the best expert.
    Return ONLY the username.
    PROMPT
  end

  def self.build_prompt_for_summary(conversation, messages)
    formatted_messages = messages.map do |m|
      role = m.sender_role == "initiator" ? "User" : "Expert"
      "#{role}: #{m.content}"
    end.join("\n")

    <<~PROMPT
    Summarize the following conversation in a clear and concise way.
    Highlight:
      - The main issue
      - What the user wants
      - Expert suggestions or responses
      - Current status (if any)

    Conversation Title: "#{conversation.title}"

    Conversation Messages:
    #{formatted_messages}

    Provide the final summary only.
    PROMPT
  end
  

end
