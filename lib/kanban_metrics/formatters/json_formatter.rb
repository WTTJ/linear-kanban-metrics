# frozen_string_literal: true

require 'json'

module KanbanMetrics
  module Formatters
    # Handles JSON formatting
    class JsonFormatter
      def initialize(metrics, team_metrics = nil, timeseries = nil)
        @metrics = metrics
        @team_metrics = team_metrics
        @timeseries = timeseries
      end

      def generate
        output = { overall_metrics: @metrics }
        output[:team_metrics] = @team_metrics if @team_metrics
        output[:timeseries] = build_timeseries_data if @timeseries
        JSON.pretty_generate(output)
      end

      private

      def build_timeseries_data
        return {} unless @timeseries

        {
          status_flow_analysis: @timeseries.status_flow_analysis,
          average_time_in_status: @timeseries.average_time_in_status,
          daily_status_counts: @timeseries.daily_status_counts
        }
      end
    end
  end
end
