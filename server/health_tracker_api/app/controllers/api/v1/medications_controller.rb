module Api
  module V1
    class MedicationsController < ApplicationController
      # GET /api/v1/medications
      def index
        render json: current_user.medications.as_json(
          only: [ :id, :name, :strength, :is_prn, :scheduled_times, :pill_size_mg, :is_active, :created_at ]
        )
      end

      # POST /api/v1/medications
      def create
        medication = current_user.medications.build(medication_params)

        if medication.save
          render json: medication.as_json(
            only: [ :id, :name, :strength, :is_prn, :scheduled_times, :pill_size_mg, :is_active, :created_at ]
          ), status: :created
        else
          render json: { errors: medication.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def medication_params
        params.require(:medication).permit(:name, :strength, :is_prn, :pill_size_mg, :is_active, scheduled_times: [])
      end
    end
  end
end
