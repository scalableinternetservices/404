class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :detect_locust_request

  private

  def detect_locust_request
    ua = request.user_agent.to_s

    if ua.include?("python-requests")
      Current.might_be_locust_request = true
    else
      Current.might_be_locust_request = false
    end
  end
end
