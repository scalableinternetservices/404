class ConversationsController < ApplicationController
  include JwtAuth

  # GET /conversations
  def index
    convs = Conversation
              .includes(:initiator, :assigned_expert)
              .where("initiator_id = :id OR assigned_expert_id = :id", id: current_user.id)
              .order(updated_at: :desc)

    render json: convs.map { |c| conversation_payload(c) }
  end

  # GET /conversations/:id
  def show
    conv = find_visible_conversation!(params[:id])
    return unless conv

    render json: conversation_payload(conv)
  end

  # POST /conversations
  def create
    conv = Conversation.new(title: params[:title], initiator: current_user, status: "waiting")

    if conv.save
      # LLM generated expert assignment
      expert_user = LlmService.get_expert(conv)
      if expert_user
        puts expert_user.username
        conv.update!(assigned_expert_id: expert_user.id, status: 'active')
        ExpertAssignment.create!(conversation_id: conv.id, expert_id: expert_user.id, status: 'active', assigned_at: Time.current)
      end

      render json: conversation_payload(conv), status: :created
    else
      render json: { errors: conv.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def find_visible_conversation!(id)
    conv = Conversation.find_by(id: id)
    if conv && (conv.initiator_id == current_user.id || conv.assigned_expert_id == current_user.id)
      return conv
    end
    render json: { error: "Conversation not found" }, status: :not_found and return
  end

  def conversation_payload(c)
    {
      id: c.id.to_s,
      title: c.title,
      status: c.status,
      questionerId: c.initiator_id.to_s,
      questionerUsername: c.initiator&.username,
      assignedExpertId: c.assigned_expert_id&.to_s,
      assignedExpertUsername: c.assigned_expert&.username,
      createdAt: c.created_at&.iso8601,
      updatedAt: c.updated_at&.iso8601,
      lastMessageAt: c.last_message_at&.iso8601,
      unreadCount: 0,
      summary: LlmService.summarize_conversation(c)
    }
  end


end
