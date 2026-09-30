# frozen_string_literal: true

RSpec.describe 'FetchUtil repeated record collection ownership' do
  include_context 'extractor integration helpers'

  def story_cards(count, prefix: 'weekly', images: false, alt_texts: nil)
    (1..count).map do |index|
      number = format("%02d", index)
      alt = alt_texts ? alt_texts[index - 1] : "Issue date #{index}"
      media = images ? %(<a href="/#{prefix}/#{index}"><img src="/covers/#{index}.jpg" alt="#{alt}"></a>) : ''
      <<~HTML
        <div class="story-card">
          #{media}<h2><a href="/#{prefix}/#{index}">Weekly issue #{number}</a></h2>
          <p>Published June #{index}, 2026</p>
        </div>
      HTML
    end.join
  end

  it 'classifies an unknown-host homepage with repeated records and retains an uncapped source-ordered collection' do
    html = <<~HTML
      <html><head><title>Weekly editions</title></head><body><main>
        <h1>Weekly editions</h1>#{story_cards(19)}
      </main></body></html>
    HTML

    with_url_page('https://unknown.example/weekly.htm', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('list')
      positions = (1..19).map do |index|
        title = "Weekly issue #{format("%02d", index)}"
        expect(payload['markdown']).to include(title)
        expect(payload['markdown']).to include("https://unknown.example/weekly/#{index}")
        payload['markdown'].index(title)
      end
      expect(positions).to eq(positions.sort)
    end
  end

  it 'preserves repeated linked cover media and its local date context' do
    html = <<~HTML
      <html><head><title>Weekly editions</title></head><body><main>
        <h1>Weekly editions</h1><div id="collection">
          #{story_cards(4, images: true)}
        </div>
      </main></body></html>
    HTML

    with_url_page('https://unknown.example/weekly.htm', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('list')
      (1..4).each do |index|
        expect(payload['html']).to include("/covers/#{index}.jpg", "Issue date #{index}")
        linked_cover = "[![Issue date #{index} Weekly issue #{format("%02d", index)}](https://unknown.example/covers/#{index}.jpg)](https://unknown.example/weekly/#{index})"
        expect(payload['markdown']).to include("Published June #{index}, 2026", "Issue date #{index}", linked_cover)
      end
    end
  end

  it 'retains proven linked covers with blank or short source alt text' do
    html = <<~HTML
      <html><head><title>Weekly editions</title></head><body><main>
        <h1>Weekly editions</h1><div id="collection">
          #{story_cards(4, images: true, alt_texts: ["", "X", "i", ""])}
        </div>
      </main></body></html>
    HTML

    with_url_page('https://unknown.example/weekly.htm', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('list')
      (1..4).each do |index|
        expect(payload['html']).to include("/covers/#{index}.jpg")
        expect(payload['markdown']).to include("https://unknown.example/covers/#{index}.jpg")
      end
      expect(payload['markdown']).to include('[![Weekly issue 01](https://unknown.example/covers/1.jpg)]')
      expect(payload['markdown']).to include('[![X Weekly issue 02](https://unknown.example/covers/2.jpg)]')
    end
  end

  it 'does not promote hidden cards or a sidebar-only collection' do
    hidden_cards = story_cards(4)
    research_detail = "The analysis compares source material and documents how each conclusion follows from the available public record. " * 3
    prose = (1..5).map do |index|
      %(<p>Research section #{index} explains the public report's evidence, methods, chronology, and implications for policy teams. #{research_detail}</p>)
    end.join
    html = <<~HTML
      <html><head><title>Editorial report</title></head><body><main><article>
        <h1>Editorial report</h1>
        #{prose}
      </article><aside class="sidebar">#{story_cards(4, prefix: "sidebar")}</aside>
      <div hidden>#{hidden_cards}</div></main></body></html>
    HTML

    extract_from_url('https://unknown.example/reports/editorial', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Research section 1 explains the public report')
      expect(payload['markdown']).not_to include('Weekly issue 01')
    end
  end

  it 'keeps a focal article with one substantial visible paragraph ahead of related records' do
    focal_paragraph = [
      'Focal report: Investigators inspected the signed public filings and verified their sequence against the archive.',
      'The chronology identifies three separate revisions, each with a named author and published date.',
      'Residents described how delayed notices changed their application deadlines, while the agency confirmed an independent review remains underway.',
      'The report traces those verified events from the original filing through the review now requested by affected residents.'
    ].join(' ')
    article = <<~HTML
      <article itemprop="articleBody">
        <h1>Focal report on the public record</h1>
        <p>#{focal_paragraph}</p>
        <p>Editors will publish a later update if the record changes.</p>
      </article>
    HTML
    related = story_cards(4, prefix: "related")
    html = <<~HTML
      <html><head><title>Focal report on the public record</title></head><body><main>
        #{article}
        <section aria-label="Related records">#{related}</section>
      </main></body></html>
    HTML

    extract_from_url('https://unknown.example/articles/focal-report', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Focal report on the public record')
      expect(payload['markdown'].gsub(/\s+/, ' ')).to include(focal_paragraph.gsub(/\s+/, ' '))
    end
  end

  it 'keeps one long index introduction while admitting its repeated records' do
    introduction = [
      'Catalogue introduction: This archive collects complete public records and explains how each edition is organized.',
      'Editors describe the source of every entry, identify revisions that affect interpretation, and note where readers can inspect the underlying files.',
      'The index also preserves older editions so researchers can compare how the public record changed over time.'
    ].join(' ')
    html = <<~HTML
      <html><head><title>Weekly editions</title></head><body><main>
        <h1>Weekly editions</h1><p>#{introduction}</p>
        <section id="collection">#{story_cards(4)}</section>
      </main></body></html>
    HTML

    with_url_page('https://unknown.example/weekly.htm', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Weekly issue 04')
      expect(payload['markdown'].gsub(/\s+/, ' ')).to include(introduction.gsub(/\s+/, ' '))
    end
  end

  it 'does not combine competing collections or ambiguous multi-destination cards' do
    competing = <<~HTML
      <section aria-label="Regional reports">#{story_cards(4, prefix: "regional")}</section>
      <section aria-label="Research updates">#{story_cards(4, prefix: "research")}</section>
    HTML
    ambiguous_cards = (1..4).map do |index|
      %(<article class="story-card"><a href="/one/#{index}">First record #{index}</a><a href="/two/#{index}">Second record #{index}</a></article>)
    end.join
    editorial_detail = "The analysis follows the source record, explains its chronology, and describes the implications without relying on either collection below. " * 3
    prose = (1..5).map do |index|
      %(<p>Editorial section #{index} documents independent evidence and methods for readers. #{editorial_detail}</p>)
    end.join
    html = <<~HTML
      <html><head><title>Editorial report</title></head><body><main><article>
        <h1>Editorial report</h1>
        #{prose}
        #{competing}<div class="ambiguous">#{ambiguous_cards}</div>
      </article></main></body></html>
    HTML

    extract_from_url('https://unknown.example/reports/editorial', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Editorial section 1 documents independent evidence')
      expect(payload['markdown']).to include('Weekly issue 01', 'https://unknown.example/regional/1')
      expect(payload['markdown']).to include('Weekly issue 01', 'https://unknown.example/research/1')
    end
  end

  it 'does not merge two independent repeated collections into one list' do
    html = <<~HTML
      <html><head><title>Weekly collections</title></head><body><main>
        <h1>Weekly collections</h1>
        <section aria-label="Regional reports">#{story_cards(4, prefix: "regional")}</section>
        <section aria-label="Research updates">#{story_cards(4, prefix: "research")}</section>
      </main></body></html>
    HTML

    with_url_page('https://unknown.example/weekly.htm', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).not_to eq('list')
      expect(payload['markdown']).to include('Weekly issue 01', 'https://unknown.example/regional/1')
      expect(payload['markdown']).to include('Weekly issue 01', 'https://unknown.example/research/1')
    end
  end

  it 'does not count duplicate copies of the same destination and title as distinct records' do
    cards = (1..4).map do |index|
      %(<div class="story-card"><h2><a href="/reports/shared">Shared report</a></h2><p>Copy #{index}</p></div>)
    end.join
    context = 'This account retains the full narrative context around the cited report for readers and researchers. ' * 2
    prose = (1..6).map do |index|
      %(<p>Analysis section #{index} details the evidence, chronology, and implications from multiple independent public records. #{context}</p>)
    end.join
    html = <<~HTML
      <html><head><title>Editorial report</title></head><body><main>
        <h1>Editorial report</h1><article>#{prose}
        #{cards}</article>
      </main></body></html>
    HTML

    extract_from_url('https://unknown.example/reports/editorial', html) do |payload|
      expect(payload['contentType']).to eq('article')
      (1..6).each { |index| expect(payload['markdown']).to include("Analysis section #{index} details") }
    end
  end

  it 'retains narrative DIV and SECTION records that each cite the same source' do
    narrative_cards = (1..4).map do |index|
      prose = <<~TEXT.gsub("\n", " ").strip * 2
        Editorial section #{index} follows the evidence through its complete chronology,
        documents testimony, and explains consequences for the people involved.
      TEXT
      tag = index.even? ? 'section' : 'div'
      %(<#{tag} class="story-card"><h2>Section #{index}</h2><p>#{prose}<a href="/sources/report">source report</a></p></#{tag}>)
    end.join
    html = <<~HTML
      <html><head><title>Editorial analysis</title></head><body><main><article>
        <h1>Editorial analysis</h1>#{narrative_cards}
      </article></main></body></html>
    HTML

    extract_from_url('https://unknown.example/opinion/analysis', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('complete chronology')
      expect(payload['markdown']).to include('consequences', 'people involved')
      expect(payload['markdown'].scan('https://unknown.example/sources/report').length).to eq(4)
    end
  end

  it 'keeps a headed unlinked methods section beside reference cards as an article' do
    paragraphs = (1..4).map do |index|
      %(<p>Methods section #{index} describes the research design, compares primary evidence,
        explains the chronology, and records limitations for readers assessing the analysis and its conclusions.</p>)
    end.join
    references = (1..4).map do |index|
      %(<article class="reference-card"><h3><a href="/references/#{index}">Reference work #{index}</a></h3></article>)
    end.join
    html = <<~HTML
      <html><head><title>Methods and references</title></head><body><main>
        <section class="methods"><h2>Methods and analysis</h2>#{paragraphs}</section>
        <section class="references">#{references}</section>
      </main></body></html>
    HTML

    extract_from_url('https://unknown.example/notes/research', html) do |payload|
      expect(payload['contentType']).to eq('article')
      (1..4).each do |index|
        expect(payload['markdown']).to include("Methods section #{index}", "Reference work #{index}")
        expect(payload['markdown']).to include("https://unknown.example/references/#{index}")
      end
    end
  end

  it 'does not graft an adjacent collection onto owned about prose' do
    paragraphs = (1..4).map do |index|
      detail = "Further analysis preserves the surrounding context and source distinctions. " * 2
      lead = "About section #{index} describes the research program, reviews its documented history, and explains its evidence."
      %(<p>#{lead} #{detail}</p>)
    end.join
    references = (1..4).map do |index|
      %(<article class="reference-card"><h3><a href="/projects/#{index}">Other project #{index}</a></h3></article>)
    end.join
    html = <<~HTML
      <html><head><title>Research notes</title></head><body>
        <main><div class="about"><h2>About this research</h2>#{paragraphs}</div>
          <section aria-label="Other projects">#{references}</section>
        </main>
      </body></html>
    HTML

    extract_from_url('https://unknown.example/reference-overview', html) do |payload|
      expect(payload['contentType']).to eq('article')
      (1..4).each do |index|
        expect(payload['markdown']).to include("About section #{index}")
        expect(payload['markdown']).not_to include("Other project #{index}", "https://unknown.example/projects/#{index}")
      end
    end
  end

  it 'limits primary-main prose evidence and rendering to that main region' do
    site_information = (1..4).map do |index|
      %(<p>Company information #{index} describes the organization's history, services, mission, and public contacts for visitors.</p>)
    end.join
    html = <<~HTML
      <html><head><title>Weekly editions</title></head><body>
        <main><h1>Weekly editions</h1>#{story_cards(4)}</main>
        <div class="about"><h2>About the organization</h2>#{site_information}</div>
      </body></html>
    HTML

    with_url_page('https://unknown.example/weekly.htm', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('list')
      (1..4).each { |index| expect(payload['markdown']).to include("Weekly issue #{format("%02d", index)}") }
      expect(payload['markdown']).not_to include('Company information 1')
    end
  end

  it 'does not treat distinct labels for the same destination as independent records' do
    aliases = (1..4).map do |index|
      %(<article class="reference-card"><h2><a href="/references/shared">Reference alias #{index}</a></h2></article>)
    end.join
    prose = (1..4).map do |index|
      %(<p>Analysis section #{index} evaluates the source record, documents the research method, and explains the evidence and its limitations.</p>)
    end.join
    html = <<~HTML
      <html><head><title>Research analysis</title></head><body><main><article>
        <h1>Research analysis</h1>#{prose}#{aliases}
      </article></main></body></html>
    HTML

    extract_from_url('https://unknown.example/reports/analysis', html) do |payload|
      expect(payload['contentType']).to eq('article')
      (1..4).each do |index|
        expect(payload['markdown']).to include("Analysis section #{index}", "Reference alias #{index}")
      end
    end
  end
end
