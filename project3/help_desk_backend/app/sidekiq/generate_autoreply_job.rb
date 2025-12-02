class GenerateAutoreplyJob
  include Sidekiq::Job

  def perform(message_id)
    msg = Message.find(message_id)
    return unless msg
    conv = msg.conversation

    auto_text = LlmService.auto_response(conv, msg.content)
    if auto_text.present?
      conv.messages.create!(
        sender: conv.assigned_expert,
        sender_role: "expert",
        content: auto_text,
        is_auto_generated: true
      )
      conv.update!(last_message_at: Time.current)
    end
  end
end
