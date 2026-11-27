class ApplicationController < (ENV["HOST_API"] == "yes" ? ActionController::API : ActionController::Base)
  include TEST_CONCERN
end
