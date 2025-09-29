class StaticController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    # Page d'accueil statique - pas de logique métier
  end
end
