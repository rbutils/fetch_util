# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Short related-story sections' do
  include_context 'extractor integration helpers'

  it 'omits an isolated short recommendation while retaining substantive linkless context' do
    html = <<~HTML
      <html><head><title>Regional transport funding report</title></head><body><main><article>
        <h1>Regional transport funding report</h1>
        <p>Officials explained the completed public consultation and gave a detailed account of which routes will be funded across the region this year.</p>
        <p>The report also identifies the expected station improvements, the timetable, and the sources of funding for the work under discussion.</p>
        <p>Residents can compare the measurements in the original published report with the decisions reached during a later council meeting.</p>
        <section><h3>Te puede interesar</h3><p>Otra noticia recomendada que no pertenece al artículo.</p></section>
        <section><h3>Related articles</h3><p>The public archive explains how earlier proposals were assessed, which records remain available for review, and why the final route differs from the initial proposal. This explanation is part of the report.</p></section>
      </article></main></body></html>
    HTML

    with_url_page('https://journal.example/reports/transport-funding', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')
      expect(markdown).not_to include('Otra noticia recomendada', 'Te puede interesar')
      expect(markdown).to include('expected station improvements', 'public archive explains how earlier proposals')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'omits heading-and-time related rails without deleting substantive related commentary' do
    records = (1..6).map do |index|
      "<article><h2>Independent recommendation headline #{index}</h2><time>#{index}:15</time></article>"
    end.join
    html = <<~HTML
      <html><head><title>Regional transport funding report</title></head><body><main><article>
        <h1>Regional transport funding report</h1>
        <p>Officials explained the completed public consultation and gave a detailed account of which routes will be funded across the region this year.</p>
        <p>The report identifies the expected station improvements, the timetable, and the sources of funding for the work under discussion.</p>
        <section><h2>Zobacz również:</h2>#{records}</section>
        <p>Residents can compare the measurements in the original published report with the decisions reached during a later council meeting.</p>
        <section><h3>Related articles</h3>
          <article><h4>Historical assessment</h4><p>A substantive retrospective explains how earlier proposals were assessed and why the final route differs.</p></article>
          <article><h4>Funding context</h4><p>A substantive funding note documents the public record and the decisions made by the council.</p></article>
          <article><h4>Timetable context</h4><p>A substantive timetable note records project stages and the evidence used for the final schedule.</p></article>
        </section>
      </article></main></body></html>
    HTML

    with_url_page('https://journal.example/reports/transport-funding', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch('markdown')).not_to include('Zobacz również', 'Independent recommendation headline')
      expect(payload.fetch('markdown')).to include('substantive retrospective', 'substantive funding note',
                                                   'substantive timetable note', 'Residents can compare')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves undated unlinked editorial headings inside and beside the focal article' do
    notes = (1..3).map { |index| "<article><h3>Editorial context heading #{index}</h3></article>" }.join
    section = "<section><h2>Related articles</h2>#{notes}</section>"

    %w[inside beside].each do |placement|
      html = <<~HTML
        <html><head><title>Regional transport funding report</title></head><body><main><article>
          <h1>Regional transport funding report</h1>
          <p>The report explains the approved funding and records the evidence behind the final regional transport decision.</p>
          <p>Residents can compare the complete published measurements with the timetable and the council's commitments.</p>
          #{section if placement == "inside"}
        </article>#{section if placement == "beside"}</main></body></html>
      HTML

      with_url_page("https://journal.example/reports/undated-context-#{placement}", html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

        expect(payload.fetch('markdown')).to include(
          'approved funding', 'Related articles', 'Editorial context heading 1',
          'Editorial context heading 2', 'Editorial context heading 3'
        )
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'omits Portuguese related and trending rails without matching editorial headings' do
    html = <<~HTML
      <html><head><title>Public health funding report</title></head><body><main><article>
        <h1>Public health funding report</h1>
        <p>The published report explains the approved funding, the affected clinics, and the implementation timetable for the next fiscal year.</p>
        <p>Officials documented the public consultation and the evidence used to select the regional projects.</p>
        <p>Independent auditors will publish quarterly measurements so residents can review the program's progress.</p>
        <h2>LEIA MAIS</h2>
        <ul><li><a href='/related/one'>First unrelated story</a></li><li><a href='/related/two'>Second unrelated story</a></li></ul>
        <p>The focal report continues after the related links with substantive evidence about the implementation timetable and the clinics receiving support.</p>
        <p>Auditors will compare the published measurements with the original commitments before the program enters its second year.</p>
        <h2>EM ALTA</h2>
        <ul><li>First trending story</li></ul>
        <h2>Leia mais sobre o financiamento público</h2>
        <p>This editorial section explains the legal framework behind the funding and remains part of the focal report.</p>
        <h2>References</h2>
        <ol><li>A historical announcement archived by Business Wire documents the implementation milestone.</li></ol>
      </article></main></body></html>
    HTML

    with_url_page('https://journal.example/reports/public-health-funding', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload.fetch('markdown')).not_to include(
        'LEIA MAIS', 'First unrelated story', 'Second unrelated story'
      )
      # A lone unlinked story has no destination evidence that it is an owned related-record rail.
      expect(payload.fetch('markdown')).to include('EM ALTA', 'First trending story')
      expect(payload.fetch('markdown')).to include(
        'Leia mais sobre o financiamento público',
        'legal framework behind the funding',
        'focal report continues after the related links',
        'Auditors will compare the published measurements',
        'Business Wire documents the implementation milestone'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
