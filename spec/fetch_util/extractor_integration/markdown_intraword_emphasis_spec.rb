# frozen_string_literal: true

RSpec.describe 'FetchUtil intraword emphasis rendering' do
  include_context 'extractor integration helpers'

  def emphasis_markdown_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.renderEmphasisProbe = function(html) { return markdownFor(html, false, true, true); };
      })(window);
    JAVASCRIPT
  end

  def emphasis_markdowns(fragments)
    with_url_page('https://publication.example.test/emphasis', '<main>Emphasis rendering probe</main>') do |page|
      source = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: false)
      page.add_script_tag(content: emphasis_markdown_source)
      markdowns = page.evaluate("#{JSON.generate(fragments)}.map(renderEmphasisProbe)")
      expect(page.evaluate('document.body.outerHTML')).to eq(source)
      markdowns
    end
  end

  it 'uses valid intraword delimiters for modifier letters and ordinary Unicode words' do
    samples = {
      '<p>ʿ<em>Aba</em>ʾat al-Maqam</p>' => 'ʿ*Aba*ʾat al-Maqam',
      '<p><em>Dima</em>ʾ ʿala Wajh al-Qamar</p>' => '*Dima*ʾ ʿala Wajh al-Qamar',
      '<p>Al-Ta<em>ʾ</em>ir al-Abyad</p>' => 'Al-Ta*ʾ*ir al-Abyad',
      '<p>un<em>break</em>able</p>' => 'un*break*able',
      '<p>東京<i>大学</i>研究</p>' => '東京*大学*研究',
      '<p>é<em>clair</em>s</p>' => 'é*clair*s',
      '<p>2<em>nd</em>3</p>' => '2*nd*3'
    }
    expect(emphasis_markdowns(samples.keys)).to eq(samples.values)
  end

  it 'keeps adjacent pure emphasis as a complete run without literal delimiter artifacts' do
    samples = {
      '<p><em>ʿ</em><em>Aba</em><em>ʾ</em><em>at al-Maqam</em></p>' => '_ʿAbaʾat al-Maqam_',
      '<p><em>Dima</em><em>ʾ</em> <em>ʿ</em><em>ala Wajh al-Qamar</em></p>' => '_Dimaʾ_ _ʿala Wajh al-Qamar_',
      '<p>un<em>break</em><em>able</em>ness</p>' => 'un*breakable*ness',
      '<p><i>東京</i><i>大学</i></p>' => '_東京大学_',
      '<p><em>first</em> <em>second</em></p>' => '_first_ _second_',
      '<pre><code><em>left</em><em>right</em></code></pre>' => "```\nleftright\n```"
    }
    expect(emphasis_markdowns(samples.keys)).to eq(samples.values)
  end

  it 'reads inline boundary text without crossing paragraphs or deleting punctuation and code' do
    samples = {
      '<p>ʿ<span><em>Aba</em></span>ʾ</p>' => 'ʿ*Aba*ʾ',
      '<p>un<!-- inline boundary --><i>break</i><!-- inline boundary -->able</p>' => 'un*break*able',
      '<p>Before</p><p><em>ordinary</em></p><p>After</p>' => "Before\n\n_ordinary_\n\nAfter",
      '<p>(<em>ordinary</em>), <i>another</i> word.</p>' => '(_ordinary_), _another_ word.',
      '<p><a href="https://publication.example.test/edition">Edition</a><em>.</em></p>' => '[Edition](https://publication.example.test/edition)_._',
      '<p>Before<br><em>ordinary</em><br>After</p>' => "Before  \n_ordinary_  \nAfter",
      '<p><code>ʿ_Aba_ʾ</code> and <em>ordinary</em></p>' => '`ʿ_Aba_ʾ` and _ordinary_',
      '<pre><code>ʿ_Aba_ʾ\nun_break_able</code></pre>' => "```\nʿ_Aba_ʾ\\nun_break_able\n```"
    }
    expect(emphasis_markdowns(samples.keys)).to eq(samples.values)
  end
end
