# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Promotion cleanup eligibility' do
  include_context 'extractor integration helpers'

  def promo_work_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~'JS')
      window.promoWorkProbe = withComposedDomRead(function() {
        var root = document.querySelector('#source').cloneNode(true);
        var original = elementVisuallyHidden, calls = 0;
        elementVisuallyHidden = function(node) { calls++; return original(node); };
        try {
          stripPromoAdModules(root);
          return {html: root.innerHTML, visibilityReads: calls};
        } finally { elementVisuallyHidden = original; }
      });
      })(window);
    JS
  end

  it 'retains every ordinary section without repeated editorial visibility assessment' do
    sections = (1..240).map do |number|
      "<section><h2>Published section #{number}</h2><div><p>" \
        "The complete authored discussion #{number} explains subscriptions, privacy, support and services. " \
        "Each paragraph and its <a href=\"/references/#{number}\">published reference</a> remains part of this work." \
        "</p><pre><code>complete_program_#{number}();</code></pre></div></section>"
    end.join
    with_url_page('https://publication.example.test/reference/guide', "<article id='source'>#{sections}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: promo_work_probe)
      result = page.evaluate('promoWorkProbe({})')
      expect(result.fetch('html')).to eq(sections)
      expect(result.fetch('visibilityReads')).to eq(0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps substantive attributed layouts while still removing proved promotional modules' do
    paragraph = 'This complete authored explanation develops the technical subject, its alternatives and implications. ' * 3
    retained = "<div class=\"sponsor\"><h2>Published analysis</h2><p>#{paragraph}</p><p>#{paragraph}</p></div>" \
               '<section class="cta"><h2>Published section without an action</h2><p>Original explanation.</p></section>'
    removed = "<aside class='advertisement'><p>Buy now</p><a href='/purchase'>Shop now</a></aside>" \
              "<div><img src='/ads/banner.png'><p>Buy now</p></div>"
    with_url_page('https://publication.example.test/reference/guide', "<article id='source'>#{retained}#{removed}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: promo_work_probe)
      result = page.evaluate('promoWorkProbe({})')
      expect(result.fetch('html')).to eq(retained)
      expect(result.fetch('visibilityReads')).to eq(4)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
