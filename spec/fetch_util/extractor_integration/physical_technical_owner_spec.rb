# frozen_string_literal: true

RSpec.describe 'FetchUtil complete physical technical-document owners' do
  include_context 'extractor integration helpers'

  def technical_owner_page(body, title: 'Closure reference', attributes: '')
    <<~HTML
      <html><head><title>#{title}</title><meta property="og:title" content="#{title}"></head><body>
      <nav><a href="/navigation-control">Site navigation</a></nav><main #{attributes}><header><h1>#{title}</h1></header>
      #{body}</main><footer><p>Unrelated global footer.</p></footer></body></html>
    HTML
  end

  def technical_owner_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.hasPhysicalTechnicalOwner = function() { return !!physicalTechnicalDocsContext({title: document.title}); };
      })(window);
    JAVASCRIPT
  end

  def declared_technical_body
    <<~HTML
      <article itemscope itemtype="https://schema.org/TechArticle"><div itemprop="articleBody">
      <h2>Lexical environments</h2><p>Published instruction explains independent closure bindings and the complete source records.</p>
      <pre><code class="language-javascript">const binding = {value: 1};</code></pre>
      </div></article>
    HTML
  end

  it 'keeps every authored exercise beyond the nested declared article in both output forms' do
    exercises = (1..160).map do |number|
      <<~HTML
        <section id="exercise-#{number}"><h3>Published exercise #{number}</h3>
        <p>The complete task #{number} documents an independent binding and its source-backed solution.</p>
        <pre><code class="language-javascript">const solution#{number} = () =&gt; #{number};</code></pre>
        <p>Source resource <a href="/resources/#{number}">resource #{number}</a> explains the published example.</p></section>
      HTML
    end.join
    quote = '<blockquote><p>The author discusses subscription privacy in this independently published quotation.</p></blockquote>'
    replies = <<~HTML
      <section id="comments"><h2>Published replies</h2><article class="comment" itemscope itemtype="https://schema.org/Comment">
      <p>A published reader explains the independent closure result with <a href="/replies/source">its source reference</a>.</p>
      <blockquote><p>The quoted reply retains its complete explanation and published context.</p></blockquote></article></section>
    HTML
    body = "#{declared_technical_body}<section><h2>Exercises</h2>#{exercises}#{quote}</section>#{replies}"
    html = technical_owner_page(body, title: 'Lexical bindings')
           .sub('<body>', '<body><div class="page_sidebar_on"><aside>Unrelated sibling navigation.</aside>').sub('</body>', '</div></body>')
    extract_from_url('https://publication.example.test/tutorial/bindings#exercise-1', html) do |payload|
      (1..160).each do |number|
        expect(payload['html']).to include("Published exercise #{number}", "solution#{number}", "/resources/#{number}")
        expect(payload['markdown']).to include("Published exercise #{number}", "const solution#{number} = () => #{number};", "/resources/#{number}")
      end
      expect(payload['markdown']).to include('Lexical bindings', 'subscription privacy', 'Lexical environments')
      expect(payload['markdown']).not_to include('Unrelated global footer', 'navigation-control')
      expect(payload['markdown']).not_to include('Unrelated sibling navigation')
      expect(payload['markdown']).to include('A published reader explains', '/replies/source', 'The quoted reply retains')
    end
  end

  it 'renders an identified reference manual without a generator and keeps every section and literal example' do
    sections = (1..180).map do |number|
      <<~HTML
        <section><h2>Reference section #{number}</h2><p>Complete manual instruction #{number} preserves its published source prose.</p>
        <div class="highlight"><pre>value#{number} = transform(#{number})</pre></div></section>
      HTML
    end.join
    html = technical_owner_page(sections, title: 'Language reference manual')
    extract_from_url('https://publication.example.test/reference/manual', html) do |payload|
      (1..180).each do |number|
        expect(payload['html']).to include("Reference section #{number}", "value#{number} = transform(#{number})")
        expect(payload['markdown']).to include("Reference section #{number}", "value#{number} = transform(#{number})")
      end
    end
  end

  it 'keeps source-hidden descendants hidden while preserving visible technical material' do
    body = <<~HTML
      #{declared_technical_body}
      <section hidden><h2>Hidden solution</h2><pre><code class="language-text">Hidden literal</code></pre></section>
      <p style="display:none">Hidden authored explanation.</p><p>Visible supplemental explanation.</p>
    HTML
    extract_from_url('https://publication.example.test/tutorial/bindings', technical_owner_page(body, title: 'Lexical bindings')) do |payload|
      expect(payload['html']).to include('Visible supplemental explanation', 'const binding')
      expect(payload['markdown']).to include('Visible supplemental explanation', 'const binding')
      expect(payload['html']).not_to include('Hidden solution', 'Hidden literal', 'Hidden authored explanation')
      expect(payload['markdown']).not_to include('Hidden solution', 'Hidden literal', 'Hidden authored explanation')
    end
  end

  it 'declines hidden, duplicate, conflicting and nontechnical physical owners' do
    valid = technical_owner_page(declared_technical_body, title: 'Lexical bindings')
    cases = [
      valid.sub('<main >', '<main hidden>'),
      valid.sub('</main>', '</main><main><h1>Other owner</h1></main>'),
      valid.sub('<title>Lexical bindings</title>', '<title>Foreign reporting identity</title>'),
      valid.sub('https://schema.org/TechArticle', 'https://schema.org/Article'),
      valid.sub('class="language-javascript"', ''),
      valid.sub('<main >', '<aside><main >').sub('</main>', '</main></aside>'),
      valid.sub('<main >', '<main class="sidebar">'),
      valid.sub('</article>', '</article><article itemscope itemtype="https://schema.org/TechArticle"><p>Other declaration</p></article>')
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/tutorial/bindings', html) do |page|
        page.add_script_tag(content: technical_owner_source)
        expect(page.evaluate('hasPhysicalTechnicalOwner()')).to be false
      end
    end
  end

  it 'does not request visibility or overflow evidence for an ineligible physical owner' do
    records = (1..200).map do |number|
      "<section><h2>Published record #{number}</h2><p>Complete record #{number} remains materialized.</p></section>"
    end.join
    html = technical_owner_page(records, title: 'Published records').sub('<h1>Published records</h1>', '')
    with_url_page('https://publication.example.test/records', html) do |page|
      page.add_script_tag(content: technical_owner_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = window.getComputedStyle;
          const before = document.body.innerHTML;
          let styleRequests = 0;
          window.getComputedStyle = function() { styleRequests += 1; return original.apply(this, arguments); };
          try {
            return { owned: hasPhysicalTechnicalOwner(), styleRequests: styleRequests, unchanged: before === document.body.innerHTML };
          } finally { window.getComputedStyle = original; }
        })()
      JAVASCRIPT
      expect(result).to eq('owned' => false, 'styleRequests' => 0, 'unchanged' => true)
    end
  end
end
