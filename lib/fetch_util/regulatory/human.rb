# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Human
      HUMAN_PATTERNS = [
        {
          "verb" => "disallow",
          "noun" => "text-and-data-mining",
          "regex" => /
            \b(?:do\s+not|does\s+not|must\s+not|may\s+not|shall\s+not|not\s+permit(?:ted)?|not\s+allow(?:ed)?|forbid(?:den|s)?|prohibit(?:ed|s)?)\b.{0,120}
            \b(?:text\s+and\s+data\s+mining|text-and-data-mining|tdm)\b
          /ix
        },
        {
          "verb" => "disallow",
          "noun" => "ai-training",
          "regex" => /
            \b(?:do\s+not|does\s+not|must\s+not|may\s+not|shall\s+not|not\s+permit(?:ted)?|not\s+allow(?:ed)?|forbid(?:den|s)?|prohibit(?:ed|s)?)\b.{0,120}
            \b(?:ai\s+training|training\s+(?:of|for)\s+(?:ai|models?)|machine\s+learning|large\s+language\s+model|large\s+language\s+models|llm|generative\s+ai)\b
          /ix
        },
        {
          "verb" => "disallow",
          "noun" => "index",
          "regex" => /
            \b(?:do\s+not|does\s+not|must\s+not|may\s+not|shall\s+not|not\s+permit(?:ted)?|not\s+allow(?:ed)?|forbid(?:den|s)?|prohibit(?:ed|s)?)\b.{0,120}
            \b(?:index(?:ing)?|search\s+engine(?:s)?)\b
          /ix
        },
        {
          "verb" => "disallow",
          "noun" => "fetch",
          "regex" => /
            \b(?:do\s+not|does\s+not|must\s+not|may\s+not|shall\s+not|not\s+permit(?:ted)?|not\s+allow(?:ed)?|forbid(?:den|s)?|prohibit(?:ed|s)?)\b.{0,120}
            \b(?:crawl(?:ing)?|scrap(?:e|ing)|fetch(?:ing)?|bot(?:s)?)\b
          /ix
        },
        {
          "verb" => "allow",
          "noun" => "text-and-data-mining",
          "regex" => /\b(?:allow(?:ed|s)?|permit(?:ted|s)?|may|can)\b.{0,120}\b(?:text\s+and\s+data\s+mining|text-and-data-mining|tdm)\b/i
        },
        {
          "verb" => "allow",
          "noun" => "ai-training",
          "regex" => /
            \b(?:allow(?:ed|s)?|permit(?:ted|s)?|may|can)\b.{0,120}
            \b(?:ai\s+training|training\s+(?:of|for)\s+(?:ai|models?)|machine\s+learning|large\s+language\s+model|large\s+language\s+models|llm|generative\s+ai)\b
          /ix
        },
        {
          "verb" => "allow",
          "noun" => "index",
          "regex" => /\b(?:allow(?:ed|s)?|permit(?:ted|s)?|may|can)\b.{0,120}\b(?:index(?:ing)?|search\s+engine(?:s)?)\b/i
        },
        {
          "verb" => "allow",
          "noun" => "fetch",
          "regex" => /\b(?:allow(?:ed|s)?|permit(?:ted|s)?|may|can)\b.{0,120}\b(?:crawl(?:ing)?|scrap(?:e|ing)|fetch(?:ing)?|bot(?:s)?)\b/i
        }
      ].freeze

      def extract_human_signals(body, path:)
        chunks = human_text_chunks(body)
        seen = {}

        HUMAN_PATTERNS.filter_map do |entry|
          evidence = chunks.find { |chunk| chunk.match?(entry["regex"]) }
          next unless evidence
          next if entry["verb"] == "allow" && negative_human_chunk?(evidence)

          key = [entry["verb"], entry["noun"], evidence]
          next if seen[key]

          seen[key] = true
          build_signal(
            entry["verb"],
            entry["noun"],
            path: path,
            conditions: { "evidence" => evidence }
          )
        end
      end

      private

      def human_text_chunks(body)
        text = body.to_s
        text = text.gsub(%r{<script\b.*?</script>}mi, " ")
        text = text.gsub(%r{<style\b.*?</style>}mi, " ")
        text = text.gsub(%r{<noscript\b.*?</noscript>}mi, " ")
        text = text.gsub(/<[^>]+>/, " ")
        text = CGI.unescapeHTML(text)
        text = FetchUtil.normalize_whitespace(text)
        text.split(/(?<=[.!?])\s+/).map { |chunk| chunk.strip }.reject(&:empty?)
      end

      def negative_human_chunk?(chunk)
        chunk.match?(/\b(?:do\s+not|does\s+not|must\s+not|may\s+not|shall\s+not|not\s+permit(?:ted)?|not\s+allow(?:ed)?|forbid(?:den|s)?|prohibit(?:ed|s)?)\b/i)
      end
    end
  end
end
