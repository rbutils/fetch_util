# frozen_string_literal: true

module FetchUtil
  class Searcher
    module ResultFiltering
      private

      def search_engine_self_link?(title, url, snippet)
        host, path = result_location(url)
        text = compact_text([title, snippet].compact.join(" ")).downcase
        return false if host.empty?

        return true if duckduckgo_self_link?(host, path, title, text)
        return true if google_self_link?(host, path, title, text)
        return true if search_shell_result?(host, path, title)

        false
      end

      def low_value_result?(title, url, snippet)
        host, path = result_location(url)
        return false if host.empty?
        return true if non_html_document_url?(url)
        return true if host == "duckduckgo.com" && path == "/y.js"
        return true if host.start_with?("translate.google.")
        return true if facebook_noise_result?(host, path, title, snippet)
        return true if pinterest_noise_result?(host, path, title)
        return true if host.end_with?("threads.net") || host.end_with?("threads.com")
        return true if tiktok_noise_result?(host, path, snippet)
        return true if host.end_with?("walmart.com") && path.match?(%r{\A/(search|browse|c|cp|b)\b})

        false
      end

      def result_location(url)
        [host_for(url).to_s, path_for(url)]
      end

      def search_action_text?(text)
        /\b(redo search without this site|block this site from all results|go to google home|duckduckgo)\b/.match?(text)
      end

      def duckduckgo_self_link?(host, path, title, text)
        return false unless host.end_with?("duckduckgo.com")

        (path == "/" && (title.casecmp?("DuckDuckGo") || search_action_text?(text))) ||
          (path.start_with?("/html") && search_action_text?(text))
      end

      def google_self_link?(host, path, title, text)
        if host.end_with?("google.com")
          return true if path == "/" && search_action_text?(text)
          return true if %w[/search /preferences /advanced_search /setprefs].include?(path)
        end

        return false unless host.match?(/\Agoogle\.[a-z.]+\z/)

        google_home_shell = /before you continue to google|go to google home/.match?(text) || title.casecmp?("Before you continue to Google")
        (%w[/ /webhp].include?(path) && google_home_shell) ||
          (path.start_with?("/intl/") && /\bgoogle apps|about google|products\b/.match?(text))
      end

      def search_shell_result?(host, path, title)
        return true if host.end_with?("search.brave.com") && path == "/search" && title.casecmp?("Brave Search")
        return true if host.end_with?("bing.com") && path == "/search" && title.casecmp?("Bing")
        return true if host.end_with?("ecosia.org") && path == "/search" && title.casecmp?("Ecosia")

        false
      end

      def facebook_noise_result?(host, path, title, snippet)
        return false unless host.end_with?("facebook.com")

        path.match?(%r{\A/(groups|events|watch|share|reel|photo)\b}) ||
          title.end_with?(" - Facebook") ||
          title.match?(/\(@[^)]+\)/) ||
          snippet.to_s.match?(/\b\d+[,\dKMB+.]*\s*(followers?|likes?|members?)\b/i)
      end

      def pinterest_noise_result?(host, path, title)
        return false unless host.include?("pinterest.")

        !path.match?(%r{\A/search/}) || title.end_with?(" - Pinterest")
      end

      def tiktok_noise_result?(host, path, snippet)
        return false unless host.end_with?("tiktok.com")

        host.start_with?("shop.") ||
          path.match?(%r{\A/@[^/]+/video/}) ||
          snippet.to_s.match?(/\bAll Categories\b/i)
      end

      def non_html_document_url?(url)
        normalized = url.to_s.downcase
        path = path_for(normalized).downcase

        path.end_with?(".pdf") || path.match?(%r{/pdf(?:/|\z)}) || normalized.match?(/[?&](?:format|download)=pdf\b/)
      end
    end
  end
end
