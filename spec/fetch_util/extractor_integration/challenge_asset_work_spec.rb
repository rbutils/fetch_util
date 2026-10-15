# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Challenge evidence eligibility' do
  include_context 'extractor integration helpers'

  def challenge_asset_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.challengeAssetProbe = function(cases) {
        var originalAssets = challengeAssetText, originalNormalize = normalizeText;
        var reads = 0, combinations = 0;
        challengeAssetText = function(signals) { reads++; return originalAssets(signals); };
        normalizeText = function(value) {
          if (typeof value === 'string' && value.indexOf('FULL_REPORT_MARKER') !== -1 &&
              value.indexOf('FULL_ASSET_MARKER') !== -1) combinations++;
          return originalNormalize(value);
        };
        try {
          return cases.map(function(entry) {
            var beforeReads = reads, beforeCombinations = combinations;
            var classify = entry.kind === 'data' ? dataDomeChallengePage : cloudflareChallengePage;
            var result = classify(entry.title || '', entry.page || '', entry.signals || {});
            return {challenge: result, reads: reads - beforeReads, combinations: combinations - beforeCombinations};
          });
        } finally {
          challengeAssetText = originalAssets;
          normalizeText = originalNormalize;
        }
      };
      })(window);
    JS
  end

  it 'does no irrelevant full-asset combination for complete published material or decisive page labels' do
    sections = (1..240).map do |number|
      "<section><h2>Published evidence #{number}</h2><p>Complete report #{number} remains visible.</p>" \
        "<a href='/record/#{number}'>Source reference #{number}</a></section>"
    end.join
    with_url_page('https://publication.example.test/reference', "<article>#{sections}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: challenge_asset_probe)
      body = "FULL_REPORT_MARKER #{sections}"
      signals = { bodyHtml: "FULL_ASSET_MARKER #{sections}" }
      cases = [{ kind: 'data', page: body, signals: signals },
               { kind: 'cloud', page: body, signals: signals },
               { kind: 'data', title: 'DataDome CAPTCHA', page: body, signals: signals },
               { kind: 'cloud', title: 'Just a moment', page: body, signals: signals },
               { kind: 'cloud', page: "This page explains challenge examples. #{body}", signals: signals }]
      expected = [[false, 1], [false, 0], [true, 0], [true, 0], [false, 0]].map do |challenge, reads|
        { 'challenge' => challenge, 'reads' => reads, 'combinations' => 0 }
      end
      expect(page.evaluate("challengeAssetProbe(#{JSON.generate(cases)})")).to eq(expected)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete asset gates, normalization and labels spanning title and page' do
    with_url_page('https://publication.example.test/access', '<main><h1>Access verification</h1></main>') do |page|
      page.add_script_tag(content: challenge_asset_probe)
      marker = { bodyHtml: 'var dd = {};' }
      cases = [{ page: 'x' * 79, signals: marker },
               { page: 'x' * 80, signals: marker },
               { page: 'x' * 120, signals: { bodyHtml: "var dd = {}; PLEASE   ENABLE\nJAVASCRIPT" } },
               { title: 'Please enable', page: "JavaScript to continue #{"x" * 120}", signals: marker },
               { page: 'x' * 120, signals: { bodyHtml: 'Please enable JavaScript' } },
               { page: 'loading', signals: { bodyHtml: "ddjsKey = 'value';" } },
               { title: 'DataDome CAPTCHA', page: 'x' * 120 }]
      cases.each { |entry| entry[:kind] = 'data' }
      expected = [[true, 1], [false, 1], [true, 1], [true, 1], [false, 1], [true, 1], [true, 0]].map do |challenge, reads|
        { 'challenge' => challenge, 'reads' => reads, 'combinations' => 0 }
      end
      expect(page.evaluate("challengeAssetProbe(#{JSON.generate(cases)})")).to eq(expected)
    end
  end

  it 'retains the exact short-page boundary, positive challenge labels and educational exclusions' do
    with_url_page('https://publication.example.test/access', '<main><h1>Access verification</h1></main>') do |page|
      page.add_script_tag(content: challenge_asset_probe)
      signals = { scriptSources: ['https://challenge.example.test/cdn-cgi/challenge-platform/'] }
      cases = [{ page: 'x' * 119, signals: signals },
               { page: 'x' * 120, signals: signals },
               { title: 'Turnstile', page: "Managed challenge #{"x" * 120}", signals: signals },
               { page: "This page explains verification. #{"x" * 120}", signals: signals },
               { page: 'loading', signals: { bodyHtml: 'example page cdn-cgi/challenge-platform' } },
               { page: 'x' * 119, signals: {} },
               { title: 'Attention Required! | Cloudflare', page: 'x' * 120 }]
      cases.each { |entry| entry[:kind] = 'cloud' }
      expected = [[true, 1], [false, 0], [true, 0], [false, 0], [false, 1], [false, 1], [true, 0]].map do |challenge, reads|
        { 'challenge' => challenge, 'reads' => reads, 'combinations' => 0 }
      end
      expect(page.evaluate("challengeAssetProbe(#{JSON.generate(cases)})")).to eq(expected)
    end
  end
end
