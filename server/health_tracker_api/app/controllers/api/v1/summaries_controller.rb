module Api
  module V1
    class SummariesController < ApplicationController
      PROJECTOR_MAP = {
        "blood_pressure"       => Projections::BloodPressureProjector,
        "blood_pressure_wake"  => Projections::BloodPressureProjector,
        "blood_pressure_sleep" => Projections::BloodPressureProjector,
        "weight"               => Projections::WeightProjector,
        "sleep"                => Projections::SleepProjector,
        "activity"             => Projections::ActivityProjector,
        "nutrition"            => Projections::NutritionProjector,
        "symptom"              => Projections::SymptomProjector,
        "medication_dose"      => Projections::MedicationDoseProjector
      }.freeze

      # GET /api/v1/summaries
      # Filters: date (default: today), metric_type
      # Triggers projectors for the requested date before returning.
      def index
        date        = params[:date] ? Date.parse(params[:date]) : Date.current
        metric_type = params[:metric_type]

        run_projectors(date, metric_type)

        summaries = current_user.daily_summaries.where(summary_date: date)
        summaries = summaries.where(metric_type: metric_type) if metric_type

        render json: summaries.as_json(only: [ :id, :summary_date, :metric_type, :summary_data, :status ])
      end

      private

      def run_projectors(date, metric_type_filter)
        types     = metric_type_filter ? [ metric_type_filter ] : DailySummary::METRIC_TYPES
        projectors = types.filter_map { |mt| PROJECTOR_MAP[mt] }.uniq

        projectors.each do |projector_class|
          projector_class.new(user: current_user, date: date).project!
        end
      end
    end
  end
end
