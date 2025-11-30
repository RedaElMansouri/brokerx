# frozen_string_literal: true

class SwaggerController < ApplicationController
  skip_before_action :authenticate_request!, raise: false

  def index
    send_file Rails.root.join('public', 'swagger.html'), 
              type: 'text/html', 
              disposition: 'inline'
  end

  def openapi
    send_file Rails.root.join('public', 'openapi.yaml'), 
              type: 'application/x-yaml', 
              disposition: 'inline'
  end
end
