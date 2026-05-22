namespace :body_ledger do
  desc "Import legacy Obsidian journal files into typed Body Ledger records"
  task import_journal: :environment do
    username = ENV.fetch("USERNAME")
    journal_path = ENV.fetch("JOURNAL_PATH", "/home/jwl/projects/notes/journal")
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))

    user = User.find_by!(username: username)
    device = user.devices.find_or_create_by!(name: "Legacy journal import", platform: "desktop") do |record|
      record.token_digest = Digest::SHA256.hexdigest("legacy-journal-import:#{user.id}")
      record.is_active = false
    end

    result = Importers::JournalImporter.new(
      user: user,
      device: device,
      path: journal_path,
      dry_run: dry_run
    ).import!

    puts JSON.pretty_generate(result)
  end
end
