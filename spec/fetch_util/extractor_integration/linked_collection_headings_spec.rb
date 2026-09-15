# frozen_string_literal: true

RSpec.describe 'FetchUtil linked collection heading boundaries' do
  include_context 'extractor integration helpers'

  def collection_heading_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub(
      '})(window);',
      'global.__linkedCollectionHeading = genericLinkedCollectionHeading; })(window);'
    )
  end

  def collection_record(number)
    <<~HTML
      <article>
        <h3><a href="/stories/#{number}"><img src="/images/#{number}.jpg" alt="Story #{number}">Independent story #{number}</a></h3>
      </article>
    HTML
  end

  def collection_heading_fixture
    <<~HTML
      <!doctype html>
      <html><head><title>Collection boundary newsroom</title></head><body><main>
        <div id="owner" class="PageGroup_left__fixture">
          #{collection_record(1)}#{collection_record(2)}
          <h2 class="SectionTitle_title__fixture"><a id="collection" href="/tools/training">Training desk</a></h2>
        </div>
        <div id="single-owner" class="PageGroup_left__fixture">
          #{collection_record(3)}
          <h2 class="SectionTitle_title__fixture"><a id="single" href="/tools/single">Single desk</a></h2>
        </div>
        <div id="unnamed-owner" class="PageGroup_left__fixture">
          #{collection_record(4)}#{collection_record(5)}
          <h2><a id="unnamed" href="/tools/general">General desk</a></h2>
        </div>
        <article id="article-owner">
          <h2 class="SectionTitle_title__fixture"><a id="article-title" href="/stories/6">Article title</a></h2>
          #{collection_record(7)}#{collection_record(8)}
        </article>
        <div id="navigation-record-owner" class="PageGroup_left__fixture">
          <nav><ul>
            <li><h3><a href="/nav/1"><img src="/images/nav-1.jpg" alt="Navigation one">Navigation one</a></h3></li>
            <li><h3><a href="/nav/2"><img src="/images/nav-2.jpg" alt="Navigation two">Navigation two</a></h3></li>
          </ul></nav>
          <h2 class="SectionTitle_title__fixture"><a id="navigation-records" href="/tools/navigation">Navigation desk</a></h2>
        </div>
        <div id="navigation-heading-owner" class="PageGroup_left__fixture">
          #{collection_record(9)}#{collection_record(10)}
          <nav><h2 class="SectionTitle_title__fixture"><a id="navigation-heading" href="/tools/nav-heading">Navigation heading</a></h2></nav>
        </div>
        <div id="alias-owner" class="PageGroup_left__fixture">
          #{collection_record(11)}#{collection_record(12)}
          <h2><a id="alias" class="category-heading" href="/topics/reports">Reports category</a></h2>
        </div>
      </main></body></html>
    HTML
  end

  it 'requires independent content records and explicit non-navigation title evidence' do
    with_url_page('https://news.example.com/', collection_heading_fixture) do |page|
      page.add_script_tag(content: collection_heading_source)
      decisions = page.evaluate(<<~JAVASCRIPT)
        [
          ['#collection', '#owner'], ['#single', '#single-owner'], ['#unnamed', '#unnamed-owner'],
          ['#article-title', '#article-owner'], ['#navigation-records', '#navigation-record-owner'],
          ['#navigation-heading', '#navigation-heading-owner'], ['#alias', '#alias-owner']
        ].map(function(pair) {
          return window.__linkedCollectionHeading(document.querySelector(pair[0]), document.querySelector(pair[1]));
        });
      JAVASCRIPT

      expect(decisions).to eq([true, false, false, false, false, false, true])
    end
  end

  it 'does not treat the same structure as a collection title on a non-homepage path' do
    with_url_page('https://news.example.com/archive', collection_heading_fixture) do |page|
      page.add_script_tag(content: collection_heading_source)
      decision = page.evaluate(<<~JAVASCRIPT)
        window.__linkedCollectionHeading(document.querySelector('#collection'), document.querySelector('#owner'));
      JAVASCRIPT

      expect(decision).to be(false)
    end
  end
end
