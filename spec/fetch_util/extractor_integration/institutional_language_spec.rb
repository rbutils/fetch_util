require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Institutional language markup ownership' do
  include_context 'extractor integration helpers'

  def language_page
    <<~HTML
      <!doctype html><html lang="de"><head>
      <title>Public culture guide</title><meta name="Generator" content="Drupal 11">
      </head><body><main><article><div class="field--name-field-paragraphs">
      <h1>Public culture guide</h1>
      <h2>Regional <span lang="en" class="a11y-language">Highlights</span></h2>
      <p>The independent published guide describes the complete public collection,
      including <span lang="en" class="a11y-language">Community Outreach</span>
      and the resources available to every visitor throughout the year.</p>
      <h3><span lang="en" class="a11y-language">Public</span>
      <span lang="en" class="a11y-language">Program</span> for everyone</h3>
      <p class="language-editorial">This authored language paragraph explains the
      collection and retains its <a href="https://culture.example.test/reference">source reference</a>.</p>
      <div class="language-switcher"><a href="/de/guide" hreflang="de">Deutsch</a>
      <a href="/en/guide" hreflang="en">English</a></div>
      <p><span class="a11y-language" lang="fr" style="display:none">Secret translation</span>
      The final published paragraph contains substantive information about visiting
      the collection and consulting its complete independent reference material.</p>
      <pre><code>&lt;span class="language-example" lang="fr"&gt;Literal example&lt;/span&gt;</code></pre>
      </div></article></main></body></html>
    HTML
  end

  it 'retains complete visible language-marked headings, prose and literal code' do
    with_url_page('https://culture.example.test/guide', language_page) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      html = Nokogiri::HTML5.fragment(payload.fetch('html'))

      expect(html.css('h2,h3').map { |node| node.text.gsub(/\s+/, ' ').strip })
        .to include('Regional Highlights', 'Public Program for everyone')
      expect(html.text).to include('Community Outreach', 'This authored language paragraph')
      expect(payload.fetch('markdown')).to include('Regional Highlights', 'Public Program', 'Community Outreach')
      expect(html.css('a[href]').map { |node| node['href'] }).to include('https://culture.example.test/reference')
      expect(html.css('pre').map(&:text)).to include('<span class="language-example" lang="fr">Literal example</span>')
      expect(payload.fetch('markdown')).to include('<span class="language-example" lang="fr">Literal example</span>')
      expect(html.text).not_to include('Secret translation', 'Deutsch', 'English')
      expect(payload.fetch('markdown')).not_to include('Secret translation', 'Deutsch', 'English')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete linked-card headings, destinations and prose in lists' do
    cards = 6.times.map do |index|
      <<~HTML
        <li><a href="https://culture.example.test/visit?location[]=#{index}">
        <h3>Resource #{index} <span lang="en" class="a11y-language">Highlights</span></h3>
        <p>Complete independent collection information for resource #{index}, with every published detail retained.</p>
        <div>Collection hall</div>
        </a></li>
      HTML
    end.join
    html = language_page.sub('</div></article>', "<ul>#{cards}</ul></div></article>")
    with_url_page('https://culture.example.test/guide', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      document = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = payload.fetch('markdown')

      expect(document.css('li > a[href] > h3').length).to eq(6)
      6.times do |index|
        expect(markdown).to include("[Resource #{index} Highlights](https://culture.example.test/visit?location[]=#{index})")
        expect(markdown).to include("Complete independent collection information for resource #{index}, with every published detail retained.")
      end
      expect(markdown).to match(/^[*+-] {1,4}### \[Resource 0 Highlights\]/)
      expect(markdown.scan('Collection hall').length).to eq(6)
      expect(markdown).to include('<span class="language-example" lang="fr">Literal example</span>')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  def language_navigation_probe
    directory = File.expand_path('../../../websieve', __dir__)
    script = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |line| File.read(File.join(directory, line)) }.join("\n")
    raise 'unexpected extraction boundary' unless script.scan('})(window);').length == 1

    script.sub('})(window);', <<~JS)
      global.languageNavigationProof = function(html) {
        var holder = document.createElement('div');
        holder.innerHTML = html;
        return drupalLanguageNavigation(holder.querySelector('[class*="language"]'));
      };
      })(window);
    JS
  end

  it 'keeps already-cleaned visitor references and standalone images readable' do
    media = <<~HTML
      <a class="button" tabindex="-1" href="https://culture.example.test/tickets?location[]=1"><span>Reserve source tickets</span></a>
      <div>
             <picture>
             <source srcset="https://culture.example.test/collection-large.png" media="(min-width: 1200px)">
             <img src="https://culture.example.test/collection.png" alt="Collection overview">
             </picture>
      </div>
      <pre><code>![Collection overview](https://culture.example.test/collection.png)</code></pre>
    HTML
    html = language_page.sub('</div></article>', "#{media}</div></article>")
    with_url_page('https://culture.example.test/guide', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(markdown).to include('[Reserve source tickets](https://culture.example.test/tickets?location[]=1)')
      expect(markdown).to match(%r{^ {0,3}!\[Collection overview\]\(https://culture\.example\.test/collection\.png\)})
      expect(markdown).to include("```\n![Collection overview](https://culture.example.test/collection.png)\n```")
      expect(markdown).to include('<span class="language-example" lang="fr">Literal example</span>')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'requires navigation or complete language choices without authored context' do
    with_url_page('https://culture.example.test/guide', language_page) do |page|
      page.evaluate(language_navigation_probe)
      choices = '<a href="/en/guide" hreflang="en">English</a><a href="/fr/guide" hreflang="fr">French</a>'
      positive = [
        "<div class=language-choices>#{choices}</div>",
        '<nav class=language-menu><a href="/en/guide">English</a></nav>',
        '<select class=language-control><option>English</option><option>French</option></select>'
      ]
      negative = [
        '<span lang=en class=a11y-language>Public program</span>',
        "<p class=language-reference>#{choices}</p>",
        "<div class=language-reference><p>Published information remains authored material.</p>#{choices}</div>",
        "<nav class=language-reference><h2>Published collection</h2>#{choices}</nav>",
        "<div class=language-reference>Independent source explanation.#{choices}</div>",
        '<pre><select class=language-example><option>Literal source</option></select></pre>',
        '<div class=language-reference><a href="/en/guide" hreflang="en">First</a><a href="/en/other" hreflang="en">Second</a></div>'
      ]
      positive.each { |html| expect(page.evaluate('window.languageNavigationProof(arguments[0])', html)).to be(true), html }
      negative.each { |html| expect(page.evaluate('window.languageNavigationProof(arguments[0])', html)).to be(false), html }
    end
  end
end
