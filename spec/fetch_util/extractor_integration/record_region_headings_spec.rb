require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical record and region heading ownership' do
  include_context 'extractor integration helpers'

  def record_region_headings(html, flag: nil, separate: false, missing: false)
    repository = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    modules = File.readlines(File.join(repository, 'websieve/manifest.txt'), chomp: true)
                  .reject { |line| line.empty? || line.start_with?('#') }
    source = modules.map { |path| File.read(File.join(repository, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(repository, 'websieve/99_outro.js'))
    raise 'extractor closure is not unique' unless source.scan(outro).length == 1

    with_url_page('https://record.publication.example.test/', html) do |page|
      inject_standalone_extractor(page)
      probe = 'window.recordRegionProbe = {region: sectionRegionHeadingMarkdown, record: listMarkdown};'
      page.add_script_tag(content: source.sub(outro, "#{probe}\n#{outro}"))
      before = page.evaluate('document.body.outerHTML')
      result = page.evaluate(<<~JS)
        (() => {
          const card = document.querySelector('article');
          const link = card.querySelector('a');
          const heading = #{missing.to_json} ? null : document.getElementById(#{(separate ? "region-heading" : "record-heading").to_json});
          const item = {card: card, sourceNode: link, text: link.textContent, url: link.href};
          const flag = #{flag.to_json};
          if (flag) item[flag] = true;
          const region = {node: document.querySelector('section') || card, headingNode: heading,
            label: heading ? heading.textContent : 'Declared grouping', cards: [item]};
          return {region: window.recordRegionProbe.region(region), record: window.recordRegionProbe.record([item])};
        })()
      JS
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      return result
    end
  end

  def heading_record
    '<article><h2 id="record-heading"><a href="/report">Owned report</a></h2>' \
      '<p>Complete independently authored report detail.</p></article>'
  end

  %w[sourceOrderedRepeatedRecord sourceOrderedStructuredCard].each do |flag|
    it "renders an owned physical heading once for #{flag}" do
      result = record_region_headings(heading_record, flag: flag)
      expect(result.fetch('region')).to eq('')
      expect(result.fetch('record').scan(/^## /).length).to eq(1)
      expect(result.fetch('record')).to include('## [Owned report](https://record.publication.example.test/report)')
      expect(result.fetch('record')).to include('Complete independently authored report detail.')
    end
  end

  it 'retains the region heading when a partial record has no complete-rendering proof' do
    result = record_region_headings(heading_record)
    expect(result.fetch('region')).to eq('## [Owned report](https://record.publication.example.test/report)')
  end

  it 'retains an independent equal-label section heading and the card heading at their actual ranks' do
    html = '<section><h2 id="region-heading">Owned report</h2><article>' \
      '<h3 id="record-heading"><a href="/report">Owned report</a></h3>' \
      '<p>Complete independently authored report detail.</p></article></section>'
    result = record_region_headings(html, flag: 'sourceOrderedRepeatedRecord', separate: true)
    expect(result.fetch('region')).to eq('## Owned report')
    expect(result.fetch('record')).to include('### [Owned report](https://record.publication.example.test/report)')
    expect(result.fetch('record')).to include('Complete independently authored report detail.')
  end

  it 'retains a declared grouping without a physical heading instead of guessing ownership from its label' do
    result = record_region_headings(heading_record, flag: 'sourceOrderedRepeatedRecord', missing: true)
    expect(result.fetch('region')).to eq('## Declared grouping')
    expect(result.fetch('record').scan(/^## /).length).to eq(1)
  end
end
