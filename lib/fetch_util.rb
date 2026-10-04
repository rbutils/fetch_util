# frozen_string_literal: true

require "addressable/uri"
require "ferrum"
require "public_suffix"
require "uri"

require_relative "fetch_util/version"

module FetchUtil
  class Error < StandardError; end
  class InputError < ArgumentError; end
  class BrowserError < Error; end
  class ExtractionError < Error; end

  autoload :DocsLikeUrl, "fetch_util/docs_like_url"

  # Preserve the existing constants while keeping the classifier cohesive.
  DOCS_LIKE_EXACT_HOSTS = DocsLikeUrl::EXACT_HOSTS
  DOCS_LIKE_PATH_KEYWORDS = DocsLikeUrl::PATH_KEYWORDS
  DOCS_LIKE_PATH_PATTERN = DocsLikeUrl::PATH_PATTERN

  autoload :Browser, "fetch_util/browser"
  autoload :CLI, "fetch_util/cli"
  autoload :Extractor, "fetch_util/extractor"
  autoload :Fetcher, "fetch_util/fetcher"
  autoload :ParallelFetcher, "fetch_util/parallel_fetcher"
  autoload :PdfProbe, "fetch_util/pdf_probe"
  autoload :Regulatory, "fetch_util/regulatory"
  autoload :RawDocsFallback, "fetch_util/raw_docs_fallback"
  autoload :RequestLog, "fetch_util/request_log"
  autoload :Result, "fetch_util/result"
  autoload :Searcher, "fetch_util/searcher"
  autoload :SearchTransport, "fetch_util/search_transport"

  module_function

  def fetch(url, **options)
    Fetcher.fetch_once(url, **options)
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
    DocsLikeUrl.match?(value)
  end
end
