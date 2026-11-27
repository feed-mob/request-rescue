module RequestRescue
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      return ErrorResponse.new(405).call(env) unless ActionDispatch::Request::HTTP_METHODS.include?(env["REQUEST_METHOD"])
      return ErrorResponse.new(400).call(env) unless valid_query?(env)

      @app.call(env)
    end

    private

    def valid_query?(env)
      # Rack caches parsing here. Rails can still apply per-action encodings after routing.
      Rack::Request.new(env).GET
      true
    rescue Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError, RangeError
      # Old Rack releases use RangeError when the parser's nesting limit is reached.
      false
    end
  end
end
