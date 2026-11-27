RequestRescue::Engine.routes.draw do
  get "not_found", to: RequestRescue::ErrorResponse.new(404, legacy_page: true), as: :not_found
  get "invalid_params", to: RequestRescue::ErrorResponse.new(422, legacy_page: true), as: :invalid_params
  match "/404", to: RequestRescue::ErrorResponse.new(404, legacy_page: true), via: :all
  match "/500", to: RequestRescue::ErrorResponse.new(500, legacy_page: true), via: :all
end
