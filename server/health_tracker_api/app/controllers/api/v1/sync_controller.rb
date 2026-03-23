module Api
  module V1
    class SyncController < ApplicationController
      include HealthEventSerializer

      # POST /api/v1/sync
      # Body: { last_synced_at: "<iso8601>" }
      # Returns events created by other devices since last_synced_at,
      # and updates the download cursor for this device.
      def create
        last_synced_at = params[:last_synced_at] ? Time.zone.parse(params[:last_synced_at]) : Time.at(0)

        events = current_user.health_events
                              .where("health_events.created_at > ?", last_synced_at)
                              .where.not(device_id: current_device.id)
                              .includes(:blood_pressure_payload, :weight_payload, :sleep_payload,
                                        :activity_payload, :nutrition_payload, :symptom_payload,
                                        :medication_dose_payload)

        synced_at = Time.current

        SyncCursor.upsert(
          {
            device_id:      current_device.id,
            last_synced_at: synced_at,
            last_event_id:  events.maximum(:id) || 0,
            direction:      "download",
            created_at:     synced_at,
            updated_at:     synced_at
          },
          unique_by: [ :device_id, :direction ],
          update_only: [ :last_synced_at, :last_event_id, :updated_at ]
        )

        render json: {
          synced_at: synced_at,
          events:    events.map { |e| event_json(e) }
        }
      end
    end
  end
end
