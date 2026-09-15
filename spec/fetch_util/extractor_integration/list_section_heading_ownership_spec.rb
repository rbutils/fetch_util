# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor list section heading ownership' do
  include_context 'extractor integration helpers'

  def section_heading_record(number)
    <<~HTML
      <article>
        <h3><a href="/stories/#{number}">Independent newsroom story #{number}</a></h3>
        <p>Locally owned summary for newsroom story #{number}.</p>
      </article>
    HTML
  end

  def inject_section_coverage_test_api(page)
    source_root = File.expand_path('../../../websieve', __dir__)
    entries = File.readlines(File.join(source_root, 'manifest.txt'), chomp: true)
                  .map(&:strip)
                  .reject { |entry| entry.empty? || entry.start_with?('#') }
    outro = entries.pop
    source = entries.map { |entry| File.read(File.join(source_root, entry)) }
    source << <<~JAVASCRIPT
      window.FetchUtilSectionCoverageTest = {
        supplementalCoverage: supplementalSameRootSectionCoverage,
        normalizeText: normalizeText,
        canonicalKey: listCanonicalKey
      };
    JAVASCRIPT
    source << File.read(File.join(source_root, outro))
    page.evaluate("#{source.join("\n")}\ntrue")
  end

  it 'keeps collection headings through flat coverage without promoting record titles' do
    extra_records = (6..11).map do |number|
      "<li><a href=\"/stories/#{number}\">Independent newsroom story #{number}</a></li>"
    end.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        <section id="lead-record">#{section_heading_record(1)}</section>
        <section id="local-desk">
          <h2><a href="/topics/local">Local desk</a></h2>
          #{section_heading_record(2)}
          #{section_heading_record(3)}
        </section>
        <section id="culture-desk">
          <a href="/topics/culture"><h2>Culture desk</h2></a>
          #{section_heading_record(4)}
          #{section_heading_record(5)}
        </section>
        <ul>#{extra_records}</ul>
      </main></body></html>
    HTML

    with_url_page('https://newsroom.example/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)
      markdown = payload['markdown']
      expected_headings = [
        '## [Local desk](https://newsroom.example/topics/local)',
        '## [Culture desk](https://newsroom.example/topics/culture)'
      ]

      expect(payload['contentType']).to eq('list')
      expect(markdown.scan(/^## .+$/)).to eq(expected_headings)
      expect(markdown.scan('](https://newsroom.example/topics/local)').length).to eq(1)
      expect(markdown.scan('](https://newsroom.example/topics/culture)').length).to eq(1)
      expect(markdown).not_to include('## Independent newsroom story 1')
      story_positions = (1..11).map { |number| markdown.index("/stories/#{number}") }
      expect(story_positions).to eq(story_positions.sort)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'renders a distinct record alias as a record instead of a section heading' do
    html = <<~HTML
      <html><head><title>Alias newsroom</title></head><body><main>
        <h1>Alias newsroom</h1>
        <section><h2>Local desk</h2>#{section_heading_record(1)}#{section_heading_record(2)}</section>
        <section><h2>Culture desk</h2>#{section_heading_record(3)}#{section_heading_record(4)}</section>
        <section><article><h3><a href="/stories/2">Alternate visible angle on newsroom story 2</a></h3></article></section>
        <ul>
          <li><a href="/stories/5">Independent newsroom story 5</a></li>
          <li><a href="/stories/6">Independent newsroom story 6</a></li>
          <li><a href="/stories/7">Independent newsroom story 7</a></li>
          <li><a href="/stories/8">Independent newsroom story 8</a></li>
          <li><a href="/stories/9">Independent newsroom story 9</a></li>
        </ul>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['markdown']).to include(
        '- [Alternate visible angle on newsroom story 2](https://newsroom.example/stories/2)'
      )
      expect(payload['markdown']).not_to include('## Alternate visible angle on newsroom story 2')
    end
  end

  it 'supplements a section alias with its distinct authored lead record' do
    lead_records = (1..4).map do |number|
      if number == 1
        <<~HTML
          <article>
            <h3><a href="/stories/shared">Full authored account of the shared public story</a></h3>
            <a rel="author" href="/reporters/lead">Lead Reporter</a>
          </article>
        HTML
      else
        section_heading_record("lead-#{number}")
      end
    end.join
    local_records = (1..4).map do |number|
      if number == 1
        <<~HTML
          <article>
            <h3><a href="/stories/shared">Short section angle on the shared story</a></h3>
          </article>
        HTML
      else
        section_heading_record("local-#{number}")
      end
    end.join
    culture_records = (1..4).map { |number| section_heading_record("culture-#{number}") }.join
    html = <<~HTML
      <html><head><title>Supplemented newsroom</title></head><body><main>
        <h1>Supplemented newsroom</h1>
        <div class="lead-grid">#{lead_records}</div>
        <section><h2>Local desk</h2>#{local_records}</section>
        <section><h2>Culture desk</h2>#{culture_records}</section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      markdown = payload['markdown']
      full_record = '- [Full authored account of the shared public story](https://newsroom.example/stories/shared)'
      section_alias = '- [Short section angle on the shared story](https://newsroom.example/stories/shared)'

      expect(payload['contentType']).to eq('list')
      expect(markdown).to include(full_record, section_alias)
      expect(markdown.scan('](https://newsroom.example/reporters/lead)').length).to eq(1)
      expect(markdown.index(full_record)).to be < markdown.index('## Local desk')
      expect(markdown.index('## Local desk')).to be < markdown.index(section_alias)
    end
  end

  it 'places a section heading at its own alias when an earlier record shares the canonical URL' do
    html = <<~HTML
      <html><head><title>Alias placement newsroom</title></head><body><main>
        <article id="lead"><h3><a href="/stories/shared">Full authored account</a></h3></article>
        <section id="desk">
          <h2 id="desk-heading">Local desk</h2>
          <article id="alias"><h3><a href="/stories/shared">Short section angle</a></h3></article>
          <article id="other"><h3><a href="/stories/other">Other local report</a></h3></article>
        </section>
      </main></body></html>
    HTML

    with_url_page('https://newsroom.example/', html) do |page|
      inject_section_coverage_test_api(page)
      placement = page.evaluate(<<~JAVASCRIPT)
        (function() {
          var api = window.FetchUtilSectionCoverageTest;
          var root = document.querySelector("main");
          var item = function(id, author) {
            var card = document.getElementById(id);
            var link = card.querySelector("a[href]");
            return {
              text: api.normalizeText(link.textContent),
              url: link.href,
              dedupeKey: api.canonicalKey(link.href),
              card: card,
              sourceNode: link,
              author: author || null
            };
          };
          var lead = item("lead", "[Lead Reporter](https://newsroom.example/reporters/lead)");
          var alias = item("alias");
          var other = item("other");
          var region = {
            node: document.getElementById("desk"),
            headingNode: document.getElementById("desk-heading"),
            label: "Local desk",
            cards: [alias, other]
          };
          var result = api.supplementalCoverage(
            { items: [alias, other], regions: [region] },
            [lead, alias, other],
            [],
            root,
            []
          );
          return {
            aliasIndex: result.items.indexOf(alias),
            headingIndexes: Object.keys(result.headings).map(Number)
          };
        })()
      JAVASCRIPT

      expect(placement['headingIndexes']).to eq([placement['aliasIndex']])
    end
  end

  it 'keeps a named linked collection title out of a broad record owner' do
    stories = (1..10).map do |number|
      <<~HTML
        <article class="StandardCard_standardCard__fixture">
          <h3><a href="/stories/#{number}">Independent collection report #{number}</a></h3>
          <p>Local summary for report #{number}.</p>
        </article>
      HTML
    end
    html = <<~HTML
      <html><head><title>Collection boundary newsroom</title></head><body><main>
        <h1>Collection boundary newsroom</h1>
        <div class="PageGroup_left__fixture">
          <section class="StandardLeftFeed_StandardLeftFeedContainer__fixture">
            <div class="StandardLeftFeed_StandardLeftFeedItems__fixture">#{stories.first(4).join}</div>
          </section>
          <section class="StandardLeftFeed_StandardLeftFeedContainer__fixture">
            <div class="StandardLeftFeed_StandardLeftFeedItems__fixture">#{stories[4..7].join}</div>
          </section>
          <h2 class="SectionTitle_title__fixture">
            <a class="SectionTitle_titleText__fixture" href="/tools/training">Training desk</a>
          </h2>
          <div class="GamesWidget_containerBottom__fixture">#{stories.last(2).join}</div>
        </div>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('## [Training desk](https://newsroom.example/tools/training)')
      expect(payload['markdown']).not_to include('- [Training desk]', 'Training desk - Independent collection report')
      expect((1..10).map { |number| payload['markdown'].index("/stories/#{number}") }).to all(be_a(Integer))
    end
  end

  it 'keeps one-link semantic cards independent from a broader feed owner' do
    sparse_records = (2..10).map do |number|
      metadata = if number == 2
                   ''
                 else
                   controls = if number == 3
                                <<~HTML
                                  <div class="comment-thread">
                                    <a class="comment-author" href="/commenter-3">Commenter</a>
                                  </div>
                                  <div class="commenter">
                                    <a rel="author" href="/nested-commenter-3">Nested commenter</a>
                                  </div>
                                  <a class="authoring-layout" href="/guide-3">Guide</a>
                                HTML
                              else
                                ''
                              end
                   author_attributes = case number
                                       when 4
                                         'class="commentary-card" data-author'
                                       when 5
                                         'class="AuthorItem_authorLink__fixture"'
                                       when 3
                                         'class="AuthorItem_authorLink__fixture reply-policy" rel="author"'
                                       else
                                         'class="AuthorItem_authorLink__fixture" rel="author"'
                                       end
                   <<~HTML
                     <span class="story-category">Desk #{number}</span>
                     #{controls}
                     <a #{author_attributes} href="/reporters/#{number}">
                       Reporter Person #{number}
                     </a>
                   HTML
                 end
      <<~HTML
        <article class="StandardCard_standardCard__fixture StandardCard_standardCardStandardLeftFeed__fixture">
          <a class="Common_sectionLink__fixture" href="/stories/#{number}">
            <img src="/images/#{number}.jpg" alt="">
            <h3 class="TitleWrapper_titleWrapper__fixture Common_standardCardTitle__fixture">
              Independent newsroom story #{number}
            </h3>
          </a>
          #{metadata}
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Semantic card newsroom</title></head><body><main>
        <h1>Semantic card newsroom</h1>
        <div class="StandardLeftFeed_StandardLeftFeedItems__fixture">
          #{section_heading_record(1)}
          #{sparse_records}
        </div>
        <section>
          <h2>Local desk</h2>
          #{section_heading_record(11)}
          #{section_heading_record(12)}
        </section>
        <section>
          <h2>Culture desk</h2>
          #{section_heading_record(13)}
          #{section_heading_record(14)}
        </section>
        <section>
          <h2>Contributors</h2>
          <article class="profile-card">
            <h3>
              <a class="AuthorItem_authorLink__fixture" rel="author" href="/contributors/editor">
                Profile of Editor Name
              </a>
            </h3>
            <p>Independent contributor profile.</p>
          </article>
        </section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      (1..14).each do |number|
        expect(payload['markdown']).to include(
          "- [Independent newsroom story #{number}](https://newsroom.example/stories/#{number})"
        )
      end
      expect(payload['markdown']).not_to include('## Independent newsroom story 2')
      expect(payload['markdown']).not_to match(/^- \[Reporter Person \d+\]/)
      expect(payload['markdown']).to match(
        %r{^- \[Independent newsroom story 3\].*\[Reporter Person 3\]\(https://newsroom\.example/reporters/3\)}
      )
      story_line = payload['markdown'].lines.find { |line| line.include?('/stories/3') }
      expect(payload['markdown']).not_to include('[Commenter](https://newsroom.example/commenter-3)')
      expect(payload['markdown']).not_to include('[Nested commenter](https://newsroom.example/nested-commenter-3)')
      expect(story_line).to include('[Guide](https://newsroom.example/guide-3)')
      expect(story_line.index('[Reporter Person 3]')).to be < story_line.index('[Guide]')
      expect(payload['markdown']).to match(
        %r{^- \[Independent newsroom story 4\].*\[Reporter Person 4\]\(https://newsroom\.example/reporters/4\)}
      )
      expect(payload['markdown']).to match(
        %r{^- \[Independent newsroom story 5\].*\[Reporter Person 5\]\(https://newsroom\.example/reporters/5\)}
      )
      expect(payload['markdown']).to include(
        '- [Profile of Editor Name](https://newsroom.example/contributors/editor)'
      )
      expect(payload['markdown']).to include('Independent contributor profile.')
      positions = (1..14).map { |number| payload['markdown'].index("/stories/#{number}") }
      expect(positions).to eq(positions.sort)
    end
  end
end
