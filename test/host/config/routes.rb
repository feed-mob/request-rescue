Rails.application.routes.draw do
  mount TEST_ENGINE => ENV.fetch("MOUNT_AT"), as: :request_rescue
  get "ok", to: "probe#ok"
  get "format", to: "probe#format_error"
  get "template", to: "probe#template_error"
  get "script", to: "probe#cross_origin"
  get "fault", to: "probe#fault"
  get "params", to: "probe#parameters_check"
end
