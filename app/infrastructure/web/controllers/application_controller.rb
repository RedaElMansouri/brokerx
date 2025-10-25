class ApplicationController < ActionController::Base
  # Contrôleur de base
  # - Fournit les protections CSRF et le rendu HTML au besoin
  # - Les contrôleurs JSON peuvent ignorer la vérification CSRF si nécessaire

  # --- Gestion d'erreurs JSON uniforme ---
  rescue_from ActiveRecord::RecordNotFound do |e|
    render_api_error(code: 'not_found', message: e.message, status: :not_found)
  end

  rescue_from ActionController::ParameterMissing do |e|
    render_api_error(code: 'bad_request', message: e.message, status: :bad_request)
  end

  rescue_from JWT::DecodeError do |e|
    render_api_error(code: 'unauthorized', message: "Invalid token: #{e.message}", status: :unauthorized)
  end

  # Attraper les exceptions non gérées (requêtes JSON uniquement)
  rescue_from StandardError do |e|
    raise e unless request.format.json?

    Rails.logger.error("Unhandled error: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    render_api_error(code: 'internal_error', message: 'An unexpected error occurred', status: :internal_server_error)
  end

  private

  def render_api_error(code:, message:, status: :bad_request)
    if request.format.json?
      render json: { success: false, code: code, message: message }, status: status
    else
      render plain: message, status: status
    end
  end

  # Gestion des routes introuvables (utilisée par `match '*path'`)
  def route_not_found
    respond_to do |format|
      format.json { render json: { success: false, code: 'not_found', message: 'Not Found' }, status: :not_found }
      format.html { render plain: '404 Not Found', status: :not_found }
      format.any  { head :not_found }
    end
  end
end
