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
end
