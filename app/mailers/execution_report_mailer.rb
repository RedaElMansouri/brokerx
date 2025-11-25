class ExecutionReportMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'no-reply@brokerx.local')

  # params expected: :email, :order_id, :status, :quantity, :price
  def execution_report
    @order_id = params[:order_id]
    @status = params[:status]
    @quantity = params[:quantity]
    @price = params[:price]
    mail(to: params[:email], subject: "Confirmation exécution ordre ##{@order_id}")
  end
end
