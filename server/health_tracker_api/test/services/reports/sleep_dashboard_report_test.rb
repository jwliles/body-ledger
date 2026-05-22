require "test_helper"

module Reports
  class SleepDashboardReportTest < ActiveSupport::TestCase
    test "uses tracker sleep minutes separately from time in bed" do
      user = User.create!(
        username: "sleepuser",
        email: "sleep@example.com",
        password: "CorrectHorseBatteryStaple1!",
        time_zone: "America/Chicago"
      )
      device = Device.create!(
        user: user,
        name: "web",
        platform: "web",
        token_digest: SecureRandom.hex(32)
      )
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
      row = report[:sections].first[:rows].first

      assert_equal 420, row[:sleep_minutes][:value]
      assert_equal "entered", row[:sleep_minutes][:source]
      assert_equal 540, row[:time_in_bed_minutes][:value]
      assert_equal 120, row[:awake_minutes][:value]
      assert_equal 77.8, row[:sleep_efficiency_percent][:value]
    end
  end
end
