# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Partial-paywall assessment eligibility' do
  include_context 'extractor integration helpers'

  def partial_paywall_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.partialPaywallProbe = function(cases) {
        var reads = 0, active, original = paywallSignals;
        var originalPublic = visiblePublicArticleBodyRetained, originalPaid = visibleDeclaredPaidBodyRetained;
        paywallSignals = function() { reads++; return {dom: true}; };
        visiblePublicArticleBodyRetained = function() { return active.publicRetained === true; };
        visibleDeclaredPaidBodyRetained = function() { return active.paidRetained === true; };
        try {
          return cases.map(function(entry) {
            active = entry;
            var before = reads, body = 'r'.repeat(entry.body), page = 'r'.repeat(entry.page);
            var metadata = {title: 'Complete report', language: 'en', isAccessibleForFree: entry.free};
            var content = {contentType: 'article', docsLike: true, html: document.body.innerHTML, textContent: body};
            var reasons = contentIntegrityWarningReasons(metadata, content, body, body, page,
              body + ' ' + page, 'complete report', true, true, false, false, false,
              null, null, true, false, false, true, true);
            return {partial: reasons.indexOf('paywall_partial_content') !== -1, reads: reads - before};
          });
        } finally {
          paywallSignals = original;
          visiblePublicArticleBodyRetained = originalPublic;
          visibleDeclaredPaidBodyRetained = originalPaid;
        }
      };
      })(window);
    JS
  end

  it 'does no source-wide paywall assessment for complete long bodies or empty output' do
    sections = (1..240).map do |number|
      "<section><h2>Published evidence #{number}</h2><p>Complete report #{number} remains available.</p>" \
        "<a href='/record/#{number}'>Source reference #{number}</a></section>"
    end.join
    with_url_page('https://publication.example.test/2026/10/15/complete-report', "<article>#{sections}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: partial_paywall_probe)
      cases = [12_000, 24_000, 120_000].product([true, false]).map do |length, free|
        { body: length, page: length * 2, free: free }
      end
      cases.concat([{ body: 0, page: 20_000, free: false }, { body: 0, page: 0, free: true }])
      result = page.evaluate("partialPaywallProbe(#{JSON.generate(cases)})")
      expect(result).to eq(Array.new(cases.length) { { 'partial' => false, 'reads' => 0 } })
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains the existing access, absolute-length and ratio boundaries' do
    with_url_page('https://publication.example.test/2026/10/15/complete-report', '<main><h1>Complete report</h1></main>') do |page|
      page.add_script_tag(content: partial_paywall_probe)
      entries = [[4999, 10_000, false, true], [5000, 5000, false, false],
                 [5000, 15_000, false, true], [6000, 15_000, false, false],
                 [7999, 20_000, false, true], [8000, 20_001, false, false],
                 [11_999, 48_000, false, true], [12_000, 60_000, false, false],
                 [9000, 36_000, false, false], [4000, 10_000, true, false],
                 [4000, 20_000, true, true], [4999, 10_000, 'true', true],
                 [1, 0, false, true], [1, 0, true, false]]
      cases = entries.map { |body, length, free, _| { body: body, page: length, free: free } }
      expected = entries.map { |_, _, _, partial| { 'partial' => partial, 'reads' => partial ? 1 : 0 } }
      expect(page.evaluate("partialPaywallProbe(#{JSON.generate(cases)})")).to eq(expected)
    end
  end

  it 'retains source-proved complete public and paid bodies even when the scalar teaser test passes' do
    with_url_page('https://publication.example.test/2026/10/15/complete-report', '<main><h1>Complete report</h1></main>') do |page|
      page.add_script_tag(content: partial_paywall_probe)
      cases = [{ body: 4000, page: 20_000, free: false, publicRetained: true },
               { body: 4000, page: 20_000, free: false, paidRetained: true },
               { body: 4000, page: 20_000, free: false }]
      expect(page.evaluate("partialPaywallProbe(#{JSON.generate(cases)})")).to eq(
        [{ 'partial' => false, 'reads' => 1 }, { 'partial' => false, 'reads' => 1 }, { 'partial' => true, 'reads' => 1 }]
      )
    end
  end
end
