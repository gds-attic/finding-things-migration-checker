require 'pg'

class Database
  def initialize
    @connection = PG.connect('postgresql:///migration_checker')
  end

  def create_table(table_name:, columns:)
    query = <<-SQL
      CREATE TABLE IF NOT EXISTS #{table_name} (
        #{columns.join(",")}
      )
    SQL

    @connection.exec("DROP TABLE IF EXISTS #{table_name}")
    @connection.exec(query)
  end

  def copy_rows(table_name:)
    enco = PG::TextEncoder::CopyRow.new

    @connection.copy_data "COPY #{table_name} FROM STDIN", enco do
      yield
    end
  end

  def copy_row(row)
    @connection.put_copy_data(row)
  end

  # Compare links where we have a matching {base_path, link_type} pair in both
  # rummager and publishing api, but the links are different.
  def compare!
    query = <<-SQL
      SELECT
        publishing_api.base_path,
        publishing_api.publishing_app,
        rummager.link_base_paths,
        publishing_api.link_base_paths
      FROM publishing_api
      JOIN rummager using(base_path, link_type)
      WHERE publishing_api.link_base_paths <> rummager.link_base_paths
    SQL

    results = @connection.exec(query)
    results.each_row do |row|
      puts row
      puts '------------------------------'
    end

    puts "#{results.ntuples} mismatches found"
  end

  # Identify rummager content that is not in the publishing api.
  # This content is ignored in other queries.
  def find_unmatched_base_paths!
    query = <<-SQL
      SELECT DISTINCT base_path FROM rummager
      EXCEPT
      SELECT base_path FROM api_content
    SQL

    results = @connection.exec(query)

    puts "UNMATCHED BASE PATHS"

    results.each_row do |row|
      puts row
      puts '------------------------------'
    end

    puts "#{results.ntuples} unmatched base paths found"
  end

  # Find content that is missing a link type in publishing api that exists
  # in rummager.
  def find_missing_publishing_api_link_types!(publishing_app:)
    query = <<-SQL
      WITH
      publishing_api_combined as (
        SELECT
          base_path,
          'organisations'::text as link_type
        FROM
          publishing_api
        WHERE link_type in ('lead_organisations', 'organisations')
      ),

      missing_links as (
        SELECT
          rummager.base_path, rummager.link_type
        FROM rummager

        EXCEPT

        SELECT
          base_path,link_type
        FROM publishing_api_combined
      )

      SELECT base_path, link_type, format
      FROM
        missing_links
      JOIN
        api_content USING(base_path)
      WHERE api_content.publishing_app = $1
    SQL

    results = @connection.exec(query, [publishing_app])

    puts "MISSING LINKS: #{publishing_app.upcase}"

    results.each_row do |row|
      puts row
      puts '------------------------------'
    end

    puts "#{results.ntuples} missing #{publishing_app} links found"
  end

  def summarise_missing_publishing_api_link_types!
    query = <<-SQL

      WITH

      publishing_api_combined as (
        SELECT
          base_path,
          'organisations'::text as link_type
        FROM
          publishing_api
        WHERE link_type in ('lead_organisations', 'organisations')
      ),

      missing_links as (
        SELECT
          rummager.base_path, rummager.link_type
        FROM rummager
        WHERE link_type='organisations'

        EXCEPT

        SELECT base_path, link_type
        FROM publishing_api_combined
      )
      SELECT link_type, publishing_app, count(*)
      FROM
        missing_links
        JOIN api_content USING(base_path)
      GROUP BY link_type, publishing_app
    SQL

    results = @connection.exec(query)

    puts "MISSING LINKS SUMMARY:"

    results.each_row do |row|
      puts row
      puts '------------------------------'
    end

  end

end