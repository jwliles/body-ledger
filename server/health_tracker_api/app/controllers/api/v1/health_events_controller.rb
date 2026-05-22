module Api
  module V1
    class HealthEventsController < ApplicationController
      include HealthEventSerializer

      PAYLOAD_CLASS = {
        "blood_pressure"  => BloodPressurePayload,
        "weight"          => WeightPayload,
        "sleep"           => SleepPayload,
        "activity"        => ActivityPayload,
        "nutrition"       => NutritionPayload,
        "symptom"         => SymptomPayload,
        "medication_dose" => MedicationDosePayload
      }.freeze

      # GET /api/v1/health_events
      # Filters: metric_type, start_date, end_date (on date_key), status
      def index
        events = current_user.health_events.current
        events = events.where(metric_type: params[:metric_type])               if params[:metric_type]
        events = events.where("date_key >= ?", params[:start_date])            if params[:start_date]
        events = events.where("date_key <= ?", params[:end_date])              if params[:end_date]
        events = events.where(confirmation_status: params[:status])            if params[:status]
        render json: events.map { |e| event_json(e) }
      end

      # GET /api/v1/health_events/:id
      def show
        event = current_user.health_events.find(params[:id])
        render json: event_json(event)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      # POST /api/v1/health_events
      # Accepts nested payload under the metric-specific key, e.g.:
      #   { "health_event": { "metric_type": "blood_pressure", ...,
      #                       "blood_pressure_payload": { ... } } }
      # Idempotent: same client_uuid for the same user returns 200 with existing event.
      def create
        event_attrs  = base_event_params
        metric_type  = event_attrs[:metric_type]
        payload_attrs = payload_params(metric_type)

        # Idempotency guard
        existing = current_user.health_events.find_by(client_uuid: event_attrs[:client_uuid])
        return render json: event_json(existing), status: :ok if existing

        result = nil
        errors = []

        ActiveRecord::Base.transaction do
          event = current_user.health_events.build(
            event_attrs.merge(device: current_device, confirmation_status: "confirmed")
          )

          unless event.save
            errors = event.errors.full_messages
            raise ActiveRecord::Rollback
          end

          if payload_attrs.present? && (payload_class = PAYLOAD_CLASS[metric_type])
            payload = payload_class.new(payload_attrs.merge(health_event: event))
            unless payload.save
              errors = payload.errors.full_messages
              raise ActiveRecord::Rollback
            end
          end

          result = event
        end

        if result
          render json: event_json(result), status: :created
        else
          render json: { errors: errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/health_events/:id/amend
      # Creates an amendment event and atomically supersedes the original.
      # Body same structure as create (minus metric_type, which is inherited).
      def amend
        event       = current_user.health_events.find(params[:id])
        metric_type = event.metric_type
        amend_attrs  = base_amendment_params
        payload_attrs = payload_params(metric_type)

        amendment = nil
        errors    = []

        ActiveRecord::Base.transaction do
          begin
            amendment = event.amend!(amend_attrs)
          rescue ActiveRecord::RecordInvalid => e
            errors = e.record.errors.full_messages
            raise ActiveRecord::Rollback
          end

          if payload_attrs.present? && (payload_class = PAYLOAD_CLASS[metric_type])
            payload = payload_class.new(payload_attrs.merge(health_event: amendment))
            unless payload.save
              errors = payload.errors.full_messages
              amendment = nil
              raise ActiveRecord::Rollback
            end
          end
        end

        if amendment
          render json: event_json(amendment.reload), status: :created
        else
          render json: { errors: errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      private

      def base_event_params
        params.require(:health_event)
              .permit(:metric_type, :recorded_at, :client_uuid, :confirmation_status, :notes)
              .to_h.symbolize_keys
      end

      def base_amendment_params
        params.require(:health_event)
              .permit(:client_uuid, :recorded_at, :confirmation_status, :notes)
              .to_h.symbolize_keys
      end

      def payload_params(metric_type)
        return {} unless params[:health_event]&.key?("#{metric_type}_payload")

        case metric_type
        when "blood_pressure"
          params.require(:health_event).require(:blood_pressure_payload)
                .permit(:systolic, :diastolic, :pulse, :reading_context).to_h
        when "weight"
          params.require(:health_event).require(:weight_payload)
                .permit(:value_kg, :original_unit, :original_value).to_h
        when "sleep"
          params.require(:health_event).require(:sleep_payload)
                .permit(:sleep_start, :sleep_end, :sleep_minutes).to_h
        when "activity"
          params.require(:health_event).require(:activity_payload)
                .permit(:activity_type, :duration_minutes, :distance_km,
                        :steps, :heart_rate_avg, :calories_burned).to_h
        when "nutrition"
          p = params.require(:health_event).require(:nutrition_payload)
                    .permit(:meal_type, :calories_kcal, :protein_g, :fat_g,
                            :carbohydrate_g, :fiber_g, :sugar_g, :sodium_mg).to_h
          raw_micro = params.dig(:health_event, :nutrition_payload, :micronutrients)
          p[:micronutrients] = raw_micro.to_unsafe_h if raw_micro.respond_to?(:to_unsafe_h)
          p
        when "symptom"
          params.require(:health_event).require(:symptom_payload)
                .permit(:symptom_code, :severity, :body_location).to_h
        when "medication_dose"
          params.require(:health_event).require(:medication_dose_payload)
                .permit(:medication_id, :dose_mg, :dose_type).to_h
        else
          {}
        end
      end
    end
  end
end
