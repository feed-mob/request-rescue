module RequestRescue
  class Engine < Rails::Engine
    engine_name "request_rescue"
    config.request_rescue = ActiveSupport::OrderedOptions.new
    config.request_rescue.legacy_responses = false

    # feedmob-rescue checked requests beside RemoteIp, before the Rails logger,
    # exception pages and any middleware the application adds.
    initializer "request_rescue.middleware" do |app|
      app.middleware.insert_after ActionDispatch::RemoteIp, RequestRescue::Middleware
    end
  end
end
