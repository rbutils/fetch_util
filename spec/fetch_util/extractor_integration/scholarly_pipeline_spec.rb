# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil shared scholarly page ownership' do
  include_context 'extractor integration helpers'

  def scholarly_fixture(name)
    File.read(File.expand_path("../../fixtures/#{name}.html", __dir__))
  end

  def scholarly_normalized_nodes(root, selector)
    root.css(selector).map { |node| node.text.gsub(/\s+/, ' ').strip }
  end

  it 'retains the complete unknown-host article through public extraction' do
    html = scholarly_fixture('scholarly_owned_record')
    source = Nokogiri::HTML(html).at_css('article')
    with_url_page('https://research.example/articles/estuaries-2026-0042', html) do |page|
      result = FetchUtil::Extractor.new.extract(page)
      body = Nokogiri::HTML.fragment(result.fetch('html'))

      expect(result).to include(
        'contentType' => 'article', 'byline' => 'Mina Fielding',
        'publishedTime' => '2026-06-18', 'warnings' => []
      )
      expect(scholarly_normalized_nodes(body, 'p')).to eq(scholarly_normalized_nodes(source, 'p'))
      expect(scholarly_normalized_nodes(body, 'h2')).to eq(scholarly_normalized_nodes(source, 'h2'))
      expect(scholarly_normalized_nodes(body, 'th, td')).to eq(scholarly_normalized_nodes(source, 'th, td'))
      expect(body.css('a[href]').map { |node| node['href'] }).to include(
        'https://data.example.org/records/estuaries-2026-0042',
        'https://doi.org/10.5555/tides.2024.001', 'https://doi.org/10.5555/budgets.2025.008'
      )
      expect(body.at_css('img')['alt']).to eq('Map of paired restored and reference sampling stations')
      expect(body.text).to include('J = Q × (Cchannel − Cmarsh)')
      expect(result.fetch('markdown')).not_to include('Export citation', 'A separate recommended study')
    end
  end

  it 'keeps the enclosing abstract together with every scientific record field' do
    html = scholarly_fixture('scholarly_owned_gene_report')
    source = Nokogiri::HTML(html)
    with_url_page('https://www.ncbi.nlm.nih.gov/gene/1956', html) do |page|
      result = FetchUtil::Extractor.new.extract(page)
      body = Nokogiri::HTML.fragment(result.fetch('html'))

      expect(body.text).to include(source.at_css('[role="doc-abstract"] p').text, 'Gene ID: 1956')
      expect(scholarly_normalized_nodes(body, 'dt, dd')).to eq(scholarly_normalized_nodes(source, 'dt, dd'))
      expect(scholarly_normalized_nodes(body, 'th, td')).to eq(scholarly_normalized_nodes(source, 'th, td'))
      expect(result.fetch('markdown')).to include('Genomic context', 'Expression', '22 other tissues')
      expect(result.fetch('warnings')).to be_empty
    end
  end

  it 'does not let a hidden abstract displace the visible scientific record' do
    html = scholarly_fixture('scholarly_owned_gene_report').sub('role="doc-abstract"', 'role="doc-abstract" hidden')
    with_url_page('https://www.ncbi.nlm.nih.gov/gene/1956', html) do |page|
      result = FetchUtil::Extractor.new.extract(page)

      expect(result.fetch('contentType')).to eq('article')
      expect(result.fetch('markdown')).to include('Gene ID: 1956', 'Genomic context', '22 other tissues')
      expect(result.fetch('markdown')).not_to include('This scholarly-looking abstract')
    end
  end
end
