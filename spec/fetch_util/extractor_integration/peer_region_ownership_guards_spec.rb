# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Physical peer-region fallback ownership' do
  include_context 'extractor integration helpers'

  def peer_ownership_page
    <<~HTML
      <html><head><title>Independent publication</title></head><body><main id="publication">
        <section id="first-region"><h2>Regional accounts</h2>
          <a href="/first?edition=2&amp;view=full#details"><h3>First independently owned account</h3>
          <p>First independently owned account retains its complete authored explanation.</p>
          <pre><code>first_value

      last_value</code></pre></a></section>
        <section id="second-region"><h2>International accounts</h2>
          <a href="/second?edition=3&amp;view=full#details"><h4>Second independently owned account</h4>
          <p>Second independently owned account retains its complete authored explanation.</p></a></section>
      </main></body></html>
    HTML
  end

  def peer_ownership_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.peerOwnershipProbe = function(change) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var main = document.querySelector('main');
            if (change === 'two-mains') document.body.appendChild(main.cloneNode(true));
            if (change === 'navigation-owner') main.setAttribute('role', 'navigation');
            if (change === 'interface-owner') main.setAttribute('role', 'dialog');
            if (change === 'unowned-prose') main.appendChild(document.createTextNode('Independent main context'));
            if (change === 'section-prose') main.firstElementChild.appendChild(document.createTextNode('Unowned section context'));
            if (change === 'hidden-region') main.lastElementChild.hidden = true;
            if (change === 'no-region-heading') main.lastElementChild.querySelector('h2').remove();
            if (change === 'current-page-record') main.querySelector('a').setAttribute('href', '#local');
            if (change === 'button-record') main.querySelector('a').setAttribute('role', 'button');
            if (change === 'independent-equal-url') main.querySelectorAll('a')[1].href = main.querySelector('a').href;
            var before = document.body.outerHTML;
            var primaryRoot = document.createElement('div');
            primaryRoot.innerHTML = main.querySelector('a').innerHTML;
            var fallbackRoot = document.createElement('div');
            fallbackRoot.innerHTML = main.outerHTML;
            var primary = {contentType: 'article', html: primaryRoot.innerHTML};
            var fallback = {contentType: 'article', html: fallbackRoot.innerHTML};
            if (change === 'focal-primary') primary.sourceOwnedFocalArticle = true;
            if (change === 'focal-fallback') fallback.sourceOwnedFocalArticle = true;
            if (change === 'partial-primary') primaryRoot.querySelector('p').remove();
            if (change === 'merged-primary') primaryRoot.innerHTML += main.querySelectorAll('a')[1].innerHTML;
            if (change === 'missing-region') fallbackRoot.querySelector('section:last-child').remove();
            if (change === 'reversed-regions') fallbackRoot.querySelector('main').prepend(fallbackRoot.querySelector('section:last-child'));
            if (change === 'changed-destination') fallbackRoot.querySelector('a').setAttribute('href', '/different?edition=2#details');
            if (change === 'lost-fragment') fallbackRoot.querySelector('a').setAttribute('href', '/first?edition=2&view=full');
            if (change === 'lost-target') fallbackRoot.querySelector('section').removeAttribute('id');
            if (change === 'changed-program') fallbackRoot.querySelector('code').textContent = 'first_value last_value';
            if (change === 'changed-heading') fallbackRoot.querySelector('h3').outerHTML = '<p>First independently owned account</p>';
            var result = sourceOwnedPeerRegionSections(primary, fallback, primaryRoot, fallbackRoot);
            return {accepted: result, sourceUnchanged: document.body.outerHTML === before};
          })({});
        })({});
      };
      })(window);
    JS
  end

  def check_peer_ownership(change, accepted:)
    with_url_page('https://publication.example.test/', peer_ownership_page) do |page|
      page.add_script_tag(content: peer_ownership_probe)
      expect(page.evaluate("peerOwnershipProbe(#{change.to_json})")).to eq('accepted' => accepted, 'sourceUnchanged' => true)
    end
  end

  it 'accepts only complete source-owned candidates, including independent equal destinations' do
    check_peer_ownership('complete', accepted: true)
    check_peer_ownership('independent-equal-url', accepted: true)
  end

  it 'rejects ambiguous ownership, interfaces, incomplete material and changed physical roles' do
    %w[two-mains navigation-owner interface-owner unowned-prose section-prose hidden-region no-region-heading
       current-page-record button-record focal-primary focal-fallback partial-primary merged-primary missing-region
       reversed-regions changed-destination lost-fragment lost-target changed-program changed-heading].each do |change|
      check_peer_ownership(change, accepted: false)
    end
  end
end
