class ExpertController < ApplicationController
  include JwtAuth

  # GET /expert/queue
  def queue
    waiting = Conversation
                .includes(:initiator, :assigned_expert)
                .where(status: 'waiting')
                .order(updated_at: :desc)

    assigned = Conversation
                 .includes(:initiator, :assigned_expert)
                 .where(status: 'active', assigned_expert_id: current_user.id)
                 .order(updated_at: :desc)

    render json: {
      waitingConversations: waiting.map { |c| conversation_payload(c) },
      assignedConversations: assigned.map { |c| conversation_payload(c) }
    }
  end

  # GET /expert/queue/updates
  def queue_updates
    since = parse_time(params[:since])
    waiting = Conversation.where(status: 'waiting')
    assigned = Conversation.where(status: 'active', assigned_expert_id: current_user.id)

    if since
      waiting = waiting.where("updated_at > :since OR (last_message_at IS NOT NULL AND last_message_at > :since)", since: since)
      assigned = assigned.where("updated_at > :since OR (last_message_at IS NOT NULL AND last_message_at > :since)", since: since)
    end

    waiting = waiting.includes(:initiator, :assigned_expert).order(updated_at: :desc)
    assigned = assigned.includes(:initiator, :assigned_expert).order(updated_at: :desc)

    render json: {
      waitingConversations: waiting.map { |c| conversation_payload(c) },
      assignedConversations: assigned.map { |c| conversation_payload(c) }
    }
  end

  # POST /expert/conversations/:conversation_id/claim
  def claim
    conv = Conversation.find_by(id: params[:conversation_id])
    return render json: { error: 'Conversation not found' }, status: :not_found unless conv

    if conv.assigned_expert_id.present?
      return render json: { error: 'Conversation is already assigned to an expert' }, status: :unprocessable_entity
    end

    conv.update!(assigned_expert_id: current_user.id, status: 'active')
    ExpertAssignment.create!(conversation_id: conv.id, expert_id: current_user.id, status: 'active', assigned_at: Time.current)
    render json: { success: true }
  end

  # POST /expert/conversations/:conversation_id/unclaim
  def unclaim
    conv = Conversation.find_by(id: params[:conversation_id])
    return render json: { error: 'Conversation not found' }, status: :not_found unless conv

    unless conv.assigned_expert_id == current_user.id
      return render json: { error: 'You are not assigned to this conversation' }, status: :forbidden
    end

    conv.update!(assigned_expert_id: nil, status: 'waiting')

    assignment = ExpertAssignment.where(conversation_id: conv.id, expert_id: current_user.id, status: 'active').order(created_at: :desc).first
    assignment&.update!(status: 'resolved', resolved_at: Time.current)

    render json: { success: true }
  end

  # GET /expert/profile
  def profile
    profile = current_user.expert_profile || current_user.create_expert_profile!
    render json: {
      id: profile.id.to_s,
      userId: current_user.id.to_s,
      bio: profile.bio,
      knowledgeBaseLinks: profile.knowledge_base_links || []
    }
  end

  # PUT /expert/profile
  def update_profile
    profile = current_user.expert_profile || current_user.create_expert_profile!

    attrs = {}
    attrs[:bio] = params[:bio] if params.key?(:bio)
    links_param = params.key?(:knowledgeBaseLinks) ? params[:knowledgeBaseLinks] : params[:knowledge_base_links]
    if params.key?(:knowledgeBaseLinks) || params.key?(:knowledge_base_links)
      if links_param.nil?
        attrs[:knowledge_base_links] = []
      elsif links_param.is_a?(Array)
        
        attrs[:knowledge_base_links] = normalize_links(links_param)
      else
        return render json: { error: "knowledgeBaseLinks must be an array" }, status: :unprocessable_entity
      end
    end

    if attrs.empty?
      return render json: { error: "No fields to update" }, status: :bad_request
    end

    if profile.update(attrs)
      render json: {
        id: profile.id.to_s,
        userId: current_user.id.to_s,
        bio: profile.bio,
        knowledgeBaseLinks: profile.knowledge_base_links || []
      }, status: :ok
    else
      render json: { errors: profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /expert/assignments/history
  def assignments_history
    assignments = ExpertAssignment
                    .includes(:conversation)
                    .where(expert_id: current_user.id)
                    .order(assigned_at: :desc)

    render json: assignments.map { |a|
      {
        id: a.id.to_s,
        conversationId: a.conversation_id.to_s,
        title: a.conversation&.title,
        status: a.status,
        assignedAt: a.assigned_at&.iso8601,
        resolvedAt: a.resolved_at&.iso8601
      }
    }
  end

  private

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
      unreadCount: 0
    }
  end

  def parse_time(val)
    return nil if val.blank?
    Time.iso8601(val) rescue nil
  end

 
  def normalize_links(list)
    Array(list).filter_map do |raw|
      s = raw.to_s.strip
      next if s.blank?
      s = "https://#{s}" unless s =~ %r{\Ahttps?://}i
      begin
        uri = URI.parse(s)
        %w[http https].include?(uri.scheme) ? uri.to_s : nil
      rescue URI::InvalidURIError
        nil
      end
    end.uniq
  end
end
