# frozen_string_literal: true

RSpec.describe 'FetchUtil duplicate record metadata' do
  include_context 'extractor integration helpers'

  def duplicate_metadata_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub(
      '})(window);',
      'global.__mergeDuplicateRecordAuthorContext = mergeDuplicateRecordAuthorContext; })(window);'
    )
  end

  def primary_record(number)
    <<~HTML
      <article class="link-card">
        <a href="/stories/#{number}"><h3>Primary newsroom story #{number}</h3></a>
      </article>
    HTML
  end

  def authored_duplicate(number, author, extra: '')
    slug = author.downcase.tr(' ', '-')
    <<~HTML
      <article class="standard-card">
        <a href="/stories/#{number}"><h3>Primary newsroom story #{number}</h3></a>
        #{extra}
        <span class="byline"><a rel="author" href="/authors/#{slug}">#{author}</a></span>
      </article>
    HTML
  end

  it 'merges only unambiguous locally owned authors from duplicate semantic records' do
    alice = authored_duplicate(1, 'Alice Reporter').sub('</h3></a>', '</h3><span>Breaking</span></a>')
    bob = authored_duplicate(2, 'Bob Reporter')
    carol = authored_duplicate(2, 'Carol Reporter')
    dave = authored_duplicate(3, 'Dave Reporter', extra: '<a href="/sources/wire">Wire source</a>')
    dave_clean = authored_duplicate(3, 'Dave Reporter')
    frank = authored_duplicate(5, 'Frank Reporter').sub('Primary newsroom story 5', 'Different report sharing story 5')
    html = <<~HTML
      <html><head><title>Duplicate record newsroom</title></head><body><main>
        <h1>Duplicate record newsroom</h1>
        <section><h2>Primary desk</h2>#{(1..8).map { |number| primary_record(number) }.join}</section>
        <div class="alternate-layouts">
          #{alice}
          #{bob}
          #{carol}
          #{dave}
          #{dave_clean}
          <article class="standard-card">
            <a href="/stories/4"><h3>Primary newsroom story 4</h3></a>
            <div class="comment-thread"><a rel="author" href="/authors/eve">Eve Commenter</a></div>
          </article>
          #{frank}
          <article class="standard-card">
            <a href="/stories/6"><h3>Primary newsroom story 6</h3></a>
            <span class="byline"><a rel="author" href="/authors/grace">Grace Reporter</a></span>
            <span class="byline"><a rel="author" href="/authors/heidi">Heidi Reporter</a></span>
          </article>
          <table><tr>
            <td><a href="/stories/7"><h5>Primary newsroom story 7</h5></a></td>
            <td><a rel="author" href="/authors/ivan">Ivan Reporter</a></td>
          </tr></table>
          <article class="standard-card">
            <a href="/stories/8"><h3>Primary newsroom story 8</h3></a>
            <span class="byline"><a rel="author" href="/authors/alex-one">Alex Reporter</a></span>
          </article>
          <article class="standard-card">
            <a href="/stories/8"><h3>Primary newsroom story 8</h3></a>
            <span class="byline"><a rel="author" href="/authors/alex-two">Alex Reporter</a></span>
          </article>
        </div>
        <section><h2>Later desk</h2>#{(9..10).map { |number| primary_record(number) }.join}</section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/archive', html, reader_mode: false) do |payload|
      story_lines = payload['markdown'].lines.grep(%r{^- .*?/stories/})
      first_story = story_lines.find { |line| line.include?('/stories/1)') }
      seventh_story = story_lines.find { |line| line.include?('/stories/7)') }

      expect(payload['contentType']).to eq('list')
      expect(first_story).to include('[Alice Reporter](https://newsroom.example/authors/alice-reporter)')
      expect(seventh_story).to include('[Ivan Reporter](https://newsroom.example/authors/ivan)')
      expect(story_lines.join).not_to match(/Bob Reporter|Carol Reporter|Dave Reporter|Eve Commenter|Frank Reporter|Grace Reporter|Heidi Reporter|Alex Reporter/)
      story_numbers = story_lines.map { |line| line[%r{/stories/(\d+)}, 1].to_i }
      expect(story_numbers).to eq((1..10).to_a)
    end
  end

  it 'keeps an author owned by the selected semantic record around its inner story link' do
    html = <<~HTML
      <html><head><title>Local record newsroom</title></head><body><main>
        <h1>Local record newsroom</h1>
        <section>
          <h2>Latest reports</h2>
          <article class="big-card">
            <a class="link-card" href="/stories/1"><h3>Lead investigation from the city desk</h3></a>
            <span class="byline"><a rel="author" href="/authors/judy">Judy Reporter</a></span>
          </article>
          #{(2..8).map { |number| primary_record(number) }.join}
        </section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/archive', html, reader_mode: false) do |payload|
      lead = payload['markdown'].lines.find { |line| line.include?('/stories/1)') }

      expect(payload['contentType']).to eq('list')
      expect(lead).to include('[Judy Reporter](https://newsroom.example/authors/judy)')
      expect(payload['markdown'].scan('Judy Reporter').length).to eq(1)
    end
  end

  it 'does not borrow an author from an outer record around the selected semantic record' do
    html = <<~HTML
      <html><head><title>Nested record newsroom</title></head><body><main>
        <article class="outer-card">
          <h3><a href="/stories/1">Lead investigation from the city desk</a></h3>
          <span class="byline"><a rel="author" href="/authors/wrong">Wrong Reporter</a></span>
          <article class="inner-card">
            <a id="selected-story" href="/stories/1"><h3>Lead investigation from the city desk</h3></a>
          </article>
        </article>
        <article id="flat-outer">
          <div class="selected-card">
            <h3><a id="selected-flat-story" href="/stories/2">Waterfront transit plan clears final review</a></h3>
          </div>
          <div class="unrelated-card">
            <a href="/stories/2">Waterfront transit plan clears final review</a>
            <span class="byline"><a rel="author" href="/authors/wrong-flat">Wrong Flat Reporter</a></span>
          </div>
        </article>
        <article class="selected-card">
          <a id="selected-ad-story" href="/stories/3"><h3>Quarterly transit schedule published for commuters</h3></a>
        </article>
        <article class="ad-slot">
          <a href="/stories/3"><h3>Quarterly transit schedule published for commuters</h3></a>
          <span class="byline"><a rel="author" href="/authors/advertiser">Advertiser Reporter</a></span>
        </article>
        <article class="selected-card">
          <a id="selected-sponsored-story" href="/stories/4"><h3>Local museum opens a new public history wing</h3></a>
        </article>
        <article class="sponsored-card">
          <a href="/stories/4"><h3>Local museum opens a new public history wing</h3></a>
          <span class="byline"><a rel="author" href="/authors/partner">Partner Reporter</a></span>
        </article>
        <nav>
          <a id="selected-nav-story" href="/stories/5">Regional rail authority publishes its annual timetable</a>
        </nav>
        <article>
          <a href="/stories/5"><h3>Regional rail authority publishes its annual timetable</h3></a>
          <span class="byline"><a rel="author" href="/authors/rail">Rail Reporter</a></span>
        </article>
        <article class="ad-slot">
          <a id="selected-ad-target" href="/stories/6">Community theatre announces a winter performance season</a>
        </article>
        <article>
          <a href="/stories/6"><h3>Community theatre announces a winter performance season</h3></a>
          <span class="byline"><a rel="author" href="/authors/theatre">Theatre Reporter</a></span>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://newsroom.example/archive', html) do |page|
      page.add_script_tag(content: duplicate_metadata_source)
      authors = page.evaluate(<<~JAVASCRIPT)
        (function() {
          var link = document.querySelector('#selected-story');
          var flatLink = document.querySelector('#selected-flat-story');
          var adLink = document.querySelector('#selected-ad-story');
          var sponsoredLink = document.querySelector('#selected-sponsored-story');
          var navLink = document.querySelector('#selected-nav-story');
          var adTargetLink = document.querySelector('#selected-ad-target');
          var outer = document.querySelector('.outer-card');
          var items = [
            { text: link.textContent, url: link.href, card: link, sourceNode: link, author: '' },
            { text: link.textContent, url: link.href, card: outer, sourceNode: link, author: '' },
            { text: link.textContent, url: link.href, card: outer, sourceNode: null, author: '' },
            { text: flatLink.textContent, url: flatLink.href, card: flatLink, sourceNode: flatLink, author: '' },
            { text: adLink.textContent, url: adLink.href, card: adLink, sourceNode: adLink, author: '' },
            { text: sponsoredLink.textContent, url: sponsoredLink.href, card: sponsoredLink, sourceNode: sponsoredLink, author: '' },
            { text: navLink.textContent, url: navLink.href, card: navLink, sourceNode: navLink, author: '' },
            { text: adTargetLink.textContent, url: adTargetLink.href, card: adTargetLink, sourceNode: adTargetLink, author: '' }
          ];
          window.__mergeDuplicateRecordAuthorContext(document.querySelector('main'), items);
          return items.map(function(item) { return item.author || ''; });
        })()
      JAVASCRIPT

      expect(authors).to eq([
        '', '', '', '', '',
        '[Partner Reporter](https://newsroom.example/authors/partner)',
        '', ''
      ])
    end
  end

  it 'resolves equivalent byline renderings without crossing nested ad or author identities' do
    html = <<~HTML
      <html><head><title>Duplicate byline newsroom</title></head><body><main>
        <article class="selected-card">
          <a id="selected-equivalent" href="/stories/equivalent"><h3>City council approves the waterfront transit plan</h3></a>
        </article>
        <article>
          <a href="/stories/equivalent"><h3>City council approves the waterfront transit plan</h3></a>
          <span class="byline">Casey Reporter</span>
        </article>
        <article>
          <a href="/stories/equivalent"><h3>City council approves the waterfront transit plan</h3></a>
          <span class="byline"><a rel="author" href="/authors/casey">Casey Reporter</a></span>
        </article>

        <article class="selected-card">
          <a id="selected-conflict" href="/stories/conflict"><h3>Regional authority publishes the annual rail timetable</h3></a>
        </article>
        <article>
          <a href="/stories/conflict"><h3>Regional authority publishes the annual rail timetable</h3></a>
          <span class="byline"><a rel="author" href="/authors/alex-one">Alex Reporter</a></span>
        </article>
        <article>
          <a href="/stories/conflict"><h3>Regional authority publishes the annual rail timetable</h3></a>
          <span class="byline"><a rel="author" href="/authors/alex-two">Alex Reporter</a></span>
        </article>

        <article class="selected-card">
          <a id="selected-nested-ad" href="/stories/nested-ad"><h3>Community theatre announces its winter performance season</h3></a>
        </article>
        <article>
          <a href="/stories/nested-ad"><h3>Community theatre announces its winter performance season</h3></a>
          <div class="ad-slot">
            <span class="byline"><a rel="author" href="/authors/advertiser">Advertiser Reporter</a></span>
          </div>
        </article>

        <article class="selected-card">
          <header><a id="selected-local-header" href="/stories/local-header"><h3>Public library opens its renovated reading room</h3></a></header>
        </article>
        <article>
          <header>
            <a href="/stories/local-header"><h3>Public library opens its renovated reading room</h3></a>
            <span class="byline"><a rel="author" href="/authors/library">Library Reporter</a></span>
          </header>
        </article>

        <article class="selected-card">
          <a id="selected-navigation-header" href="/stories/navigation-header"><h3>Transit agency releases its updated rider guide</h3></a>
        </article>
        <article>
          <header role="navigation">
            <a href="/stories/navigation-header"><h3>Transit agency releases its updated rider guide</h3></a>
            <span class="byline"><a rel="author" href="/authors/navigation">Navigation Reporter</a></span>
          </header>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://newsroom.example/archive', html) do |page|
      page.add_script_tag(content: duplicate_metadata_source)
      authors = page.evaluate(<<~JAVASCRIPT)
        (function() {
          var links = ['#selected-equivalent', '#selected-conflict', '#selected-nested-ad', '#selected-local-header', '#selected-navigation-header'].map(function(selector) {
            return document.querySelector(selector);
          });
          var items = links.map(function(link) {
            return { text: link.textContent, url: link.href, card: link, sourceNode: link, author: '' };
          });
          window.__mergeDuplicateRecordAuthorContext(document.querySelector('main'), items);
          return items.map(function(item) { return item.author || ''; });
        })()
      JAVASCRIPT

      expect(authors).to eq([
        '[Casey Reporter](https://newsroom.example/authors/casey)',
        '', '',
        '[Library Reporter](https://newsroom.example/authors/library)',
        ''
      ])
    end
  end
end
