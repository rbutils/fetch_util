# frozen_string_literal: true

RSpec.describe 'FetchUtil localized author route eligibility' do
  include_context 'extractor integration helpers'

  def author_route_probe_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    marker = '})(window);'
    raise 'ambiguous private probe boundary' unless source.scan(marker).length == 1

    source.sub(marker, <<~JAVASCRIPT)
      global.probeAuthorRouteWork = function() {
        var originalStyle = window.getComputedStyle, originalOwnership = articleBylineNode;
        var resourceStyle = 0, resourceOwnership = 0, profileStyle = 0, profileOwnership = 0;
        var before = document.body.innerHTML;
        window.getComputedStyle = function(node) {
          if (node && node.hasAttribute('data-resource')) resourceStyle++;
          if (node && node.hasAttribute('data-profile')) profileStyle++;
          return originalStyle.apply(this, arguments);
        };
        articleBylineNode = function(node) {
          if (node && node.hasAttribute('data-resource')) resourceOwnership++;
          if (node && node.hasAttribute('data-profile')) profileOwnership++;
          return originalOwnership.apply(this, arguments);
        };
        try {
          var author = visibleLocalizedAuthor([document.getElementById('scope')]);
          return {author: author, resourceStyle: resourceStyle, resourceOwnership: resourceOwnership,
            profileStyle: profileStyle, profileOwnership: profileOwnership,
            links: Array.from(document.querySelectorAll('[data-resource]'), function(node) { return [node.textContent, node.href]; }),
            unchanged: before === document.body.innerHTML};
        } finally {
          window.getComputedStyle = originalStyle;
          articleBylineNode = originalOwnership;
        }
      };
      })(window);
    JAVASCRIPT
  end

  it 'rejects unrelated resource routes before visibility and publication ownership work' do
    records = 125.times.map { |index| "<p><a data-resource href='/downloads/item-#{index}.gz'>Complete resource #{index}</a></p>" }.join
    html = "<title>Complete resource catalogue</title><article id='scope'><h1>Complete resource catalogue</h1>#{records}</article>"
    with_url_page('https://publication.example.test/catalogue', html) do |page|
      page.add_script_tag(content: author_route_probe_source)
      value = page.evaluate('probeAuthorRouteWork()')
      expect(value.values_at('author', 'resourceStyle', 'resourceOwnership', 'unchanged')).to eq([nil, 0, 0, true])
      expect(value.fetch('links')).to eq(125.times.map do |index|
        ["Complete resource #{index}", "https://publication.example.test/downloads/item-#{index}.gz"]
      end)
    end
  end

  it 'retains genuine author visibility and ownership checks after each independent source mutation' do
    html = '<article id="scope"><h1>Current report</h1><a id="person" data-profile href="/authors/ari-reader">Ari Reader</a>' \
           '<p>The complete independently authored report stays available beside its visible author.</p></article>'
    with_url_page('https://publication.example.test/reports/current', html) do |page|
      page.add_script_tag(content: author_route_probe_source)
      first = page.evaluate('probeAuthorRouteWork()')
      expect(first.values_at('author', 'unchanged')).to eq(['Ari Reader', true])
      expect(first.fetch('profileStyle')).to be_positive
      expect(first.fetch('profileOwnership')).to be_positive
      page.evaluate("document.getElementById('person').style.display = 'none'")
      expect(page.evaluate('probeAuthorRouteWork()').values_at('author', 'unchanged')).to eq([nil, true])
      page.evaluate("document.getElementById('person').style.display = ''")
      expect(page.evaluate('probeAuthorRouteWork()').values_at('author', 'unchanged')).to eq(['Ari Reader', true])
    end
  end

  it 'still rejects independently owned publication credits and navigation profiles' do
    html = <<~HTML
      <main id="scope"><h1>Publication overview</h1>
        <article><h2><a href="/reports/another">Another independently owned report</a></h2>
          <div class="author"><a data-profile href="/authors/bo-editor">Bo Editor</a></div>
          <p>Complete material belongs to that independently linked report.</p></article>
        <nav><a data-profile href="/authors/cam-writer">Cam Writer</a></nav>
      </main>
    HTML
    with_url_page('https://publication.example.test/overview', html) do |page|
      page.add_script_tag(content: author_route_probe_source)
      value = page.evaluate('probeAuthorRouteWork()')
      expect(value.values_at('author', 'unchanged')).to eq([nil, true])
      expect(value.fetch('profileOwnership')).to be_positive
    end
  end
end
