module Reporting
  class CheckReporter
    def initialize(whitelist)
      @whitelist = whitelist
    end

    def create_report(name, headers, candidate_rows)
      whitelister = @whitelist.get_whitelister(name, headers)
      rows = candidate_rows.reject(&whitelister.whitelist_function)
      unused_whitelist_entries = whitelister.unused_entries
      Reporting::Report.new(
        name: name,
        success: rows.empty?,
        summary: "#{name} report: found #{rows.size} (#{candidate_rows.size - rows.size} whitelisted)",
        csv: generate_csv(headers, rows),
        csv_including_whitelisted_rows: generate_csv(headers, candidate_rows),
        unused_whitelist_entries: unused_whitelist_entries,
      )
    end

    def report_expired_whitelist_entries
      headers = %w(check_name expiry_date reason)
      expiries = @whitelist.report_expired_entries(Date.today)
      create_report('ExpiredWhitelistEntries', headers, expiries)
    end

  private

    def generate_csv(headers, rows)
      CSV.generate do |csv|
        csv << headers
        rows.each { |row| csv << row }
      end
    end
  end


  class Report
    attr_reader :name, :success, :summary, :csv, :csv_including_whitelisted_rows, :unused_whitelist_entries

    private_class_method :initialize

    def initialize(name:, success:, summary:, csv:, csv_including_whitelisted_rows:, unused_whitelist_entries:)
      @name = name
      @success = success
      @summary = summary
      @csv = csv
      @csv_including_whitelisted_rows = csv_including_whitelisted_rows
      @unused_whitelist_entries = unused_whitelist_entries
    end
  end
end
