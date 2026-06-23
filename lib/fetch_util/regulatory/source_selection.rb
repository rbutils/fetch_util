# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module SourceSelection
      private

      def all_sources
        @all_sources ||= (MACHINE_SOURCES + HUMAN_SOURCES).freeze
      end

      def resolve_sources(selection)
        tokens = Array(selection || "machine").flat_map { |value| value.to_s.split(",") }
        tokens = tokens.map(&:strip).reject(&:empty?)
        selected = []

        tokens.each do |token|
          remove = token.start_with?("-")
          name = remove ? token[1..] : token
          expansions = SOURCE_CLASSES.fetch(name, [name])

          expansions.each do |source|
            validate_source!(source)
            if remove
              selected.delete(source)
            else
              selected << source unless selected.include?(source)
            end
          end
        end

        selected
      end

      def validate_source!(source)
        return if all_sources.include?(source)

        raise ArgumentError, "unsupported regulatory source: #{source}"
      end

      def needs_page_fetch?(selected_sources)
        (selected_sources & (HUMAN_SOURCES + %w[xrobotstag metarobots tdmheaders tdmmeta contentusageheader tdmpolicy])).any?
      end

      def needs_tdmrep_fetch?(selected_sources)
        (selected_sources & %w[tdmrep tdmpolicy]).any?
      end

      def needs_robots_fetch?(selected_sources)
        (selected_sources & %w[robotstxt contentsignal contentusagerobots]).any?
      end

      def add_source_payload(result, source, signals)
        return if signals.nil? || signals.empty?

        result[source] = signals
      end
    end
  end
end
