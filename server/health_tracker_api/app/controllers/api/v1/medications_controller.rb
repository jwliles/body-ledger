module Api
  module V1
    class MedicationsController < ApplicationController
      # GET /api/v1/medications
      def index
        render json: current_user.medications.as_json(
          only: medication_json_fields
        )
      end

      # POST /api/v1/medications
      def create
        medication = current_user.medications.build(medication_params)

        if medication.save
          render json: medication.as_json(
            only: medication_json_fields
          ), status: :created
        else
          render json: { errors: medication.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/medications/:id
      def update
        medication = current_user.medications.find(params[:id])

        if medication.update(medication_params)
          render json: medication.as_json(
            only: medication_json_fields
          )
        else
          render json: { errors: medication.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Medication not found" }, status: :not_found
      end

      # POST /api/v1/medications/:id/merge
      # Keeps :id and reassigns dose history from source_medication_id.
      def merge
        target = current_user.medications.find(params[:id])
        source = current_user.medications.find(params.require(:source_medication_id))

        if source.id == target.id
          return render json: { error: "Choose two different medications to merge" }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          MedicationDosePayload
            .joins(:health_event)
            .where(medication_id: source.id, health_events: { user_id: current_user.id })
            .update_all(medication_id: target.id)

          source.update_columns(is_active: false, updated_at: Time.current)
        end

        render json: target.reload.as_json(
          only: medication_json_fields
        )
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Medication not found" }, status: :not_found
      end

      private

      def medication_json_fields
        [
          :id, :name, :strength, :is_prn, :scheduled_times, :pill_size_mg,
          :date_started, :rx_date, :rx_qty, :rx_per_day, :dosage, :dose_unit,
          :med_form, :med_type, :is_active, :created_at
        ]
      end

      def medication_params
        params.require(:medication).permit(
          :name, :strength, :is_prn, :pill_size_mg, :date_started, :rx_date,
          :rx_qty, :rx_per_day, :dosage, :dose_unit, :med_form, :med_type, :is_active,
          scheduled_times: []
        )
      end
    end
  end
end
