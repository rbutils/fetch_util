# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Adjacent source-owned article headings' do
  include_context 'extractor integration helpers'

  let(:short_title) { 'Funding changes for the regional transport network' }
  let(:full_title) { 'Funding changes for the regional transport network: “The next phase will reach every district in 2027”' }
  let(:body) do
    <<~HTML
      <p>The ministry outlined its next phase of funding for the regional transport network, with details on the new routes, timetable, and stations for residents.</p>
      <p>Officials said the next phase will reach every district in 2027, following a year of infrastructure work across the network.</p>
      <p>The announced programme also covers maintenance, safety checks, accessibility upgrades, and publication of progress for the communities affected.</p>
    HTML
  end

  it 'uses a fuller adjacent heading only when the article itself corroborates its missing text' do
    html = <<~HTML
      <html><head><title>#{short_title}</title></head><body>
        <header><h1>#{full_title}</h1></header>
        <article>#{body}</article>
      </body></html>
    HTML

    with_url_page('https://publisher.example/stories/transport-funding', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq(full_title)
      expect(payload['markdown']).to start_with("# #{full_title}")
      expect(payload['markdown']).to include('The announced programme also covers maintenance')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not promote an invisible adjacent heading even when its words appear in the article' do
    html = <<~HTML
      <html><head><title>#{short_title}</title></head><body>
        <header><h1 hidden>#{full_title}</h1></header>
        <article>#{body}</article>
      </body></html>
    HTML

    with_url_page('https://publisher.example/stories/transport-funding', html) do |page|
      payload = extract_payload(page)
      expect(payload['title']).to eq(short_title)
    end
  end

  it 'uses a unique self-linked article headline instead of an unrelated blog suffix' do
    headline = 'Local researchers publish complete transport funding records for every district'
    html = <<~HTML
      <html><head><title>#{headline} | Author journal and notebook</title></head><body><main>
        <article>
          <h1><a href="/reports/funding-records">#{headline}</a></h1>
          <p>The first section explains where the public funding originated and how the regional transport team checked the submitted documents.</p>
          <p>The published records also name each district, the expected completion dates, and the public consultation held before decisions were made.</p>
          <p>Readers can review the complete report and compare the independent measurements with the ministry's own published timetable.</p>
        </article>
      </main></body></html>
    HTML

    extract_from_url('https://journal.example/reports/funding-records', html) do |payload|
      expect(payload['title']).to eq(headline)
      expect(payload['markdown']).to include('each district', 'independent measurements')
    end
  end

  it 'renders a uniquely owned self-linked reader headline as the page title' do
    headline = 'Researchers publish complete transport evidence and public records for every district'
    html = <<~HTML
      <html><head><title>#{headline} | Author journal</title></head><body><main><article>
        <h1><a href="/reports/funding-records">#{headline}</a></h1>
        #{body}
      </article></main></body></html>
    HTML

    with_url_page('https://journal.example/reports/funding-records', html) do |page|
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const Reader = function() {};
          Reader.prototype.parse = function() {
            const body = document.querySelector('main article').innerHTML;
            return {title: document.title,
              content: '<article>' + body.replace('<h1>', '<h2>').replace('</h1>', '</h2>') + '</article>',
              textContent: document.querySelector('main article').textContent};
          };
          window.Readability = Reader;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS

      expect(payload.fetch('title')).to eq(headline)
      expect(payload.fetch('markdown')).to start_with("# #{headline}\n")
      expect(payload.fetch('markdown')).not_to include("## [#{headline}]")
      expect(payload.fetch('markdown')).to include('The announced programme also covers maintenance')
    end
  end

  it 'does not trust a linked heading that points to a different article' do
    headline = 'Local researchers publish complete transport funding records for every district'
    html = <<~HTML
      <html><head><title>#{headline} | Regional research archive</title></head><body><main>
        <article>
          <h1><a href="/reports/another-story">#{headline}</a></h1>
          <p>The complete regional report explains the public funding decisions and offers the original records for review by affected residents.</p>
          <p>Each section describes the local consultation, the possible route changes, and the dates when the final policy will be announced.</p>
          <p>Researchers also published independent measurements that readers can compare with the ministry's own report and supporting evidence.</p>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://journal.example/reports/funding-records', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      page.add_script_tag(content: source.sub('})(window);', 'global.selfLinkedTitleProbe = articleTitleFromSelfLinkedHeading; })(window);'))
      selected = "<article><h2><a href='/reports/another-story'>#{headline}</a></h2><p>Original article prose.</p></article>"
      title = "#{headline} | Regional research archive"

      expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)})")).to eq(title)
    end
  end

  it 'does not borrow a self-linked title for foreign or ambiguous selected prose' do
    headline = 'Local researchers publish complete transport funding records for every district'
    title = "#{headline} | Regional research archive"
    source_body = '<p>The source article explains the public funding decisions and offers the original records for review by affected residents.</p>' \
                  '<p>Each section describes the local consultation, the possible route changes, and the dates when the final policy will be announced.</p>'
    selected_body = '<p>A foreign article describes an unrelated public health decision and the evidence gathered by local clinics.</p>' \
                    '<p>Its conclusion discusses services, patient access, and findings from a separate investigation.</p>'

    [
      "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1>#{source_body}</article>",
      "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1>#{source_body}</article>" \
        "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1>#{source_body}</article>"
    ].each do |source_articles|
      html = "<html><head><title>#{title}</title></head><body>#{source_articles}</body></html>"
      with_url_page('https://journal.example/reports/funding-records', html) do |page|
        source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
          File.read(File.join('websieve', entry))
        end.join("\n")
        source = source.sub('})(window);', 'global.selfLinkedTitleProbe = articleTitleFromSelfLinkedHeading; })(window);')
        page.add_script_tag(content: source)
        selected = "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1>#{selected_body}</article>"

        expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)})")).to eq(title)
      end
    end
  end

  it 'rejects a self-linked heading when selected prose is short-foreign, reordered, or has duplicate owners' do
    headline = 'Local researchers publish complete transport funding records for every district'
    title = "#{headline} | Regional research archive"
    first = 'The source article explains the public funding decisions and offers the original records for review by affected residents.'
    second = 'Each section describes the local consultation, the possible route changes, and the dates when the final policy will be announced.'
    source_article = "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1><p>#{first}</p><p>#{second}</p></article>"
    html = "<html><head><title>#{title}</title></head><body>#{source_article}</body></html>"

    with_url_page('https://journal.example/reports/funding-records', html) do |page|
      source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join('websieve', entry))
      end.join("\n")
      source = source.sub('})(window);', 'global.selfLinkedTitleProbe = articleTitleFromSelfLinkedHeading; })(window);')
      page.add_script_tag(content: source)
      selected_bodies = [
        "<p>#{first}</p><p>foreign short paragraph</p><p>#{second}</p>",
        "<p>#{second}</p><p>#{first}</p>"
      ]
      selected_bodies.each do |body|
        selected = "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1>#{body}</article>"
        expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)})")).to eq(title)
      end
      wrong_destination = "<article><h1><a href='/reports/another-story'>#{headline}</a></h1><p>#{first}</p><p>#{second}</p></article>"
      expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(wrong_destination)}, #{JSON.generate(title)})")).to eq(title)
    end

    duplicate_source = "<html><head><title>#{title}</title></head><body>#{source_article}#{source_article}</body></html>"
    with_url_page('https://journal.example/reports/funding-records', duplicate_source) do |page|
      source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join('websieve', entry))
      end.join("\n")
      source = source.sub('})(window);', 'global.selfLinkedTitleProbe = articleTitleFromSelfLinkedHeading; })(window);')
      page.add_script_tag(content: source)
      selected = "<article><h1><a href='/reports/funding-records'>#{headline}</a></h1><p>#{first}</p><p>#{second}</p></article>"
      expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)})")).to eq(title)
    end
  end

  it 'uses the sole visible article heading instead of an unowned site tagline' do
    html = <<~HTML
      <html><head><title>Quickstart | Example • Source documentation</title></head><body><main><article>
        <h1>Quickstart</h1>
        <p>This first paragraph explains how to install the publishing tool and prepare the first local project with a complete public guide.</p>
        <p>The next paragraph shows the build command, where to preview the output, and how to publish the finished documentation.</p>
        <div class="comments">Leave a comment</div>
      </article></main></body></html>
    HTML

    with_url_page('https://docs.example/quickstart', html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('Quickstart')
      expect(payload['markdown']).to start_with("# Quickstart\n")
      expect(payload['markdown'].scan('how to publish the finished documentation').length).to eq(1)
    end
  end

  it 'keeps the full page title when multiple articles make ownership uncertain' do
    html = <<~HTML
      <html><head><title>Quickstart | Editorial context</title></head><body><main>
        <article><h1>Quickstart</h1>
          <p>The first article describes the project setup and its workflow for readers seeking detailed installation guidance.</p>
          <p>The next article section describes the available build commands and how to verify the generated site locally.</p>
        </article>
        <article><h1>Related report</h1><p>A separate independent article follows with its own public source and story.</p></article>
      </main></body></html>
    HTML

    with_url_page('https://docs.example/quickstart', html) do |page|
      payload = extract_payload(page)
      expect(payload['title']).to eq('Quickstart | Editorial context')
    end
  end

  it 'removes a declared brand suffix only when the selected article confirms its exact title' do
    with_page('<main><article><p>Journalistic report.</p>' \
              '<p>The article explains the public record and identifies the affected local authority.</p>' \
              '<p>Readers can review the documented decision and evidence supporting its conclusions.</p></article></main>') do |page|
      source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join('websieve', entry))
      end.join("\n")
      source = source.sub('})(window);', 'global.declaredDescriptionTitleProbe = articleTitleFromDeclaredDescription; })(window);')
      page.add_script_tag(content: source)
      selected = '<article><p>Journalistic report.</p>' \
                 '<p>The article explains the public record and identifies the affected local authority.</p>' \
                 '<p>Readers can review the documented decision and evidence supporting its conclusions.</p></article>'
      title = 'Journalistic report - Example Publishing'

      expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)}, 'Example Publishing', 'Journalistic report.')"))
        .to eq('Journalistic report')
      expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)}, 'Example Publishing', 'A different report.')"))
        .to eq(title)
      foreign_body = '<article><p>Unrelated article prose.</p></article>'
      expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(foreign_body)}, #{JSON.generate(title)}, 'Example Publishing', 'Journalistic report.')"))
        .to eq(title)
      ambiguous = '<article><p>Journalistic report.</p></article><article><p>Journalistic report.</p></article>'
      expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(ambiguous)}, #{JSON.generate(title)}, 'Example Publishing', 'Journalistic report.')"))
        .to eq(title)
      expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)}, 'example-publishing.example', 'Journalistic report.')"))
        .to eq(title)
    end
  end

  it 'requires every selected paragraph to match its unique source article in order for brand proof' do
    title = 'Journalistic report - Example Publishing'
    selected = '<article><p>Journalistic report.</p>' \
               '<p>The article explains the public record and identifies the affected local authority.</p>' \
               '<p>Readers can review the documented decision and evidence supporting its conclusions.</p></article>'
    source_article = '<article><p>Journalistic report.</p>' \
                     '<p>The article explains the public record and identifies the affected local authority.</p>' \
                     '<p>Readers can review the documented decision and evidence supporting its conclusions.</p></article>'
    source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join('websieve', entry))
    end.join("\n")
    source = source.sub('})(window);', 'global.declaredDescriptionTitleProbe = articleTitleFromDeclaredDescription; })(window);')
    foreign = '<article><p>Unrelated first paragraph provides enough visible detail to look like the beginning of a substantial public investigation.</p>' \
              '<p>Unrelated second paragraph continues the separate story with more context, evidence, and conclusions for its own readers.</p></article>'
    mixed = '<article><p>Journalistic report.</p><p>foreign</p>' \
            '<p>The article explains the public record and identifies the affected local authority.</p>' \
            '<p>Readers can review the documented decision and evidence supporting its conclusions.</p></article>'
    reordered = '<article><p>Readers can review the documented decision and evidence supporting its conclusions.</p>' \
                '<p>The article explains the public record and identifies the affected local authority.</p>' \
                '<p>Journalistic report.</p></article>'

    with_page("<main>#{source_article}</main>") do |page|
      page.add_script_tag(content: source)
      [foreign, mixed, reordered].each do |body|
        expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(body)}, #{JSON.generate(title)}, 'Example Publishing', 'Journalistic report.')"))
          .to eq(title)
      end
    end

    duplicate_source = "<main>#{source_article}#{source_article}</main>"
    with_page(duplicate_source) do |page|
      page.add_script_tag(content: source)
      expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)}, 'Example Publishing', 'Journalistic report.')"))
        .to eq(title)
    end
  end

  it 'rejects hidden, nested, and sidebar paragraphs as title ownership witnesses' do
    title = 'Journalistic report - Example Publishing'
    selected = '<article><p>The selected report provides its own detailed account of transport decisions and the evidence behind them.</p>' \
               '<p>Its final section explains the local responses and the next steps available to affected residents.</p></article>'
    selected_paragraphs = selected.delete_prefix('<article>').delete_suffix('</article>')
    public_prose = '<p>The actual outer article discusses a separate investigation and the records available from local authorities.</p>' \
                   '<p>Its source material and conclusions concern a different set of events and public responsibilities.</p>'
    source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join('websieve', entry))
    end.join("\n")
    source = source.sub('})(window);', 'global.declaredDescriptionTitleProbe = articleTitleFromDeclaredDescription; })(window);')
    owners = [
      "<article><div hidden>#{selected_paragraphs}</div>#{public_prose}</article>",
      "<article>#{selected}#{public_prose}</article>",
      "<aside>#{selected}</aside>",
      "<article><h1 hidden>Journalistic report</h1>#{selected_paragraphs}</article>"
    ]

    owners.each do |owner|
      with_page("<main>#{owner}</main>") do |page|
        page.add_script_tag(content: source)
        expect(page.evaluate("declaredDescriptionTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)}, 'Example Publishing', 'Journalistic report.')"))
          .to eq(title)
      end
    end
  end

  it 'does not use an empty or hidden permalink as a linked headline' do
    headline = 'Local researchers publish complete transport funding records for every district'
    title = "#{headline} | Regional research archive"
    body = '<p>The source article explains the public funding decisions and offers the original records for review by affected residents.</p>' \
           '<p>Each section describes the local consultation, possible route changes, and the dates when the final policy will be announced.</p>'
    source = File.readlines('websieve/manifest.txt', chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join('websieve', entry))
    end.join("\n")
    source = source.sub('})(window);', 'global.selfLinkedTitleProbe = articleTitleFromSelfLinkedHeading; })(window);')
    headings = [
      "<h1>#{headline}<a href='/reports/funding-records'></a></h1>",
      "<h1><a style='display:none' href='/reports/funding-records'>#{headline}</a></h1>"
    ]

    headings.each do |heading|
      html = "<html><head><title>#{title}</title></head><body><article>#{heading}#{body}</article></body></html>"
      with_url_page('https://journal.example/reports/funding-records', html) do |page|
        page.add_script_tag(content: source)
        selected = "<article><h1>#{headline}</h1>#{body}</article>"
        expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)})")).to eq(title)
      end
    end
  end

  it 'uses a unique preceding main headline corroborated by the selected article body' do
    short = 'Researchers publish the complete regional transport funding records'
    headline = "#{short}, including independent measurements from every district"
    html = <<~HTML
      <html><head><title>#{short} | Public records journal</title>
      <meta property="og:site_name" content="Public records journal"></head><body><main>
        <h1>#{headline}</h1>
        <div class="article-author">Independent author</div>
        <aside><a href="/other-story">Unrelated article</a></aside>
        <article>
          <p>#{headline}</p>
          <p>The first section describes the independently checked regional measurements and explains their relevance to every affected district.</p>
          <p>The second section reports the complete public funding records alongside the timetable, consultation dates, and supporting documents.</p>
        </article>
      </main></body></html>
    HTML

    extract_from_url('https://records.example/articles/regional-funding', html) do |payload|
      expect(payload['title']).to eq(headline)
      expect(payload['markdown']).not_to include('Public records journal', 'Unrelated article')
      expect(payload['markdown']).to include('independently checked regional measurements', 'complete public funding records')
    end
  end

  it 'does not promote an adjacent headline when another article shares its main owner' do
    short = 'Researchers publish the complete regional transport funding records'
    headline = "#{short}, including independent measurements from every district"
    html = <<~HTML
      <html><head><title>#{short} | Public records journal</title></head><body><main>
        <h1>#{headline}</h1>
        <article>
          <p>#{headline}</p>
          <p>The first section describes the independently checked regional measurements for affected residents.</p>
          <p>The second section reports the complete public funding records and consultation timetable.</p>
        </article>
        <article><p>An independent report on a different public issue appears in this second article.</p></article>
      </main></body></html>
    HTML

    with_url_page('https://records.example/articles/regional-funding', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      source = source.sub('})(window);', 'global.adjacentTitleProbe = articleTitleFromOwnedExternalHeading; })(window);')
      page.add_script_tag(content: source)
      selected = "<p>#{headline}</p>" \
                 '<p>The first section describes the independently checked regional measurements for affected residents.</p>' \
                 '<p>The second section reports the complete public funding records and consultation timetable.</p>'
      title = "#{short} | Public records journal"

      expect(page.evaluate("adjacentTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)}, 'Public records journal')"))
        .to eq(title)
    end
  end
end
