module RequestRescue
  class Engine < Rails::Engine
    engine_name "request_rescue"
    config.request_rescue = ActiveSupport::OrderedOptions.new
    config.request_rescue.legacy_responses = false

    initializer "request_rescue.middleware" do |app|
      app.middleware.use RequestRescue::Middleware
    end
  end
end
