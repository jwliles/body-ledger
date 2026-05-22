require "digest"
require "yaml"

module Importers
  class JournalImporter
    JOURNAL_DATE_PATTERN = %r{/(\d{4})_(\d{2})_(\d{2})\.md\z}
    MED_LINE_PATTERN = /
      (?<recorded_at>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})
      \s+\|\s+med::\s+\[\[(?<med>[^\]]+)\]\]
      \s+\|\s+qty::\s+(?<qty>[0-9.]+)
    /x

    attr_reader :user, :device, :path, :dry_run, :stats, :errors

    def initialize(user:, device:, path:, dry_run: false)
      @user = user
      @device = device
      @path = Pathname(path)
      @dry_run = dry_run
      @stats = Hash.new(0)
      @errors = []
    end

    def import!
      files.each { |file| import_file(file) }

      {
        dry_run: dry_run,
        files: stats[:files],
        created: stats.select { |key, _| key.to_s.start_with?("created_") },
        skipped: stats.select { |key, _| key.to_s.start_with?("skipped_") },
        errors: errors
      }
    end

    private

    def files
      Pathname.glob(path.join("**/20*.md")).sort
    end

    def import_file(file)
      stats[:files] += 1
      date_key = date_from_path(file)
      return skip(:skipped_bad_filename, file, "could not infer date") unless date_key

      content = file.read
      frontmatter = parse_frontmatter(content, file)
      return unless frontmatter

      import_blood_pressure(frontmatter, file, date_key, "wake")
      import_blood_pressure(frontmatter, file, date_key, "sleep")
      import_sleep(frontmatter, file, date_key)
      import_weight(frontmatter, file, date_key)
      import_steps(frontmatter, file, date_key)
      sleep_med_names = import_medication_lines(content, file, date_key)
      import_frontmatter_sleep_med(frontmatter, file, date_key, sleep_med_names)
    end

    def parse_frontmatter(content, file)
      match = content.match(/\A---\s*\n(.*?)\n---/m)
      return skip(:skipped_no_frontmatter, file, "missing frontmatter") unless match

      YAML.safe_load(match[1], permitted_classes: [ Date, Time ], aliases: true) || {}
    rescue Psych::Exception => e
      skip(:skipped_bad_yaml, file, e.message)
      nil
    end

    def import_blood_pressure(data, file, date_key, context)
      prefix = context == "wake" ? %w[wake am] : %w[sleep pm]
      sys = number(value(data, *prefix.map { |item| "#{item}_sys" }))
      dia = number(value(data, *prefix.map { |item| "#{item}_dia" }))
      return stats[:"skipped_#{context}_bp_missing"] += 1 unless sys && dia

      recorded_at = timestamp(value(data, *prefix.map { |item| "#{item}_bp_time" }), date_key)
      return skip(:"skipped_#{context}_bp_bad_time", file, value(data, *prefix.map { |item| "#{item}_bp_time" })) unless recorded_at

      create_event(file, "#{context}_bp", "blood_pressure", date_key, recorded_at) do |event|
        BloodPressurePayload.create!(
          health_event: event,
          reading_context: context,
          systolic: sys.to_i,
          diastolic: dia.to_i,
          pulse: number(value(data, *prefix.map { |item| "#{item}_hr" }, *prefix.map { |item| "#{item}_pulse" }))&.to_i
        )
      end
    end

    def import_sleep(data, file, date_key)
      bedtime = timestamp(value(data, "bedtime", "sleep_start"), date_key)
      wake_time = timestamp(value(data, "wake_time", "sleep_end"), date_key)
      sleep_minutes = number(value(data, "sleep", "sleep_mins", "sleep_minutes"))&.to_i

      return stats[:skipped_sleep_missing] += 1 unless sleep_minutes || (bedtime && wake_time)

      sleep_end = bedtime && wake_time ? adjusted_wake_time(bedtime, wake_time) : nil
      recorded_at = sleep_end || timestamp(value(data, "wake_time"), date_key) || date_key.to_time.change(hour: 12)
      create_event(file, "sleep", "sleep", date_key, recorded_at) do |event|
        SleepPayload.create!(
          health_event: event,
          sleep_start: bedtime,
          sleep_end: sleep_end,
          sleep_minutes: sleep_minutes
        )
      end
    end

    def import_weight(data, file, date_key)
      weight = number(data["weight"])
      return stats[:skipped_weight_missing] += 1 unless weight

      recorded_at = timestamp(data["wake_time"], date_key) || date_key.to_time.change(hour: 12)
      create_event(file, "weight", "weight", date_key, recorded_at) do |event|
        WeightPayload.create!(
          health_event: event,
          value_kg: (weight * 0.45359237).round(3),
          original_unit: "lb",
          original_value: weight
        )
      end
    end

    def import_steps(data, file, date_key)
      steps = number(data["steps"])&.to_i
      return stats[:skipped_steps_missing] += 1 unless steps

      recorded_at = date_key.to_time.change(hour: 23, min: 59)
      create_event(file, "steps", "activity", date_key, recorded_at) do |event|
        ActivityPayload.create!(
          health_event: event,
          activity_type: "steps",
          duration_minutes: 1,
          steps: steps
        )
      end
    end

    def import_medication_lines(content, file, date_key)
      context = nil
      sleep_med_names = []

      content.each_line.with_index do |line, index|
        context = "wake" if line.match?(/>\s*###\s*AM/i)
        context = "sleep" if line.match?(/>\s*###\s*PM/i)
        match = line.match(MED_LINE_PATTERN)
        next unless match

        import_medication_dose(
          file: file,
          date_key: date_key,
          key: "med_line_#{index}",
          name: match[:med],
          quantity: number(match[:qty]),
          recorded_at: Time.zone.parse(match[:recorded_at]),
          timing_context: context || "other"
        )
        sleep_med_names << med_name(match[:med]).downcase if context == "sleep"
      end

      sleep_med_names
    end

    def import_frontmatter_sleep_med(data, file, date_key, sleep_med_names)
      names = Array(data["med"]).map { |value| med_name(value) }.compact
      names.reject! { |name| none_value?(name) }
      names.reject! { |name| sleep_med_names.include?(name.downcase) }
      quantity = number(data["qty"])
      med_type = scalar(data["med_type"])
      return stats[:skipped_frontmatter_med_missing] += 1 if names.empty? || quantity.nil? || quantity <= 0

      recorded_at = timestamp(value(data, "sleep_meds", "pm_meds"), date_key) || timestamp(value(data, "bedtime", "sleep_start"), date_key)
      return skip(:skipped_frontmatter_med_bad_time, file, value(data, "sleep_meds", "pm_meds", "bedtime", "sleep_start")) unless recorded_at

      names.each_with_index do |name, index|
        import_medication_dose(
          file: file,
          date_key: date_key,
          key: "frontmatter_sleep_med_#{index}",
          name: name,
          quantity: quantity,
          recorded_at: recorded_at,
          timing_context: "sleep",
          med_type: med_type
        )
      end
    end

    def import_medication_dose(file:, date_key:, key:, name:, quantity:, recorded_at:, timing_context:, med_type: nil)
      return stats[:skipped_medication_qty_missing] += 1 unless quantity && quantity.positive?
      if dry_run
        stats[:created_medication_dose] += 1
        return
      end

      medication = medication_for(name, med_type)
      strength = medication.pill_size_mg.to_f
      dose_mg = strength.positive? ? quantity * strength : quantity

      create_event(file, key, "medication_dose", date_key, recorded_at) do |event|
        MedicationDosePayload.create!(
          health_event: event,
          medication: medication,
          dose_mg: dose_mg.round(3),
          dose_type: medication.is_prn? ? "prn" : "scheduled",
          timing_context: timing_context
        )
      end
    end

    def medication_for(raw_name, med_type = nil)
      name = med_name(raw_name)
      medication = user.medications.where("LOWER(name) = ?", name.downcase).first
      medication ||= user.medications.create!(
        name: name,
        strength: "1unit unit",
        pill_size_mg: 1,
        dosage: 1,
        dose_unit: "unit",
        med_form: "unit",
        med_type: none_value?(med_type) ? nil : med_type,
        is_prn: true,
        scheduled_times: [],
        is_active: true
      )

      if medication.med_type.blank? && med_type.present? && !none_value?(med_type)
        medication.update!(med_type: med_type)
      end

      medication
    end

    def create_event(file, key, metric_type, date_key, recorded_at)
      client_uuid = deterministic_uuid("#{file}:#{key}")
      existing = user.health_events.find_by(client_uuid: client_uuid)
      if existing
        stats[:"skipped_existing_#{metric_type}"] += 1
        return existing
      end

      if dry_run
        stats[:"created_#{metric_type}"] += 1
        return nil
      end

      HealthEvent.transaction do
        event = user.health_events.create!(
          device: device,
          metric_type: metric_type,
          date_key: date_key,
          recorded_at: recorded_at,
          client_uuid: client_uuid,
          confirmation_status: "confirmed",
          notes: "Imported from legacy journal #{file}"
        )
        yield event
        stats[:"created_#{metric_type}"] += 1
        event
      end
    rescue ActiveRecord::RecordInvalid => e
      skip(:"skipped_invalid_#{metric_type}", file, e.record.errors.full_messages.join(", "))
    end

    def date_from_path(file)
      match = file.to_s.match(JOURNAL_DATE_PATTERN)
      return nil unless match

      Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
    end

    def timestamp(value, date_key)
      value = scalar(value)
      return nil if value.blank?

      time = Time.zone.parse(value.to_s)
      return nil unless time && time.year.between?(date_key.year - 1, date_key.year + 1)

      time
    rescue ArgumentError, TypeError
      nil
    end

    def adjusted_wake_time(bedtime, wake_time)
      return wake_time if wake_time > bedtime

      wake_time + 1.day
    end

    def number(value)
      value = scalar(value)
      return nil if value.blank?

      number = Float(value)
      number.finite? ? number : nil
    rescue ArgumentError, TypeError
      nil
    end

    def scalar(value)
      value = value.first if value.is_a?(Array)
      value
    end

    def value(data, *keys)
      keys.each do |key|
        candidate = data[key]
        return candidate unless scalar(candidate).blank?
      end
      nil
    end

    def med_name(value)
      value = scalar(value).to_s.strip
      value = value.delete_prefix("[[").delete_suffix("]]")
      value.tr("_", " ")
    end

    def none_value?(value)
      value.blank? || value.to_s.strip.casecmp("none").zero?
    end

    def deterministic_uuid(value)
      hex = Digest::MD5.hexdigest(value)
      [
        hex[0, 8],
        hex[8, 4],
        hex[12, 4],
        hex[16, 4],
        hex[20, 12]
      ].join("-")
    end

    def skip(key, file, message)
      stats[key] += 1
      errors << { file: file.to_s, reason: key, message: message.to_s }
      nil
    end
  end
end
