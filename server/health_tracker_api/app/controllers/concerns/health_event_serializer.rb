module HealthEventSerializer
  private

  def event_json(event)
    payload_assoc = :"#{event.metric_type}_payload"
    payload = event.public_send(payload_assoc)
    {
      id:                  event.id,
      metric_type:         event.metric_type,
      date_key:            event.date_key,
      recorded_at:         event.recorded_at,
      client_uuid:         event.client_uuid,
      confirmation_status: event.confirmation_status,
      is_superseded:       event.is_superseded,
      supersedes_id:       event.supersedes_id,
      notes:               event.notes,
      created_at:          event.created_at,
      payload:             payload&.as_json(except: :health_event_id)
    }
  end
end
