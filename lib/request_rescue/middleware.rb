module RequestRescue
  class Middleware
    def initialize(app)
      @app = app
    end

    # Check the query before the method, in the same order as feedmob-rescue.
    def call(env)
      return ErrorResponse.new(400).call(env) unless valid_query?(env)
      return ErrorResponse.new(405).call(env) unless ActionDispatch::Request::HTTP_METHODS.include?(env["REQUEST_METHOD"])

      @app.call(env)
    end

    private

    def valid_query?(env)
      query = Rack::Request.new(env).GET
      # Legacy mode also checked encoding on routes that never read controller parameters.
      if Rails.application.config.request_rescue.legacy_responses
        ActionDispatch::Request::Utils.check_param_encoding(query)
      end
      true
    rescue Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError, RangeError
      # Old Rack releases use RangeError when the parser's nesting limit is reached.
      false
    end
  end
end
