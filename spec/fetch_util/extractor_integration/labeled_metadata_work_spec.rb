# frozen_string_literal: true

RSpec.describe 'FetchUtil role-owned labeled metadata work' do
  include_context 'extractor integration helpers'

  def labeled_metadata_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.readLabeledMetadata = function(labels) {
        var before = document.body.innerHTML;
        var original = visibleMetadataNodeText;
        var unrelatedReads = 0;
        visibleMetadataNodeText = function(node) {
          if (node.nodeType === 1 && node.matches('dd[data-unrelated]')) unrelatedReads += 1;
          return original(node);
        };
        try {
          var groups = visibleLabeledMetadataGroups(document.querySelector('main'), labels && function(label) {
            return labels.indexOf(sourceRecordLabelKey(label)) !== -1;
          });
          return {groups: groups.map(function(group) {
            return {id: group.list.id, fields: group.fields.map(function(field) {
              return {label: field.label, values: field.values};
            })};
          }), unrelatedReads: unrelatedReads, unchanged: before === document.body.innerHTML};
        } finally {
          visibleMetadataNodeText = original;
        }
      };
      })(window);
    JAVASCRIPT
  end

  def labeled_metadata_page(html)
    with_url_page('https://publication.example.test/reference/definitions', html) do |page|
      page.add_script_tag(content: labeled_metadata_source)
      yield page
    end
  end

  it 'does not traverse unrelated definition values and preserves complete default parsing' do
    definitions = 250.times.map do |index|
      "<dt>Definition #{index}</dt><dd data-unrelated><span>Complete technical value #{index}</span> and its explanation.</dd>"
    end.join
    html = "<main><h1>Complete reference</h1><dl id='definitions'>#{definitions}</dl>" \
           "<dl id='publication'><dt>From</dt><dd>Published author</dd><dt>Published</dt>" \
           '<dd>2026-04-15</dd><dd>2026-04-16</dd></dl></main>'
    result = labeled_metadata_page(html) do |page|
      page.evaluate("({selected: readLabeledMetadata(['from', 'published']), complete: readLabeledMetadata(null)})")
    end

    selected = result.fetch('selected')
    expect(selected.fetch('unrelatedReads')).to eq(0)
    expect(selected.fetch('unchanged')).to be(true)
    publication_fields = [
      { 'label' => 'from', 'values' => ['Published author'] },
      { 'label' => 'published', 'values' => %w[2026-04-15 2026-04-16] }
    ]
    expect(selected.fetch('groups')).to eq([{ 'id' => 'publication', 'fields' => publication_fields }])
    complete = result.fetch('complete')
    expect(complete.fetch('unrelatedReads')).to eq(250)
    expect(complete.fetch('unchanged')).to be(true)
    expect(complete.fetch('groups').first.fetch('fields').map { |field| field.fetch('values') }).to eq(
      250.times.map { |index| ["Complete technical value #{index} and its explanation."] }
    )
  end

  it 'preserves visible label normalization, all eligible values and incomplete competing groups' do
    html = <<~HTML
      <main><dl id="record"><dt>Document Type:</dt><dd>Notice</dd>
      <dt>Agency</dt><dd>Published agency</dd><dd>Second agency</dd>
      <dt>Publication <span hidden>irrelevant hidden label</span>Date:</dt>
      <dd>2026-04-15<span hidden>hidden date suffix</span></dd>
      <dt>Document Number</dt><dd>2026-01234</dd>
      <dt>Agency</dt><dd hidden>Hidden agency</dd></dl>
      <dl id="competing"><dt>Published</dt><dd>2026-04-16</dd></dl>
      <dl id="hidden" hidden><dt>Agency</dt><dd>Hidden record</dd></dl></main>
    HTML
    labels = ['document type', 'agency', 'agencies', 'published', 'publication date', 'document number', 'document citation']
    result = labeled_metadata_page(html) { |page| page.evaluate("readLabeledMetadata(#{JSON.generate(labels)})") }

    expect(result.fetch('unchanged')).to be(true)
    expected = [
      { 'id' => 'record', 'fields' => [
        { 'label' => 'document type:', 'values' => ['Notice'] },
        { 'label' => 'agency', 'values' => ['Published agency', 'Second agency'] },
        { 'label' => 'publication date:', 'values' => ['2026-04-15'] },
        { 'label' => 'document number', 'values' => ['2026-01234'] }
      ] },
      { 'id' => 'competing', 'fields' => [{ 'label' => 'published', 'values' => ['2026-04-16'] }] }
    ]
    expect(result.fetch('groups')).to eq(expected)
  end
end
