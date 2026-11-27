module RequestRescue
  module Controller
    extend ActiveSupport::Concern

    included do
      rescue_from ActionController::UnknownFormat, ActionView::MissingTemplate, with: :request_rescue_not_found
      rescue_from ActionController::InvalidCrossOriginRequest, with: :request_rescue_cross_origin
      # Rails resolves string class names when handling an exception, so Apipie is optional.
      rescue_from "Apipie::ParamMissing", "Apipie::ParamInvalid", with: :request_rescue_invalid_params
    end

    private

    def request_rescue_not_found(error)
      raise error if Rails.env.development?
      return redirect_to(request_rescue.not_found_path) if Rails.application.config.request_rescue.legacy_responses

      request_rescue_render(404)
    end

    def request_rescue_invalid_params(error)
      raise error if Rails.env.development?
      return redirect_to(request_rescue.invalid_params_path) if Rails.application.config.request_rescue.legacy_responses

      request_rescue_render(422)
    end

    def request_rescue_cross_origin(error)
      raise error if Rails.env.development? || Rails.env.test?
      return head(:ok) if Rails.application.config.request_rescue.legacy_responses

      request_rescue_render(403)
    end

    def request_rescue_render(code)
      status, headers, body = ErrorResponse.new(code).call(request.env)
      self.status = status
      self.content_type = headers.fetch("content-type")
      vary = response.get_header("Vary").to_s.split(/\s*,\s*/)
      unless vary.include?("*") || vary.any? { |field| field.casecmp?("Accept") }
        response.set_header("Vary", (vary + ["Accept"]).join(", "))
      end
      self.response_body = body
    end
  end
end
