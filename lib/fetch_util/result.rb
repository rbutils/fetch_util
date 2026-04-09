# frozen_string_literal: true

module FetchUtil
  class Result
    attr_reader :url, :final_url, :title, :byline, :excerpt, :site_name,
                :published_time, :canonical_url, :language, :html, :markdown,
                :metadata, :reader_mode, :content_type, :suspect, :warnings,
                :content_completeness_ratio, :content_format, :paywall_state

    def initialize(url:, final_url:, title:, byline:, excerpt:, site_name:, published_time:,
                   canonical_url:, language:, html:, markdown:, metadata:, reader_mode:, content_type:, suspect:, warnings:,
                   content_completeness_ratio: 1.0, content_format: nil, paywall_state: nil)
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
        paywall_state: paywall_state
      }
    end
  end
end
