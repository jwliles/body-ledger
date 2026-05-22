module Api
  module V1
    class ReportsController < ApplicationController
      REPORTS = {
        "weekly_summary" => ::Reports::WeeklySummaryReport,
        "daily_metrics_dashboard" => ::Reports::DailyMetricsDashboardReport,
        "sleep_dashboard" => ::Reports::SleepDashboardReport,
        "meds_dashboard" => ::Reports::MedsDashboardReport,
        "bp_readings" => ::Reports::BpReadingsReport,
        "trends_dashboard" => ::Reports::TrendsDashboardReport,
        "correlations_dashboard" => ::Reports::CorrelationsDashboardReport,
        "dietitian_report" => ::Reports::DietitianReport
      }.freeze

      def index
        render json: {
          reports: REPORTS.keys,
          legacy_fields: ::Reports::LegacyMetricMap.as_json
        }
      end

      def show
        report_class = REPORTS[params[:id]]
        return render json: { error: "Report not found" }, status: :not_found unless report_class

        report = report_class.new(
          user: current_user,
          start_date: params[:start_date],
          end_date: params[:end_date]
        ).call

        render json: report
      end
    end
  end
end
