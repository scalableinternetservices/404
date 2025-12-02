class AutoassignExpertJob
  include Sidekiq::Job

  def perform(conversation_id)
    conv = Conversation.find(conversation_id)
    expert_user = LlmService.get_expert(conv)
    if expert_user
      puts expert_user.username
      conv.update!(assigned_expert_id: expert_user.id, status: 'active')
      ExpertAssignment.create!(conversation_id: conv.id, expert_id: expert_user.id, status: 'active', assigned_at: Time.current)
    end

    # auto-generate a reply if a message has already been sent
    conv.reload
    if conv.messages.any?
      GenerateAutoreplyJob.perform_async(conv.messages.first.id)
    end

  end
end
