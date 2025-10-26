# Subscribe to controller actions and instrument basic HTTP metrics
# Wrap in after_initialize to ensure Zeitwerk namespaces are set up before referencing Infrastructure
Rails.application.config.after_initialize do
  ::Infrastructure::Observability::Metrics.define_histogram('http_request_duration_seconds')

  ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, _id, payload|
    duration = finish - start
    status = payload[:status].to_i
    controller = payload[:controller]
    action = payload[:action]
    ::Infrastructure::Observability::Metrics.observe('http_request_duration_seconds', duration, { controller: controller, action: action })
    ::Infrastructure::Observability::Metrics.inc_counter('http_requests_total', { controller: controller, action: action, code: status })
    if status >= 500
      ::Infrastructure::Observability::Metrics.inc_counter('http_errors_total', { code: status })
    elsif status >= 400
      ::Infrastructure::Observability::Metrics.inc_counter('http_client_errors_total', { code: status })
    end
  end

  # Track ActionCable connections gauge
  ::Infrastructure::Observability::Metrics.set_gauge('cable_connections', 0)
end
