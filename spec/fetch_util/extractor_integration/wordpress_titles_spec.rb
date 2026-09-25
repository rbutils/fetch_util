# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil WordPress fallback titles' do
  include_context 'extractor integration helpers'

  def wordpress_title_page(title, site_name: 'Field Notes', heading: nil)
    publisher = site_name ? "<meta property='og:site_name' content='#{site_name}'>" : ''
    headline = heading ? "<h1 class='entry-title'>#{heading}</h1>" : ''
    <<~HTML
      <html><head><title>#{title}</title><meta name="generator" content="WordPress">#{publisher}</head><body>
        <article>#{headline}<div class="entry-content">
          <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
          <p>Their observations showed that native plants had returned, while water quality and wildlife habitats continued to improve.</p>
          <p>The team will publish its final measurements after the next season of fieldwork.</p>
        </div></article>
      </body></html>
    HTML
  end

  it 'removes an explicitly declared publisher suffix only when the article has no headline' do
    ['-', '|', '–', '—'].each do |separator|
      html = wordpress_title_page("Restoring a river #{separator} Field Notes")
      extract_from_url('https://example-blog.test/river/', html) do |payload|
        expect(payload['title']).to eq('Restoring a river')
        expect(payload['siteName']).to eq('Field Notes')
        expect(payload['markdown']).to start_with("# Restoring a river\n")
        expect(payload['markdown']).to include('native plants had returned')
      end
    end
  end

  it 'preserves source headlines, unmatched title segments, and titles without a declared publisher' do
    cases = [
      ['Field Notes - Restoring a river', 'Field Notes', nil, 'Field Notes - Restoring a river'],
      ['Restoring a river - Another Publisher', 'Field Notes', nil, 'Restoring a river - Another Publisher'],
      ['Field Notes', 'Field Notes', nil, 'Field Notes'],
      ['Restoring a river - Field Notes', nil, nil, 'Restoring a river - Field Notes'],
      ['Understanding Field Notes - Field Notes - Field Notes', 'Field Notes', 'Understanding Field Notes - Field Notes', 'Understanding Field Notes - Field Notes']
    ]
    cases.each do |title, site_name, heading, expected|
      extract_from_url('https://example-blog.test/river/', wordpress_title_page(title, site_name: site_name, heading: heading)) do |payload|
        expect(payload['title']).to eq(expected)
        expect(payload['markdown']).to include('native plants had returned')
      end
    end
  end
end
