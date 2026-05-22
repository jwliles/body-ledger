require "test_helper"

module Reports
  class SleepDashboardReportTest < ActiveSupport::TestCase
    test "uses tracker sleep minutes separately from time in bed" do
      user = create_user("sleepuser")
      device = create_device(user)
      event = HealthEvent.create!(
        user: user,
        device: device,
        metric_type: "sleep",
        date_key: Date.new(2026, 1, 2),
        recorded_at: Time.zone.parse("2026-01-02 07:00:00"),
        client_uuid: SecureRandom.uuid,
        confirmation_status: "confirmed"
      )
      SleepPayload.create!(
        health_event: event,
        sleep_start: Time.zone.parse("2026-01-01 22:00:00"),
        sleep_end: Time.zone.parse("2026-01-02 07:00:00"),
        sleep_minutes: 420
      )

      report = SleepDashboardReport.new(
        user: user,
        start_date: Date.new(2026, 1, 2),
        end_date: Date.new(2026, 1, 2)
      ).call
      row = report[:sections].find { |section| section[:id] == "sleep_efficiency" }[:rows].first

      assert_equal 420, row[:sleep_minutes][:value]
      assert_equal "entered", row[:sleep_minutes][:source]
      assert_equal 540, row[:time_in_bed_minutes][:value]
      assert_equal 120, row[:awake_minutes][:value]
      assert_equal 77.8, row[:sleep_efficiency_percent][:value]
    end

    test "links sleep-timed medication to next day sleep and wake bp" do
      user = create_user("sleepjoin")
      device = create_device(user)
      medication = Medication.create!(
        user: user,
        name: "White Fire OG",
        strength: "10mg unit",
        pill_size_mg: 10,
        dosage: 20,
        dose_unit: "mg",
        med_form: "unit",
        med_type: "Cannabis",
        is_prn: true,
        scheduled_times: []
      )

      create_bp(user, device, Date.new(2026, 1, 2), "2026-01-02 22:33:00", "sleep", 152, 100, 92)
      create_dose(user, device, medication, Date.new(2026, 1, 2), "2026-01-02 22:00:00", 20, "sleep")
      create_sleep(user, device, Date.new(2026, 1, 3), "2026-01-02 23:00:00", "2026-01-03 07:00:00", 420)
      create_bp(user, device, Date.new(2026, 1, 3), "2026-01-03 07:35:00", "wake", 140, 88, 73)
      create_steps(user, device, Date.new(2026, 1, 3), "2026-01-03 20:00:00", 1433)

      report = SleepDashboardReport.new(
        user: user,
        start_date: Date.new(2026, 1, 2),
        end_date: Date.new(2026, 1, 3)
      ).call

      by_med = report[:sections].find { |section| section[:id] == "by_medication" }[:rows].first
      by_type = report[:sections].find { |section| section[:id] == "by_medication_type" }[:rows].first

      assert_equal "White Fire OG", by_med[:label]
      assert_equal 420.0, by_med[:avg_sleep]
      assert_equal 2.0, by_med[:avg_qty]
      assert_equal 146.0, by_med[:avg_systolic]
      assert_equal 94.0, by_med[:avg_diastolic]
      assert_equal 1433.0, by_med[:avg_steps]
      assert_equal 1, by_med[:nights]
      assert_equal 2, by_med[:bp_reads]

      assert_equal "Cannabis", by_type[:label]
      assert_equal by_med[:avg_sleep], by_type[:avg_sleep]
      assert_equal by_med[:avg_qty], by_type[:avg_qty]
    end

    private

    def create_user(username)
      User.create!(
        username: username,
        email: "#{username}@example.com",
        password: "CorrectHorseBatteryStaple1!",
        time_zone: "America/Chicago"
      )
    end

    def create_device(user)
      Device.create!(
        user: user,
        name: "web",
        platform: "web",
        token_digest: SecureRandom.hex(32)
      )
    end

    def create_event(user, device, metric_type, date_key, recorded_at)
      HealthEvent.create!(
        user: user,
        device: device,
        metric_type: metric_type,
        date_key: date_key,
        recorded_at: Time.zone.parse(recorded_at),
        client_uuid: SecureRandom.uuid,
        confirmation_status: "confirmed"
      )
    end

    def create_bp(user, device, date_key, recorded_at, context, systolic, diastolic, pulse)
      event = create_event(user, device, "blood_pressure", date_key, recorded_at)
      BloodPressurePayload.create!(
        health_event: event,
        reading_context: context,
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse
      )
    end

    def create_dose(user, device, medication, date_key, recorded_at, dose_mg, context)
      event = create_event(user, device, "medication_dose", date_key, recorded_at)
      MedicationDosePayload.create!(
        health_event: event,
        medication: medication,
        dose_mg: dose_mg,
        dose_type: "scheduled",
        timing_context: context
      )
    end

    def create_sleep(user, device, date_key, sleep_start, sleep_end, sleep_minutes)
      event = create_event(user, device, "sleep", date_key, sleep_end)
      SleepPayload.create!(
        health_event: event,
        sleep_start: Time.zone.parse(sleep_start),
        sleep_end: Time.zone.parse(sleep_end),
        sleep_minutes: sleep_minutes
      )
    end

    def create_steps(user, device, date_key, recorded_at, steps)
      event = create_event(user, device, "activity", date_key, recorded_at)
      ActivityPayload.create!(
        health_event: event,
        activity_type: "steps",
        duration_minutes: 1,
        steps: steps
      )
    end
  end
end
