Rails.application.routes.draw do
  mount TEST_ENGINE => ENV.fetch("MOUNT_AT"), as: :request_rescue
  post "echo", to: "probe#ok"
  get "ok", to: "probe#ok"
  get "format", to: "probe#format_error"
  get "template", to: "probe#template_error"
  get "listing", to: "probe#listing"
  get "api/format", to: "probe#format_error", defaults: { format: "json" }
  get "api/fault", to: "probe#fault", defaults: { format: "json" }
  get "script", to: "probe#cross_origin"
  get "javascript", to: "probe#javascript"
  get "fault", to: "probe#fault"
  get "required", to: "probe#required"
  get "params", to: "probe#parameters_check"
end
