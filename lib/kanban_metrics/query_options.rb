# frozen_string_literal: true

module KanbanMetrics
  # Value object for API query options
  class QueryOptions
    attr_reader :team_id, :start_date, :end_date, :page_size, :no_cache, :include_archived

    def initialize(options = {})
      @team_id = options[:team_id]
      @start_date = options[:start_date]
      @end_date = options[:end_date]
      @page_size = normalize_page_size(options[:page_size])
      @no_cache = options[:no_cache]
      @include_archived = options[:include_archived] || false
    end

    def cache_key_data
      {
        team_id: team_id,
        start_date: start_date,
        end_date: end_date,
        page_size: page_size,
        include_archived: include_archived
      }.compact
    end

    def to_h
      {
        team_id: team_id,
        start_date: start_date,
        end_date: end_date,
        page_size: page_size,
        no_cache: no_cache,
        include_archived: include_archived
      }
    end

    private

    def normalize_page_size(size)
      return 250 unless size

      # Handle string inputs - if invalid, fallback to default
      if size.is_a?(String)
        converted = size.to_i
        return 250 if converted.zero? && size != '0' # Invalid string case

        normalized = converted
      else
        normalized = size
      end

      [[normalized, 1].max, 250].min
    end
  end
end
