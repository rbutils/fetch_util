# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "json"
require "openssl"
require "time"
require "timeout"
require "uri"

module FetchUtil
  class Regulatory
    CACHE_TTL = 86_400
    CACHE_VERSION = 2
    DEFAULT_CACHE_PATH = File.expand_path("~/.local/state/fetch_util/regulatory-cache")
    MACHINE_SOURCES = %w[
      robotstxt
      contentsignal
      contentusagerobots
      contentusageheader
      trusttxt
      xrobotstag
      metarobots
      tdmrep
      tdmheaders
      tdmmeta
      tdmpolicy
    ].freeze
    HUMAN_SOURCES = %w[human].freeze
    SOURCE_CLASSES = {
      "machine" => MACHINE_SOURCES,
      "human" => HUMAN_SOURCES
    }.freeze

    Response = Struct.new(:url, :status, :headers, :body, :redirects, keyword_init: true)
    autoload :HttpClient, "fetch_util/regulatory/http_client"
    autoload :Orchestration, "fetch_util/regulatory/orchestration"
    autoload :SourceSelection, "fetch_util/regulatory/source_selection"
    autoload :Signals, "fetch_util/regulatory/signals"
    autoload :FetchRecords, "fetch_util/regulatory/fetch_records"
    autoload :CacheStore, "fetch_util/regulatory/cache_store"
    autoload :Robots, "fetch_util/regulatory/robots"
    autoload :RobotGlobs, "fetch_util/regulatory/robot_globs"
    autoload :Headers, "fetch_util/regulatory/headers"
    autoload :Directives, "fetch_util/regulatory/directives"
    autoload :TdmSupport, "fetch_util/regulatory/tdm_support"
    autoload :TdmPage, "fetch_util/regulatory/tdm_page"
    autoload :TrustTxt, "fetch_util/regulatory/trust_txt"
    autoload :UsagePreferences, "fetch_util/regulatory/usage_preferences"
    autoload :Page, "fetch_util/regulatory/page"
    autoload :TdmRep, "fetch_util/regulatory/tdm_rep"
    autoload :TdmPolicy, "fetch_util/regulatory/tdm_policy"
    autoload :Human, "fetch_util/regulatory/human"

    include Orchestration
    include SourceSelection
    include Signals
    include FetchRecords
    include CacheStore
    include Robots
    include RobotGlobs
    include Headers
    include Directives
    include TdmSupport
    include TdmPage
    include TrustTxt
    include UsagePreferences
    include Page
    include TdmRep
    include TdmPolicy
    include Human
  end
end
