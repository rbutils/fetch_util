# frozen_string_literal: true

module FetchUtil
  # Shared documentation-URL heuristics, independent of fetch transport.
  module DocsLikeUrl
    EXACT_HOSTS = %w[
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
    PATH_KEYWORDS = %w[
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
    PATH_PATTERN = %r{/
      (?:
        docs?|reference|api(?:/reference)?|tutorial|guide|guides|library|libraries|
        book|books|dictionary|definition|definitions|concept|concepts|
        get(?:ting)?-started|quick-start|how-to|howto|manual|sdk|learn
      )
      (?:/|\b)
    }x

    module_function

    def match?(value)
      uri = value.is_a?(URI::Generic) ? value : URI.parse(FetchUtil.normalize_url(value.to_s.strip))
      return false unless uri.is_a?(URI::HTTP) && uri.host

      host = FetchUtil.strip_www_host(uri)
      path = uri.path.to_s.downcase
      path_terms = path.split(/[^a-z0-9]+/)

      return true if EXACT_HOSTS.include?(host)
      return true if host.end_with?(".readthedocs.io")
      return true if host.start_with?("docs.") || host.start_with?("developer.") || host.start_with?("developers.") || host.start_with?("api.")
      return true if host.match?(/\b(?:dictionary|merriam-webster|thefreedictionary|wiktionary|collinsdictionary|reverso)\b/)
      return true if host == "go.dev" && path.match?(%r{\A/ref(?:/|\b)})
      return true if path.match?(PATH_PATTERN)
      return true if (path_terms & PATH_KEYWORDS).any?

      false
    rescue URI::InvalidURIError
      false
    end
  end

  private_constant :DocsLikeUrl
end
