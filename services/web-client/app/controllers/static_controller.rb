# frozen_string_literal: true

class StaticController < ApplicationController
  def index
    render 'static/index'
  end
end
