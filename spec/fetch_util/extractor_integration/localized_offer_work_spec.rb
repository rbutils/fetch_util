# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Source-owned subscription offer assessment' do
  include_context 'extractor integration helpers'

  def localized_offer_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.localizedOfferProbe = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'rejects unrelated actions without visibility work and reads each physical owner once' do
    sections = (1..240).map do |number|
      links = (1..12).map { |entry| "<a href='/reference/#{number}/#{entry}'>Published reference #{entry}</a>" }.join
      "<section><h2>Complete report #{number}</h2><p>Authored explanation #{number} #{links}</p></section>"
    end.join
    with_url_page('https://publication.example.test/reports/analysis', "<main><h1>Published reports</h1>#{sections}</main>") do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: localized_offer_probe(<<~'JS'))
        var originalPrefix = localizedSubscriptionOfferPrefix;
        var originalVisibility = elementSubtreeHidden;
        var prefixes = 0, visibility = 0;
        localizedSubscriptionOfferPrefix = function(offer) { prefixes++; return originalPrefix(offer); };
        elementSubtreeHidden = function(node) { visibility++; return originalVisibility(node); };
        try {
          return {recognized: visibleLocalizedSubscriptionOffer(), prefixes: prefixes, visibility: visibility};
        } finally {
          localizedSubscriptionOfferPrefix = originalPrefix;
          elementSubtreeHidden = originalVisibility;
        }
      JS
      expect(page.evaluate('localizedOfferProbe({})')).to eq('recognized' => false, 'prefixes' => 240, 'visibility' => 0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'matches full native text across whitespace, split nodes, boundary collisions and complete long owners' do
    with_url_page('https://publication.example.test/reports/analysis', '<p>Unchanged physical reporting.</p>') do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: localized_offer_probe(<<~'JS'))
        var owner = document.implementation.createHTMLDocument('');
        var offer = owner.createElement('section');
        var examples = ['', 'Wybierz prenumeratę', 'wybierz prenumeratęx', 'wybierz prenumeratę:',
          'wybierz prenumeratę!', 'wybierz prenumeratę?', 'wybierz prenumeratę.', 'wybierz prenumeratę,',
          'wybierz prenumeratę more', '<span>WYB</span>IERZ <em>PRENUMERATĘ</em>!',
          '<span hidden>Earlier words</span>wybierz prenumeratę', '<span hidden>wybierz</span> prenumeratę',
          'wybierz<!-- no extra text --> prenumeratę', '<template>Earlier words</template>wybierz prenumeratę'];
        var whitespace = ['\u0009', '\u000a', '\u000b', '\u000c', '\u000d', '\u0020', '\u00a0',
          '\u1680', '\u2000', '\u2001', '\u2002', '\u2003', '\u2004', '\u2005', '\u2006',
          '\u2007', '\u2008', '\u2009', '\u200a', '\u2028', '\u2029', '\u202f', '\u205f', '\u3000', '\ufeff'];
        whitespace.forEach(function(first) {
          whitespace.forEach(function(second) { examples.push(first + 'wybierz' + first + second + 'prenumeratę' + second); });
        });
        var mismatches = [];
        examples.forEach(function(html, index) {
          offer.innerHTML = html;
          var expected = /^wybierz\s+prenumeratę(?:\s|[,!.?]|$)/iu.test(normalizeText(offer.textContent));
          if (localizedSubscriptionOfferPrefix(offer) !== expected) mismatches.push(index);
        });
        offer.textContent = ' '.repeat(4096) + 'Wybierz prenumeratę!';
        var longWhitespace = localizedSubscriptionOfferPrefix(offer);
        offer.textContent = 'Wybierz prenumeratę!';
        for (var number = 0; number < 240; number++) {
          var paragraph = owner.createElement('p');
          paragraph.textContent = 'Complete authored continuation ' + number + ' with every published explanation.';
          offer.appendChild(paragraph);
        }
        var originalWalker = owner.createTreeWalker;
        var visited = 0;
        owner.createTreeWalker = function(root, filter) {
          var walker = originalWalker.call(this, root, filter);
          var originalNext = walker.nextNode;
          walker.nextNode = function() { visited++; return originalNext.call(this); };
          return walker;
        };
        var recognized;
        try { recognized = localizedSubscriptionOfferPrefix(offer); }
        finally { owner.createTreeWalker = originalWalker; }
        return {mismatches: mismatches, longWhitespace: longWhitespace, recognized: recognized, visited: visited,
          paragraphs: offer.querySelectorAll('p').length, finalText: offer.lastElementChild.textContent};
      JS
      result = page.evaluate('localizedOfferProbe({})')
      expect(result).to include('mismatches' => [], 'longWhitespace' => true, 'recognized' => true, 'visited' => 1, 'paragraphs' => 240)
      expect(result.fetch('finalText')).to include('Complete authored continuation 239')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains visible ordered restricted-body proof and observes visibility, label and heading changes' do
    html = <<~HTML
      <main id="owner"><h1>Published research report</h1>
        <div class="locked"><p>Materialized reporting before the source-owned subscription offer.</p></div>
        <section id="offer">Wybierz prenumeratę, by czytać dalszą część <button id="action">Choose an option</button></section>
      </main>
    HTML
    with_url_page('https://publication.example.test/reports/analysis', html) do |page|
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: localized_offer_probe(<<~'JS'))
        var owner = document.querySelector('#owner'), offer = document.querySelector('#offer');
        var action = document.querySelector('#action'), restricted = owner.querySelector('.locked');
        var values = [visibleLocalizedSubscriptionOffer()];
        action.hidden = true;
        values.push(visibleLocalizedSubscriptionOffer());
        action.hidden = false;
        owner.insertBefore(offer, restricted);
        values.push(visibleLocalizedSubscriptionOffer());
        owner.appendChild(offer);
        values.push(visibleLocalizedSubscriptionOffer());
        offer.firstChild.nodeValue = 'Ordinary published account of subscriptions ';
        values.push(visibleLocalizedSubscriptionOffer());
        offer.firstChild.nodeValue = 'Wybierz prenumeratę, by czytać dalszą część ';
        var heading = document.createElement('h1');
        heading.textContent = 'Another printed title';
        owner.appendChild(heading);
        values.push(visibleLocalizedSubscriptionOffer());
        heading.hidden = true;
        values.push(visibleLocalizedSubscriptionOffer());
        return values;
      JS
      expect(page.evaluate('localizedOfferProbe({})')).to eq([true, false, false, true, false, false, true])
    end
  end
end
