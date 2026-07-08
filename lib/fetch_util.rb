# frozen_string_literal: true

require "addressable/uri"
require "uri"

require_relative "fetch_util/version"

module FetchUtil
  class Error < StandardError; end
  class BrowserError < Error; end
  class ExtractionError < Error; end

  DOCS_LIKE_EXACT_HOSTS = %w[
    developer.mozilla.org
    doc.rust-lang.org
    docs.rs
    fastapi.tiangolo.com
    learn.microsoft.com
    ncbi.nlm.nih.gov
    nextjs.org
    pkg.go.dev
    platform.claude.com
    react.dev
    rubydoc.info
    rubyapi.org
  ].freeze
  DOCS_LIKE_PATH_KEYWORDS = %w[
    api
    book
    books
    concept
    concepts
    definition
    definitions
    dictionary
    doc
    docs
    guide
    guides
    howto
    library
    libraries
    manual
    reference
    sdk
    tutorial
  ].freeze
  DOCS_LIKE_PATH_PATTERN = %r{/
    (?:
      docs?|reference|api(?:/reference)?|tutorial|guide|guides|library|libraries|
      book|books|dictionary|definition|definitions|concept|concepts|
      get(?:ting)?-started|quick-start|how-to|howto|manual|sdk|learn
    )
    (?:/|\b)
  }x

  autoload :Browser, "fetch_util/browser"
  autoload :CLI, "fetch_util/cli"
  autoload :Extractor, "fetch_util/extractor"
  autoload :Fetcher, "fetch_util/fetcher"
  autoload :ParallelFetcher, "fetch_util/parallel_fetcher"
  autoload :Regulatory, "fetch_util/regulatory"
  autoload :RawDocsFallback, "fetch_util/raw_docs_fallback"
  autoload :RequestLog, "fetch_util/request_log"
  autoload :Result, "fetch_util/result"
  autoload :Searcher, "fetch_util/searcher"

  module_function

  def fetch(url, **options)
    Fetcher.new(**options).fetch(url)
  end

  def fetch_many(urls, **options)
    ParallelFetcher.new(**options).fetch(urls)
  end

  def search(query, **options)
    Searcher.new(**options).search(query)
  end

  def regulatory(url, **options)
    Regulatory.new(**options).call(url)
  end

  def normalize_whitespace(value)
    text = value.to_s
    text = text.encode("UTF-8", invalid: :replace, undef: :replace, replace: " ") unless text.encoding == Encoding::UTF_8 && text.valid_encoding?
    text.gsub(/\u00A0/, " ").gsub(/\s+/, " ").strip
  end

  def normalize_url(url)
    return url if url.nil? || url.to_s.empty?

    Addressable::URI.parse(url.to_s).normalize.to_s
  rescue Addressable::URI::InvalidURIError, URI::InvalidURIError
    url.to_s
  end

  def strip_www_host(url)
    uri = url.is_a?(URI::Generic) ? url : URI.parse(url.to_s)
    uri.host.to_s.downcase.sub(/\Awww\./, "")
  end

  def docs_like_url?(value)
    uri = value.is_a?(URI::Generic) ? value : URI.parse(normalize_url(value.to_s.strip))
    return false unless uri.is_a?(URI::HTTP) && uri.host

    host = strip_www_host(uri)
    path = uri.path.to_s.downcase
    path_terms = path.split(/[^a-z0-9]+/)

    return true if DOCS_LIKE_EXACT_HOSTS.include?(host)
    return true if host.end_with?(".readthedocs.io")
    return true if host.start_with?("docs.") || host.start_with?("developer.") || host.start_with?("developers.") || host.start_with?("api.")
    return true if host.match?(/\b(?:dictionary|merriam-webster|thefreedictionary|wiktionary|collinsdictionary|reverso)\b/)
    return true if host == "go.dev" && path.match?(%r{\A/ref(?:/|\b)})
    return true if path.match?(DOCS_LIKE_PATH_PATTERN)
    return true if (path_terms & DOCS_LIKE_PATH_KEYWORDS).any?

    false
  rescue URI::InvalidURIError
    false
  end
end
