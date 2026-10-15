# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Homepage feed assessment eligibility' do
  include_context 'extractor integration helpers'

  def feed_assessment_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.homepageFeedProbe = function(contents, markdown) {
        var reads = 0, original = homepageHasEditorialSections;
        homepageHasEditorialSections = function(root) { reads++; return original(root); };
        try {
          return {results: contents.map(function(content) {
            return credibleHomepageListFeed(content, markdown, 'Complete published evidence.', 'Complete published evidence.');
          }), reads: reads};
        } finally {
          homepageHasEditorialSections = original;
        }
      };
      })(window);
    JS
  end

  it 'does no source-wide editorial assessment for ordinary articles or ineligible feeds' do
    sections = (1..240).map do |number|
      "<section><h2>Published section #{number}</h2><p>Complete authored evidence #{number} remains available.</p>" \
        "<ul><li><a href='/record/#{number}'>Published reference #{number}</a></li></ul></section>"
    end.join
    html = "<article><h1>Published reference manual</h1>#{sections}</article>"
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: feed_assessment_probe)
      contents = Array.new(240) { { contentType: 'article' } }
      contents.concat([{ contentType: 'medical' }, { contentType: 'product' }, { contentType: 'search' },
                       { contentType: 'social', socialKind: 'post', hostAware: true },
                       { contentType: 'social', socialKind: 'feed' }])
      result = page.evaluate("homepageFeedProbe(#{JSON.generate(contents)}, '')")
      expect(result).to eq('results' => Array.new(contents.length, false), 'reads' => 0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains eligible collection and published-feed decisions and observes changed source sections' do
    sections = (1..2).map do |number|
      "<section><h2>Published collection #{number}</h2><ul><li><a href='/record/#{number}'>Independent report #{number}</a></li></ul></section>"
    end.join
    with_url_page('https://publication.example.test/news', "<main>#{sections}</main>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: feed_assessment_probe)
      contents = [{ contentType: 'list' },
                  { contentType: 'social', socialKind: 'feed', hostAware: true, itemCount: 3 },
                  { contentType: 'social', socialKind: 'feed', structuralSocialFeed: true, itemCount: 3 },
                  { contentType: 'social', socialKind: 'feed', hostAware: true, itemCount: 2 }]
      markdown = (1..3).map { |number| "[Published report #{number}](https://publication.example.test/record/#{number})" }.join("\n")
      result = page.evaluate("homepageFeedProbe(#{JSON.generate(contents)}, #{JSON.generate(markdown)})")
      expect(result).to eq('results' => [true, true, true, false], 'reads' => 1)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      page.evaluate("document.querySelector('main').innerHTML = '<p>Complete independent reporting.</p>'")
      changed = page.evaluate("homepageFeedProbe(#{JSON.generate(contents)}, #{JSON.generate(markdown)})")
      expect(changed).to eq('results' => [false, true, true, false], 'reads' => 1)
    end
  end
end
