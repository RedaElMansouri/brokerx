class MetricsController < ::ApplicationController
  skip_before_action :verify_authenticity_token

  # No auth here for prototype; restrict at ingress in real deployment
  def index
    text = ::Infrastructure::Observability::Metrics.to_prometheus_text
    render plain: text, content_type: 'text/plain; version=0.0.4'
  end
end
