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

      def source_selection
        @source_tokens ? @source_tokens.dup : resolve_sources(nil)
      end

      def normalized_source_selection(sources)
        return if sources.nil?

        resolve_sources(sources).map { |source| source.dup.freeze }.freeze
      end

      def validate_source!(source)
        return if all_sources.include?(source)

        raise ArgumentError, "unsupported regulatory source: #{source}"
      end

      def needs_page_fetch?(selected_sources)
        (selected_sources & PAGE_RECORD_SOURCES).any? || selected_sources.include?("tdmpolicy")
      end

      def needs_tdmrep_fetch?(selected_sources)
        (selected_sources & %w[tdmrep tdmpolicy]).any?
      end

      def needs_robots_fetch?(selected_sources)
        (selected_sources & ROBOTS_RECORD_SOURCES).any?
      end

      def add_source_payload(result, source, signals)
        return if signals.nil? || signals.empty?

        result[source] = signals
      end
    end
  end
end
