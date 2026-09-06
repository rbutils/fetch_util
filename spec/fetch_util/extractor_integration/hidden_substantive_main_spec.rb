# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - hidden substantive main content' do
  include_context 'extractor integration helpers'

  def visible_reader_copy(link: false)
    <<~HTML
      <article id="reader-copy">
        <h1>Unified collaboration workspace</h1>
        <p>
          The visible introduction explains how teams coordinate daily work, share decisions, and keep every project
          accountable across departments. It records the common workflow, the safeguards administrators configure,
          and the support available to people adopting the service in different regions.
        </p>
        <p>
          This visible overview remains useful on its own and must survive any recovery of additional material from
          the same document owner.#{' <a href="/reader/current">Read the current guide</a>' if link}
        </p>
      </article>
    HTML
  end

  def hidden_feature_sections(count: 5, hidden_reader_copy: false, unsafe_class: nil, nested_unsafe_class: nil,
                              nested_unsafe_attribute: nil, visible_owner_class: nil)
    (1..count).map do |index|
      paragraphs = (1..4).map do |paragraph|
        <<~HTML
          <p>
            Capability #{index} detail #{paragraph} explains implementation planning, permission governance,
            data migration, reporting, training, and long-term operational support. Teams use this evidence to
            understand each stage of delivery, compare available workflows, and preserve reliable ownership as
            their organization adds new projects, collaborators, and regional requirements.
          </p>
        HTML
      end.join

      reader_copy = if hidden_reader_copy && index == 1
                      <<~HTML
                        <h3>Independent reader report</h3>
                        <p>This independently generated reader copy occurs only inside hidden semantic-main material.</p>
                      HTML
                    end
      nested_unsafe = if (nested_unsafe_class || nested_unsafe_attribute) && index == 1
                        %(<div class="#{nested_unsafe_class}" #{nested_unsafe_attribute}>Hidden access-only workspace template</div>)
                      end

      <<~HTML
        <section class="feature-owner #{visible_owner_class if index == 1}">
          <h2>Capability group #{index}</h2>
          <p>
            This visible capability summary establishes the section as part of the rendered document owner.
          </p>
          <div class="feature-panel #{unsafe_class if index == 1}" style="display: none">
            <div class="product-preview-popup">Product preview illustration.</div>
            #{nested_unsafe}
            #{reader_copy}
            #{paragraphs}
            <ul>
              <li><a href="/capability/#{(index * 2) - 1}">Capability record #{(index * 2) - 1}</a></li>
              <li><a href="/capability/#{index * 2}">Capability record #{index * 2}</a></li>
            </ul>
          </div>
        </section>
      HTML
    end.join
  end

  def hidden_main_fixture(hidden_count: 5, current_link: false, extra_main: '', hidden_reader_copy: false,
                          unsafe_class: nil, nested_unsafe_class: nil, visible_owner_class: nil, head: '',
                          nested_unsafe_attribute: nil, main_class: nil, main_attribute: nil,
                          main_wrapper_attribute: nil, main_extra: '')
    main_wrapper_open = main_wrapper_attribute ? %(<div #{main_wrapper_attribute}>) : ''
    main_wrapper_close = main_wrapper_attribute ? '</div>' : ''

    <<~HTML
      <html><head><title>Collaboration workspace overview</title>#{head}</head><body>
        <header style="display: none">
          <nav>
            <h2>Account navigation</h2>
            #{(1..12).map { |index| %(<a href="/account/#{index}">Hidden account destination #{index}</a>) }.join}
          </nav>
        </header>
        #{main_wrapper_open}
        <main class="#{main_class}" #{main_attribute}>
           #{visible_reader_copy(link: current_link)}
             #{hidden_feature_sections(count: hidden_count, hidden_reader_copy: hidden_reader_copy,
                                       unsafe_class: unsafe_class, nested_unsafe_class: nested_unsafe_class,
                                       nested_unsafe_attribute: nested_unsafe_attribute,
                                       visible_owner_class: visible_owner_class)}
           #{main_extra}
        </main>
        #{main_wrapper_close}
        #{extra_main}
      </body></html>
    HTML
  end

  def extract_with_narrow_reader(page, root_expression: "document.querySelector('#reader-copy')")
    extract_payload(page)
    page.evaluate <<~JS
      (() => {
        const NarrowReadability = function() {};
        NarrowReadability.prototype.parse = function() {
          const root = #{root_expression};
          return {
            title: 'Collaboration workspace overview',
            content: root.outerHTML,
            textContent: root.textContent
          };
        };
        window.Readability = NarrowReadability;
        return window.FetchUtilExtract.extract({ reader_mode: true });
      })()
    JS
  end

  it 'recovers hidden material owned by one visible semantic main' do
    fixture = hidden_main_fixture(visible_owner_class: 'content-skeleton-header-buttons-content')

    with_url_page('https://workspace.example/unrelated-purple-oranges', fixture) do |page|
      payload = extract_with_narrow_reader(page)
      records = payload.fetch('markdown').scan(%r{/capability/(\d+)})

      expect(payload['contentType']).to eq('article')
      expect(payload['readerMode']).to be(false)
      expect(payload['title']).to eq('Unified collaboration workspace')
      expect(payload.fetch('markdown')).to include('This visible overview remains useful on its own')
      expect(payload.fetch('markdown')).to include('https://workspace.example/capability/1')
      expect(records.flatten.map(&:to_i)).to eq((1..10).to_a)
      expect(payload.fetch('markdown')).not_to include('Hidden account destination', '/account/')
      expect(payload.fetch('warnings')).to include('url_content_mismatch')
      expect(payload.fetch('warnings')).not_to include('empty_extraction', 'short_extraction')
    end
  end

  it 'does not recover hidden material when the reader already owns a link' do
    with_url_page('https://workspace.example/platform/overview', hidden_main_fixture(current_link: true)) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).to include('Read the current guide')
      expect(payload.fetch('markdown')).not_to include('Capability group 1', '/capability/')
    end
  end

  it 'does not recover from ambiguous semantic main owners' do
    second_main = <<~HTML
      <main><h1>Secondary application surface</h1>
        <p>This separately owned surface must keep the hidden recovery boundary ambiguous.</p>
      </main>
    HTML

    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(extra_main: second_main)
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability group 1', '/capability/')
    end
  end

  it 'rejects hidden material without enough independent records' do
    with_url_page('https://workspace.example/platform/overview', hidden_main_fixture(hidden_count: 2)) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability group 1', '/capability/')
    end
  end

  it 'rejects hidden access templates inside the semantic main' do
    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(unsafe_class: 'post-login-template')
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects nested access templates inside recovered hidden material' do
    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(nested_unsafe_class: 'postLoginTemplate')
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects short independently hidden access templates' do
    short_template = '<div class="post-login-template" style="display: none">Sign in</div>'

    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(main_extra: short_template)
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects independently accessibility-hidden material' do
    hidden_account = '<section aria-hidden="true">Hidden account-only workspace content</section>'

    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(main_extra: hidden_account)
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects nested inert material inside a recovered hidden root' do
    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(nested_unsafe_attribute: 'inert')
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects unsafe semantic main ownership' do
    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(main_class: 'privacyDraft')
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects accessibility-hidden semantic main ownership' do
    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(main_attribute: 'inert')
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'rejects semantic main inside accessibility-hidden ownership' do
    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(main_wrapper_attribute: 'aria-hidden="true"')
    ) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'does not recover hidden material from a paywalled document' do
    paywall = '<meta property="article:content_tier" content="locked">'

    with_url_page('https://workspace.example/platform/overview', hidden_main_fixture(head: paywall)) do |page|
      payload = extract_with_narrow_reader(page)

      expect(payload['readerMode']).to be(true)
      expect(payload['paywallState']).to eq('detected')
      expect(payload.fetch('markdown')).not_to include('Capability record 1', '/capability/')
    end
  end

  it 'requires the visible main to own the reader content' do
    detached_reader = <<~JS.strip
      (() => {
        const root = document.createElement('article');
        root.innerHTML = '<h1>Independent reader report</h1>' +
          '<p>This independently generated reader copy occurs only inside hidden semantic-main material.</p>';
        return root;
      })()
    JS

    with_url_page(
      'https://workspace.example/platform/overview',
      hidden_main_fixture(hidden_reader_copy: true)
    ) do |page|
      payload = extract_with_narrow_reader(page, root_expression: detached_reader)

      expect(payload['readerMode']).to be(true)
      expect(payload.fetch('markdown')).to include('independently generated reader copy')
      expect(payload.fetch('markdown')).not_to include('Capability group 1', '/capability/')
    end
  end
end
