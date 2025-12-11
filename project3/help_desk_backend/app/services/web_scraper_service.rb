# frozen_string_literal: true

require "nokogiri"
require "net/http"
require "uri"
require "set"

class WebScraperService
  # Scrapes content from a URL and returns a cleaned text representation
  # Also follows and scrapes relevant links found on the page
  #
  # @param url [String] The URL to scrape
  # @param max_length [Integer] Maximum length of scraped content (default: 5000 characters)
  # @param follow_links [Boolean] Whether to follow and scrape relevant links (default: true)
  # @param max_depth [Integer] Maximum depth for following links (default: 2)
  # @param visited [Set] Set of visited URLs to avoid cycles
  # @return [Hash<String, String>] Hash mapping URLs to their scraped content
  def self.scrape_url(url, max_length: 5000, follow_links: true, max_depth: 2, visited: nil)
    return {} if url.blank?

    visited ||= Set.new
    base_uri = begin
      URI.parse(url)
    rescue URI::InvalidURIError => e
      Rails.logger.error("Invalid URL #{url}: #{e.message}")
      return {}
    end

    # Avoid cycles and respect depth limit
    return {} if visited.include?(url) || max_depth < 0

    visited.add(url)
    result = {}

    begin
      http = Net::HTTP.new(base_uri.host, base_uri.port)
      http.use_ssl = (base_uri.scheme == "https")
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(base_uri.request_uri)
      request["User-Agent"] = "Mozilla/5.0 (compatible; HelpDeskBot/1.0)"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("Failed to scrape #{url}: HTTP #{response.code}")
        return result
      end

      doc = Nokogiri::HTML(response.body)

      # Remove script and style elements
      doc.css("script, style, nav, header, footer, aside").remove

      text = doc.text
      text = text.gsub(/\s+/, " ").strip

      if text.length > max_length
        text = text[0, max_length] + "..."
      end

      result[url] = text

      if follow_links && max_depth > 0
        relevant_links = extract_relevant_links(doc, base_uri)
        relevant_links.each do |link_url|
          next if visited.include?(link_url)

          # Recursively scrape linked pages
          linked_content = scrape_url(
            link_url,
            max_length: max_length,
            follow_links: follow_links,
            max_depth: max_depth - 1,
            visited: visited
          )
          result.merge!(linked_content)
        end
      end

      result
    rescue Net::TimeoutError => e
      Rails.logger.warn("Timeout scraping #{url}: #{e.message}")
      result
    rescue StandardError => e
      Rails.logger.error("Error scraping #{url}: #{e.message}")
      result
    end
  end

  # @param urls [Array<String>] Array of URLs to scrape
  # @param max_length [Integer] Maximum length per URL (default: 5000 characters)
  # @param follow_links [Boolean] Whether to follow and scrape relevant links (default: true)
  # @param max_depth [Integer] Maximum depth for following links (default: 2)
  # @return [Hash<String, String>] Hash mapping URLs to scraped content
  def self.scrape_urls(urls, max_length: 5000, follow_links: true, max_depth: 2)
    return {} if urls.blank?

    visited = Set.new
    urls.each_with_object({}) do |url, result|
      content_hash = scrape_url(
        url,
        max_length: max_length,
        follow_links: follow_links,
        max_depth: max_depth,
        visited: visited
      )
      result.merge!(content_hash)
    end
  end

  private

  # Extracts relevant links from a parsed HTML document
  # Links are considered relevant if they:
  # - Are on the same domain
  # - Are relative links
  # - Are not mailto:, tel:, javascript:, or anchor links
  #
  # @param doc [Nokogiri::HTML::Document] The parsed HTML document
  # @param base_uri [URI] The base URI for resolving relative links
  # @param max_links [Integer] Maximum number of links to extract (default: 5)
  # @return [Array<String>] Array of relevant URLs
  def self.extract_relevant_links(doc, base_uri, max_links: 5)
    links = []
    base_domain = "#{base_uri.scheme}://#{base_uri.host}"

    doc.css("a[href]").each do |anchor|
      href = anchor["href"].to_s.strip
      next if href.blank?

      begin
        # Skip non-HTTP links
        next if href.match?(/^(mailto|tel|javascript|#):/i)

        absolute_url = URI.join(base_uri.to_s, href).to_s
        link_uri = URI.parse(absolute_url)
        link_domain = "#{link_uri.scheme}://#{link_uri.host}"

        # Only include links from the same domain
        if link_domain == base_domain || link_uri.host == base_uri.host
          links << absolute_url
          break if links.length >= max_links
        end
      rescue URI::InvalidURIError
        next
      end
    end

    links.uniq
  end
end

