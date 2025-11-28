# frozen_string_literal: true

module Api
  module V1
    # UC-08: Execution Reports
    class ExecutionsController < ApplicationController
      # GET /api/v1/executions
      def index
        reports = ExecutionReport.joins(:order)
                                 .where(orders: { client_id: current_client_id })
                                 .order(created_at: :desc)
                                 .limit(params[:limit] || 50)

        render json: {
          success: true,
          data: reports.map { |r| execution_json(r) },
          meta: { count: reports.count }
        }
      end

      # GET /api/v1/executions/:id
      def show
        report = ExecutionReport.joins(:order)
                                .where(orders: { client_id: current_client_id })
                                .find(params[:id])

        render json: {
          success: true,
          **execution_json(report)
        }
      end

      private

      def execution_json(report)
        {
          id: report.id,
          order_id: report.order_id,
          report_type: report.respond_to?(:report_type) ? report.report_type : 'execution',
          status: report.status,
          quantity: report.quantity,
          price: report.price&.to_f,
          cumulative_quantity: report.respond_to?(:cumulative_quantity) ? report.cumulative_quantity : report.quantity,
          leaves_quantity: report.respond_to?(:leaves_quantity) ? report.leaves_quantity : 0,
          text: report.respond_to?(:text) ? report.text : nil,
          created_at: report.created_at.iso8601
        }
      end
    end
  end
end
