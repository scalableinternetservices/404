# frozen_string_literal: true

require "net/http"
require "json"
require "time"

class GithubService
  API_BASE = "https://api.github.com"

  # Returns the latest update time for a GitHub Pages URL (e.g., https://user.github.io[/project]).
  # @param github_pages_url [String] the public GitHub Pages link
  # @return [Hash] response hash with :status (Integer) and :last_updated_at (Time or nil)
  def last_updated_at(github_pages_url)
    repo_full_name = extract_repo_from_github_pages(github_pages_url)
    return { status: 400, last_updated_at: nil } if repo_full_name.blank?

    response = fetch_repository(repo_full_name)
    return { status: response[:status], last_updated_at: nil } unless response[:status] == 200

    timestamp = response[:body]["pushed_at"].presence || response[:body]["updated_at"]
    parsed_time = parse_time_safely(timestamp)

    { status: response[:status], last_updated_at: parsed_time }
  end

  private

  def fetch_repository(repo_full_name)
    return { status: 400, body: {} } if repo_full_name.blank?

    uri = URI("#{API_BASE}/repos/#{repo_full_name}")
    perform_request(uri)
  end

  # Converts a GitHub Pages URL into "owner/repo" form.
  # - user.github.io          -> user/user.github.io
  # - user.github.io/project  -> user/project
  def extract_repo_from_github_pages(url)
    return if url.blank?

    uri = URI.parse(url)
    host = uri.host.to_s
    return nil unless host.end_with?("github.io")

    owner = host.sub(".github.io", "")
    path_parts = uri.path.split("/").reject(&:blank?)

    repo = if path_parts.empty?
      "#{owner}.github.io"
    else
      path_parts.first
    end

    "#{owner}/#{repo}"
  rescue URI::InvalidURIError
    nil
  end

  def parse_time_safely(value)
    return nil if value.blank?

    Time.parse(value)
  rescue ArgumentError
    nil
  end

  def perform_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github+json"
    request["User-Agent"] = "HelpDeskBackend/1.0"

    response = http.request(request)
    body = response.body.present? ? JSON.parse(response.body) : {}

    { status: response.code.to_i, body: body }
  rescue JSON::ParserError => e
    Rails.logger.error("GitHub response parse error: #{e.message}")
    { status: 500, body: {} }
  rescue StandardError => e
    Rails.logger.error("GitHub request failed: #{e.message}")
    { status: 500, body: {} }
  end
end
