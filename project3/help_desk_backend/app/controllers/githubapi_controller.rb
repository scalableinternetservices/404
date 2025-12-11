# frozen_string_literal: true

class GithubapiController < ApplicationController
  # GET /githubapi/last_updated?url=https://user.github.io[/project]
  def last_updated
    url = params[:url].to_s
    result = GithubService.new.last_updated_at(url)

    if result[:status] == 200 && result[:last_updated_at].present?
      render json: { last_updated_at: result[:last_updated_at].iso8601 }, status: :ok
    else
      render json: { error: "Unable to fetch last updated time" }, status: result[:status]
    end
  end
end
