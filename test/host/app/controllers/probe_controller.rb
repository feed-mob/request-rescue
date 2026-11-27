class ProbeController < ApplicationController
  unless ENV["HOST_API"] == "yes"
    protect_from_forgery with: :exception, only: :javascript

    def javascript
      render js: "void(0)"
    end
  end

  def ok
    render json: { value: params[:value] || "ok" }
  end

  def format_error
    respond_to { |format| format.html { head :ok } }
  end

  def template_error
    render template: "probe/absent"
  end

  def cross_origin
    response.set_header("Vary", "Origin")
    raise ActionController::InvalidCrossOriginRequest
  end

  def fault
    raise "private fixture exception"
  end

  def required
    params.require(:item)
  end

  if defined?(Apipie)
    api :GET, "/params", "Check a required numeric parameter"
    param :number, :number, required: true
    def parameters_check
      head :ok
    end
  end
end
