# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Profile article source visibility' do
  include_context 'extractor integration helpers'

  def profile_visibility_document(extra, css: '')
    <<~HTML
      <html><head><title>Published field notes</title>
      <meta name="generator" content="WordPress 6.8"><style>#{css}</style></head>
      <body><main><h1>Published field notes</h1><div class="entry-content">
      <h2>Visible introduction</h2>
      <p>The published introduction contains the complete account of the field visit, its observations,
      and the independent references required to understand the original material.</p>
      <p>Every visible section remains in its physical source position, including short explanations,
      practical examples and the final independent destination.</p>
      #{extra}
      <h2>Visible conclusion</h2><p>The final explanation follows every retained field observation.</p>
      <p><a href="/references/final?edition=full#notes">Complete final reference</a></p>
      </div></main></body></html>
    HTML
  end

  def with_profile_visibility(extra, css: '')
    with_url_page('https://publication.example.test/field/notes/', profile_visibility_document(extra, css: css)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(payload.fetch('hostAware')).to be(true)
      expect(payload.fetch('title')).to eq('Published field notes')
      expect(payload.fetch('byline')).to be_nil
      expect(payload.fetch('publishedTime')).to be_nil
      yield page, payload
    end
  end

  it 'prunes computed-hidden peers before cleanup discards their source style evidence' do
    extra = <<~HTML
      <div class="displayed-record"><h2>Published observation</h2>
      <p>The complete visible observation retains its <a href="/records/visible?view=full#source">source reference</a>.</p>
      <img src="/images/visible.png?size=full#detail" alt="Complete visible diagram"></div>
      <div class="unrendered-record"><h2>Unpublished observation</h2>
      <p>Unpublished private narrative.</p><a href="/private/unpublished">Unpublished reference</a></div>
    HTML
    with_profile_visibility(extra, css: '.unrendered-record { display: none; }') do |_page, payload|
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).to include('Published observation', 'complete visible observation',
                                 'https://publication.example.test/records/visible?view=full#source',
                                 'https://publication.example.test/images/visible.png?size=full#detail')
        expect(value).not_to include('Unpublished observation', 'Unpublished private narrative', '/private/unpublished')
      end
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(native.css('h2').map(&:text)).to eq(['Visible introduction', 'Published observation', 'Visible conclusion'])
    end
  end

  it 'keeps descendants of a display-none ancestor hidden despite their own display override' do
    extra = <<~HTML
      <div style="display:none"><div style="display:block"><h2>Ancestor-hidden record</h2>
      <p>Ancestor-hidden narrative with <a href="/private/ancestor">an unpublished destination</a>.</p></div></div>
      <p>Independently visible evidence remains after the hidden owner.</p>
    HTML
    with_profile_visibility(extra) do |_page, payload|
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).to include('Independently visible evidence remains')
        expect(value).not_to include('Ancestor-hidden', '/private/ancestor')
      end
    end
  end

  it 'retains a genuinely visible visibility override while excluding its hidden sibling text' do
    extra = <<~HTML
      <div style="visibility:hidden">Unpublished inherited text
      <p>Unpublished inherited paragraph.</p>
      <section style="visibility:visible"><h2>Visible override</h2>
      <p>The visible override owns its complete <a href="/references/override">independent reference</a>.</p></section></div>
    HTML
    with_profile_visibility(extra) do |_page, payload|
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).to include('Visible override', 'visible override owns its complete',
                                 'https://publication.example.test/references/override')
        expect(value).not_to include('Unpublished inherited')
      end
    end
  end

  it 'retains every independent visible peer even when their complete destinations are equal' do
    extra = <<~HTML
      <div><h2>First independent account</h2><p>First independently authored explanation.</p>
      <a href="/shared?edition=complete#record">First reference</a></div>
      <div><h2>Second independent account</h2><p>Second independently authored explanation.</p>
      <a href="/shared?edition=complete#record">Second reference</a></div>
    HTML
    with_profile_visibility(extra) do |_page, payload|
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expected_headings = [
        'Visible introduction',
        'First independent account',
        'Second independent account',
        'Visible conclusion'
      ]
      expect(native.css('h2').map(&:text)).to eq(expected_headings)
      expect(native.css('a[href="https://publication.example.test/shared?edition=complete#record"]').map(&:text))
        .to eq(['First reference', 'Second reference'])
      expect(payload.fetch('markdown')).to include('First independently authored explanation.',
                                                   'Second independently authored explanation.')
    end
  end

  it 'keeps whole visible programs and semantic empty line targets without exposing hidden programs' do
    program = "read_source('complete')\n\nwrite_archive('exact')"
    extra = <<~HTML
      <pre><code><a id="visible-code-line" href="#visible-code-line" style="visibility:hidden"></a>#{program}</code></pre>
      <pre class="unrendered-program"><code><a id="unpublished-code-line"></a>unpublished_program()</code></pre>
      <p>Literal material belongs to the visible program, not its hidden peer.</p>
    HTML
    with_profile_visibility(extra, css: '.unrendered-program { display: none; }') do |_page, payload|
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(native.at_css('#visible-code-line')['href'])
        .to eq('https://publication.example.test/field/notes/#visible-code-line')
      expect(payload.fetch('markdown')).to include(program)
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).not_to include('unpublished_program()', 'unpublished-code-line')
      end
    end
  end

  it 'rechecks source CSS on the next extraction rather than retaining an earlier visibility decision' do
    extra = '<section class="switchable"><h2>Newly visible account</h2><p>The complete account is visible after the CSS change.</p></section>'
    with_profile_visibility(extra, css: '.switchable { display: none; }') do |page, first|
      expect(first.fetch('html')).not_to include('Newly visible account')
      page.evaluate("document.querySelector('style').sheet.insertRule('.switchable { display: block; }', 1)")
      before = page.evaluate('document.body.outerHTML')
      second = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(second.fetch('html')).to include('Newly visible account', 'complete account is visible after the CSS change')
      expect(second.fetch('markdown')).to include('Newly visible account')
    end
  end

  it 'retains a uniquely declared active owner during its finite initial opacity reveal' do
    program = "read_active_record()\n\nkeep_complete_record()"
    extra = <<~HTML
      <section data-active-slide="current">
      <div data-slide-id="current"><div class="initial-reveal">
      <h2>Declared active account</h2><p>The active account owns its complete
      <a href="/references/active?edition=full#record">independent reference</a>.</p>
      <img src="/images/active.png?size=full#diagram" alt="Complete active diagram">
      <pre><code>#{program}</code></pre></div></div>
      <div data-slide-id="inactive" style="display:none"><h2>Unpublished inactive account</h2>
      <p>The inactive narrative and its <a href="/private/inactive">private destination</a> stay hidden.</p></div>
      </section>
    HTML
    css = '@keyframes initialReveal { from { opacity:0 } to { opacity:1 } } ' \
          '.initial-reveal { animation:initialReveal 1s 20s both; }'
    expected_material = [
      'Declared active account',
      'active account owns its complete',
      'https://publication.example.test/references/active?edition=full#record',
      'https://publication.example.test/images/active.png?size=full#diagram'
    ]
    with_profile_visibility(extra, css: css) do |_page, payload|
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).to include(*expected_material)
        expect(value).not_to include('Unpublished inactive account', '/private/inactive')
      end
      expect(Nokogiri::HTML5.fragment(payload.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include(program)
    end
  end

  it 'rejects inactive ambiguous and non-revealing opacity-zero owners' do
    variants = [
      ['different', '', 'initialReveal 1s 20s both'],
      ['current', '<div data-slide-id="current"></div>', 'initialReveal 1s 20s both'],
      ['current', '', 'initialReveal 1s 20s infinite both'],
      ['current', '', 'initialReveal 1s 20s both paused'],
      ['current', '', 'remainHidden 1s 20s both']
    ]
    variants.each do |active, peer, animation|
      extra = <<~HTML
        <section data-active-slide="#{active}">#{peer}<div data-slide-id="current">
        <div class="initial-reveal"><h2>Unproved opacity account</h2>
        <p>Unproved opacity narrative and <a href="/private/unproved">unproved destination</a>.</p>
        </div></div></section>
      HTML
      css = '@keyframes initialReveal { from { opacity:0 } to { opacity:1 } } ' \
            '@keyframes remainHidden { from { opacity:0 } to { opacity:0 } } ' \
            ".initial-reveal { animation:#{animation}; }"
      with_profile_visibility(extra, css: css) do |_page, payload|
        [payload.fetch('html'), payload.fetch('markdown')].each do |value|
          expect(value).not_to include('Unproved opacity account', 'Unproved opacity narrative', '/private/unproved')
        end
      end
    end
  end

  it 'keeps authored profile prose with a complete finite initial fade declaration' do
    program = "read_declared_source()\n\nkeep_the_complete_account()"
    extra = <<~HTML
      <section class="declared-reveal" data-animation-style="fade" data-animation-repeat=""
      data-animation-duration="1500ms" data-animation-delay="800ms" data-animation-starting-opacity="0%">
      <h3>Declared publication context</h3><p>The complete unlinked publication account remains authored material.</p>
      <p>Its independent <a href="/references/context?edition=full#source">context reference</a> stays in order.</p>
      <pre><code>#{program}</code></pre></section>
    HTML
    with_profile_visibility(extra, css: '.declared-reveal { opacity:0; }') do |_page, payload|
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).to include('Declared publication context', 'complete unlinked publication account',
                                 'https://publication.example.test/references/context?edition=full#source')
      end
      expect(Nokogiri::HTML5.fragment(payload.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include(program)
    end
  end

  it 'does not use incomplete repeated hidden or interface fade declarations as visibility evidence' do
    declaration = 'data-animation-style="fade" data-animation-repeat="" data-animation-duration="1s" ' \
                  'data-animation-delay="0ms" data-animation-starting-opacity="0%"'
    variants = [
      [declaration.sub('duration="1s"', 'duration="0ms"'), ''],
      [declaration.sub('repeat=""', 'repeat="loop"'), ''],
      [declaration.sub('data-animation-delay="0ms" ', ''), ''],
      [declaration.sub('starting-opacity="0%"', 'starting-opacity="1"'), ''],
      [declaration, 'style="display:none"'],
      [declaration, 'role="tab"']
    ]
    variants.each do |attributes, owner_attributes|
      extra = <<~HTML
        <div #{owner_attributes}><section class="declared-reveal" #{attributes}>
        <h3>Unproved declared account</h3><p>Unproved declared narrative.</p>
        <a href="/private/declaration">Unproved declared reference</a></section></div>
      HTML
      with_profile_visibility(extra, css: '.declared-reveal { opacity:0; }') do |_page, payload|
        [payload.fetch('html'), payload.fetch('markdown')].each do |value|
          expect(value).not_to include('Unproved declared account', 'Unproved declared narrative', '/private/declaration')
        end
      end
    end
  end
end
