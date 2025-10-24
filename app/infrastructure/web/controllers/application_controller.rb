class ApplicationController < ActionController::Base
  # If you want API-only behavior but still need CSRF protection methods,
  # you can include modules as needed. By inheriting from ActionController::Base
  # we get `verify_authenticity_token` and view rendering for normal controllers.

  # For JSON API controllers you can still use `protect_from_forgery` or skip it
  # in specific controllers (as done in `StaticController`).

  # Generic handler for unmatched routes used by `match '*path'` in routes.rb
  def route_not_found
    respond_to do |format|
      format.json { render json: { status: 404, error: 'Not Found' }, status: :not_found }
      format.html { render plain: '404 Not Found', status: :not_found }
      format.any  { head :not_found }
    end
  end
end
