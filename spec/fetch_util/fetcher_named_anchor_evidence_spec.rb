# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  def named_anchor_snapshot(markdown)
    url = 'https://publication.example/research'
    described_class::PayloadSnapshot.new(
      payload: { 'title' => 'Research publication', 'siteName' => 'Publication', 'markdown' => markdown },
      requested_url: url, final_url: url, canonical_url: url, raw_final_url: url, raw_canonical_url: url
    )
  end

  def named_anchor_evidence(markdown)
    snapshot = named_anchor_snapshot(markdown)
    %i[markdown normalized_markdown content_downcase context context_downcase context_with_excerpt_downcase
       first_20_context first_80_context plain_list_item_count linked_heading_count linked_item_count
       markdown_link_count prose_lines long_prose_line_count_one_hundred long_prose_line_count_one_twenty
       long_prose_line_count_one_forty list_link_count table_row_count heading_count common_tokens].to_h do |name|
      [name, snapshot.public_send(name)]
    end
  end

  it 'ignores empty id and legacy-name declarations in evidence without changing surrounding text' do
    original = "Before [complete methods](https://publication.example/methods) after.\n"
    annotated = "Before <a id=\"methods\" name=\"legacy-methods\"></a>[complete methods](https://publication.example/methods) after.\n"

    expect(named_anchor_snapshot(annotated).markdown).to eq(original)
  end

  it 'keeps every bounded context and reading metric invariant under zero-text declarations' do
    original = "# Complete report\n\n#{"The complete research findings remain available to every reader.\n\n" * 85}"
    identities = (1..204).map { |number| "<a id=\"source-reference-#{number}\"></a>" }.join
    annotated = "# #{identities}Complete report\n\n" + original.split("\n\n", 2).last

    expect(named_anchor_evidence(annotated)).to eq(named_anchor_evidence(original))
  end

  it 'preserves linked-heading and linked-item evidence when declarations precede the links' do
    original = "## [Complete heading](https://publication.example/heading)\n\n- [Complete record](https://publication.example/record)\n"
    annotated = "## <a id=\"heading\"></a>[Complete heading](https://publication.example/heading)\n\n- <a name=\"record\"></a>[Complete record](https://publication.example/record)\n"

    expect(named_anchor_evidence(annotated)).to eq(named_anchor_evidence(original))
  end

  it 'handles nested list targets while preserving an indented literal program in the same list' do
    original = <<~'MARKDOWN'
      - Parent record
          - [Nested record](https://publication.example/nested)
              - [Deeper record](https://publication.example/deeper)

      A complete program follows.

          <a id="literal-program"></a>

      After the list.
    MARKDOWN
    annotated = original.sub('- [Nested', '- <a id="nested"></a>[Nested')
                        .sub('- [Deeper', '- <a name="deeper"></a>[Deeper')

    expect(named_anchor_snapshot(annotated).markdown).to eq(original)
  end

  it 'recognizes complete quoted identity values without interpreting their backticks or greater-than characters' do
    annotated = "before<a id=\"part&gt;one`two\" name='legacy&#10;reference'></a>after\n"

    expect(named_anchor_snapshot(annotated).markdown).to eq("beforeafter\n")
  end

  {
    'an identity value containing an authored newline' => "before<a id=\"two\nlines\"></a>after\n",
    'a complete attributed anchor across lines' => "before<a id=\"target\"\n href=\"https://publication.example/reference\">reading</a>after\n",
    'an apparent target inside a multiline quoted attribute' => "before<div title=\"first line\n<a id='quoted'></a>\nlast line\">reading</div>after\n"
  }.each do |description, markdown|
    it "preserves #{description} exactly once" do
      expect(named_anchor_snapshot(markdown).markdown).to eq(markdown)
    end
  end

  it 'continues ordinary evidence after a complete multiline tag without copying any tag bytes twice' do
    original = "before<div\n data-note=\"complete\nreference\">reading</div>after\n"
    annotated = original.sub('reading</div>', 'reading</div><a id="ordinary"></a>')

    expect(named_anchor_snapshot(annotated).markdown).to eq(original)
  end

  it 'retains independent duplicate identities in published input while excluding each declaration from evidence' do
    original = 'one two three'
    annotated = '<a id="same"></a>one <a id="same"></a>two <a name="same"></a>three'

    expect(named_anchor_snapshot(annotated).markdown).to eq(original)
    expect(annotated.scan('<a ').length).to eq(3)
  end

  it 'does not treat an unmatched backtick as an instruction to hide later ordinary evidence' do
    original = "An unmatched ` marker before the complete reference.\n"
    annotated = "An unmatched ` marker <a id=\"ordinary\"></a>before the complete reference.\n"

    expect(named_anchor_snapshot(annotated).markdown).to eq(original)
  end

  {
    'fenced HTML' => "```html\n<a id=\"literal\"></a>\n```\n",
    'tilde fences' => "~~~html\n<a name=\"literal\"></a>\n~~~\n",
    'long fences containing shorter fences' => "````html\n```\n<a id=\"literal\"></a>\n```\n````\n",
    'a quoted fenced block' => "> ```html\n> <a id=\"literal\"></a>\n> ```\n",
    'a fenced block nested in a list' => "- Instructions\n\n    ```html\n    <a id=\"literal\"></a>\n    ```\n",
    'inline code' => "Keep `<a id=\"literal\"></a>` exactly.\n",
    'a longer inline delimiter' => "Keep ``<a id=\"literal`value\"></a>`` exactly.\n",
    'multiline inline code' => "Keep `a program\n<a name=\"literal\"></a>` exactly.\n",
    'indented code' => "A program follows.\n\n    <a id=\"literal\"></a>\n\nAfterwards.\n",
    'indented code inside a list' => "- Instructions\n\n      <a id=\"literal\"></a>\n",
    'tab-indented code' => "A program follows.\n\n\t<a name=\"literal\"></a>\n",
    'escaped HTML' => "Keep \\<a id=\"literal\"></a> as text.\n",
    'encoded HTML' => "Keep &lt;a id=\"literal\"&gt;&lt;/a&gt; as text.\n",
    'HTML comments' => "<!-- <a id=\"literal\"></a> -->\n",
    'CDATA' => "<![CDATA[<a id=\"literal\"></a>]]>\n",
    'processing instructions' => "<?example <a id=\"literal\"></a> ?>\n"
  }.each do |description, markdown|
    it "preserves complete #{description} as evidence" do
      expect(named_anchor_snapshot(markdown).markdown).to eq(markdown)
    end
  end

  %w[pre code script style textarea svg math].each do |tag|
    it "preserves a complete raw #{tag} region and its apparent target declarations" do
      markdown = "<#{tag}>before<a id=\"literal\"></a>after</#{tag}>\n"

      expect(named_anchor_snapshot(markdown).markdown).to eq(markdown)
    end
  end

  [
    '<a id="meaningful" href="https://publication.example/"></a>',
    '<a id="meaningful" class="indicator"></a>',
    '<a id="meaningful" title="Complete context"></a>',
    '<a id="meaningful" role="button"></a>',
    '<a id="meaningful">complete reading</a>',
    '<a id="meaningful"> </a>',
    '<a id=""></a>',
    '<a name=""></a>',
    '<a title="<a id=\'quoted\'></a>">complete reading</a>',
    '<span id="existing-heading-contract"></span>'
  ].each_with_index do |markdown, index|
    it "preserves complete non-target or independently attributed anchor form #{index + 1}" do
      expect(named_anchor_snapshot(markdown).markdown).to eq(markdown)
    end
  end

  it 'returns complete original Markdown and leaves the whole Native payload untouched' do
    url = 'https://publication.example/article/methods'
    markdown = "# Methods\n\n<a id=\"methods\" name=\"legacy\"></a>[Complete reference](https://publication.example/reference)\n"
    payload = payload_with(title: 'Complete methods', markdown: markdown, contentType: 'article')
    original = Marshal.dump(payload)
    stub_browser_extraction(url, page: page_at(url), payload: payload)

    result = fetch_with_dependencies(url)

    expect(result.markdown).to eq(markdown)
    expect(Marshal.dump(payload)).to eq(original)
  end
end
