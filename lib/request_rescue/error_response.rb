module RequestRescue
  class ErrorResponse
    MESSAGES = {
      400 => "Invalid request parameters",
      403 => "Forbidden",
      404 => "Page not found",
      405 => "Method not allowed",
      422 => "Invalid parameters",
      500 => "Internal server error"
    }.freeze

    def initialize(status, legacy_page: false)
      @status = status
      @legacy_page = legacy_page
    end

    def call(env)
      message = MESSAGES.fetch(@status) { Rack::Utils::HTTP_STATUS_CODES.fetch(@status) }
      json = @status == 405 || json_request?(env)
      content_type = json ? "application/json" : "text/html"
      content = if json
        JSON.generate(errors: [message])
      else
        "<!doctype html><html><head><title>#{@status} #{message}</title></head>" \
          "<body><h1>#{@status}</h1><p>#{message}</p><a href=\"/\">Home</a></body></html>"
      end
      method = env["action_dispatch.original_request_method"] || env["REQUEST_METHOD"]
      status = @legacy_page && Rails.application.config.request_rescue.legacy_responses ? 200 : @status
      [status, { "content-type" => "#{content_type}; charset=utf-8", "vary" => "Accept" },
       method == "HEAD" ? [] : [content]]
    end

    private

    def json_request?(env)
      path = env["action_dispatch.original_path"] || env["PATH_INFO"]
      return true if path.to_s.end_with?(".json")

      accepted = ActionDispatch::Request.new(env).accepts
      preference = accepted.find { |type| type == Mime[:json] || type == Mime[:html] }
      preference ? preference == Mime[:json] : Rails.application.config.api_only
    rescue ActionDispatch::Http::MimeNegotiation::InvalidType
      Rails.application.config.api_only
    end
  end

  # Rails rewrites PATH_INFO to the numeric HTTP status before dispatch.
  class ExceptionsApp
    def self.call(env)
      path = env["PATH_INFO"].to_s
      status = path.match?(%r{\A/[45]\d\d\z}) ? path[1..].to_i : 500
      status = 500 unless Rack::Utils::HTTP_STATUS_CODES.key?(status)
      ErrorResponse.new(status).call(env)
    end
  end
end
