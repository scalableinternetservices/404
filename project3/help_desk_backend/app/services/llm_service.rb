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
    summary_record = ConversationSummary.find_by(conversation_id: conversation.id)
    last_processed_id = summary_record&.last_message_id

    if summary_record.nil?
      # No summary yet: summarize all messages
      messages = conversation.messages.order(:created_at)
      prompt = build_prompt_for_summary(conversation, messages)
      client = BedrockClient.new(model_id: MODEL_ID)
      response = client.call(
        system_prompt: "You are a helpful assistant that produces short and accurate summaries.",
        user_prompt: prompt
      )
      summary_text = response[:output_text].to_s.strip
      last_id = messages.last&.id
      ConversationSummary.create!(conversation_id: conversation.id,
                                  summary_text: summary_text,
                                  last_message_id: last_id)
      summary_text
    else
      # Incremental update: only new messages since last_message_id
      new_messages = conversation.messages.where("id > ?", last_processed_id || 0).order(:created_at)
      return summary_record.summary_text if new_messages.empty?

      incremental_prompt = build_prompt_for_incremental_summary(conversation,
                                                                summary_record.summary_text,
                                                                new_messages)
      client = BedrockClient.new(model_id: MODEL_ID)
      response = client.call(
        system_prompt: "You are a helpful assistant that updates an existing summary concisely.",
        user_prompt: incremental_prompt
      )
      updated_text = response[:output_text].to_s.strip
      summary_record.update!(summary_text: updated_text,
                             last_message_id: new_messages.last.id)
      updated_text
    end
  end

  def self.auto_response(conversation, user_message)
    expert = conversation.assigned_expert
    return nil unless expert&.expert_profile

    faq_links = expert.expert_profile.knowledge_base_links || []
    bio = expert.expert_profile.bio

    prompt = build_auto_response_prompt(
      conversation.title,
      user_message,
      faq_links,
      bio,
      expert.username
    )

    client = BedrockClient.new(model_id: MODEL_ID)

    response = client.call(
      system_prompt: "You are an expert assistant. Answer based ONLY on the expert's KB Links and Bio.",
      user_prompt: prompt
    )

    puts prompt

    response[:output_text].strip
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

  def self.build_prompt_for_incremental_summary(conversation, existing_summary, new_messages)
    formatted_messages = new_messages.map do |m|
      role = m.sender_role == "initiator" ? "User" : "Expert"
      "#{role}: #{m.content}"
    end.join("\n")

    <<~PROMPT
    Update the existing summary with the following new messages.
    Keep the summary short and accurate. If the new messages don't change the summary materially, keep it as-is but incorporate any important details.

    Conversation Title: "#{conversation.title}"

    Existing Summary:
    #{existing_summary}

    New Messages:
    #{formatted_messages}

    Provide the updated summary only.
    PROMPT
  end

  def self.build_auto_response_prompt(title, user_msg, kb_links, bio, username)
    formatted_kb = kb_links.map { |l| "- #{l}" }.join("\n")

    <<~PROMPT
    The expert assigned to this conversation is: #{username}.

    Expert Bio:
    #{bio}

    Expert Knowledge Base (FAQ):
    #{formatted_kb}

    Task:
    - Answer the user's question based ONLY on the above FAQ and bio.
    - If the FAQ does not help, reply with: "Let me check and get back to you shortly."
    - Keep the answer short and helpful.

    User asked:
    "#{user_msg}"

    Generate the auto-response now.
    PROMPT
  end

end
