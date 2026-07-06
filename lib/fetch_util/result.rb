# frozen_string_literal: true

module FetchUtil
  class Result
    attr_reader :url, :final_url, :title, :byline, :excerpt, :site_name,
                :published_time, :canonical_url, :language, :html, :markdown,
                :metadata, :reader_mode, :content_type, :suspect, :warnings,
                :content_completeness_ratio, :content_format, :paywall_state,
                :error_message

    class << self
      def from_payload(url:, final_url:, payload:, canonical_url:, content_type:, warnings:, suspect:)
        content_completeness_ratio = payload["contentCompletenessRatio"]&.to_f || 1.0
        content_format = payload["contentFormat"]
        paywall_state = payload["paywallState"]
        metadata = payload_metadata(
          payload,
          canonical_url: canonical_url,
          final_url: final_url,
          content_type: content_type,
          suspect: suspect,
          warnings: warnings,
          content_completeness_ratio: content_completeness_ratio,
          content_format: content_format,
          paywall_state: paywall_state
        )

        new(
          url: url,
          final_url: final_url,
          title: payload["title"],
          byline: payload["byline"],
          excerpt: payload["excerpt"],
          site_name: payload["siteName"],
          published_time: payload["publishedTime"],
          canonical_url: canonical_url,
          language: payload["language"],
          html: payload["html"],
          markdown: payload["markdown"],
          metadata: metadata,
          reader_mode: payload["readerMode"],
          content_type: content_type,
          suspect: suspect,
          warnings: warnings,
          content_completeness_ratio: content_completeness_ratio,
          content_format: content_format,
          paywall_state: paywall_state
        )
      end

      def error(url:, warning:, message:)
        metadata = {
          content_url: url,
          content_type: "error",
          suspect: true,
          warnings: [warning],
          error_message: message
        }.freeze

        new(
          url: url,
          final_url: url,
          title: nil,
          byline: nil,
          excerpt: nil,
          site_name: nil,
          published_time: nil,
          canonical_url: nil,
          language: nil,
          html: nil,
          markdown: "",
          metadata: metadata,
          reader_mode: nil,
          content_type: "error",
          suspect: true,
          warnings: [warning],
          error_message: message
        )
      end

      private

      def payload_metadata(payload, canonical_url:, final_url:, content_type:, suspect:, warnings:,
                           content_completeness_ratio:, content_format:, paywall_state:)
        {
          title: payload["title"],
          byline: payload["byline"],
          excerpt: payload["excerpt"],
          site_name: payload["siteName"],
          published_time: payload["publishedTime"],
          canonical_url: canonical_url,
          language: payload["language"],
          content_url: final_url,
          reader_mode: payload["readerMode"],
          content_type: content_type,
          suspect: suspect,
          warnings: warnings,
          content_completeness_ratio: content_completeness_ratio,
          content_format: content_format,
          paywall_state: paywall_state
        }.freeze
      end
    end

    def initialize(url:, final_url:, title:, byline:, excerpt:, site_name:, published_time:,
                   canonical_url:, language:, html:, markdown:, metadata:, reader_mode:, content_type:, suspect:, warnings:,
                   content_completeness_ratio: 1.0, content_format: nil, paywall_state: nil, error_message: nil)
      @url = url
      @final_url = final_url
      @title = title
      @byline = byline
      @excerpt = excerpt
      @site_name = site_name
      @published_time = published_time
      @canonical_url = canonical_url
      @language = language
      @html = html
      @markdown = markdown
      @metadata = metadata.freeze
      @reader_mode = reader_mode
      @content_type = content_type
      @suspect = suspect
      @warnings = warnings.freeze
      @content_completeness_ratio = content_completeness_ratio
      @content_format = content_format&.freeze
      @paywall_state = paywall_state&.freeze
      @error_message = error_message
    end

    def to_h
      {
        url: url,
        final_url: final_url,
        title: title,
        byline: byline,
        excerpt: excerpt,
        site_name: site_name,
        published_time: published_time,
        canonical_url: canonical_url,
        language: language,
        html: html,
        markdown: markdown,
        metadata: metadata,
        reader_mode: reader_mode,
        content_type: content_type,
        suspect: suspect,
        warnings: warnings,
        content_completeness_ratio: content_completeness_ratio,
        content_format: content_format,
        paywall_state: paywall_state,
        error_message: error_message
      }
    end
  end
end
