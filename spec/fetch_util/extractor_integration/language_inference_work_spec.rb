# frozen_string_literal: true

RSpec.describe 'FetchUtil complete language inference' do
  include_context 'extractor integration helpers'

  def language_probe_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.languageWorkProbe = function(sample) {
        document.documentElement.setAttribute('lang', sample.html || '');
        document.head.querySelectorAll('meta').forEach(function(node) { node.remove(); });
        [['property','og:locale',sample.og], ['http-equiv','Content-Language',sample.header]].forEach(function(field) {
          if (!field[2]) return;
          var node = document.createElement('meta');
          node.setAttribute(field[0], field[1]); node.content = field[2]; document.head.appendChild(node);
        });
        var reads = 0;
        Object.defineProperty(document.body, 'innerText', {
          configurable:true, get:function() { reads++; return sample.text; }
        });
        try { return {language:documentLanguage(), reads:reads}; }
        finally { delete document.body.innerText; }
      };
      })(window);
    JAVASCRIPT
  end

  def language_results(samples)
    with_url_page('https://publication.example.test/language', '<main>Language evidence</main>') do |page|
      page.add_script_tag(content: language_probe_source)
      page.evaluate("#{JSON.generate(samples)}.map(languageWorkProbe)")
    end
  end

  it 'does not inspect full text when declarations already determine the original result' do
    samples = [
      { html: 'es-MX' }, { og: 'pt_BR' }, { header: 'fr-CA, en' },
      { html: 'en-US', og: 'en_GB' }, { html: 'eng', header: 'de' }
    ].map { |sample| sample.merge(text: 'neutral evidence ' * 2_000) }
    expect(language_results(samples)).to eq(%w[es pt fr en en].map { |code| { 'language' => code, 'reads' => 0 } })
  end

  it 'retains full visible-text evidence for conflicting declarations and absent valid metadata' do
    spanish = 'El barrio y la biblioteca abren para los estudiantes con talleres de lectura por la tarde. ' * 20
    english = 'The library and the community have more books for their students and will open with volunteers. ' * 20
    samples = [
      { html: 'es', og: 'en_US', text: spanish },
      { html: 'es', og: 'en_US', text: english },
      { html: 'invalid', og: 'invalid', header: 'invalid', text: spanish },
      { html: 'th', og: 'en_US', text: 'ห้องสมุดชุมชนเปิดให้บริการทุกวันสำหรับนักเรียนและครอบครัวในพื้นที่' * 10 }
    ]
    expect(language_results(samples)).to eq(%w[es en es th].map { |code| { 'language' => code, 'reads' => 1 } })
  end

  it 'counts repeated and overlapping words throughout complete input rather than sampling its prefix' do
    neutral = 'identifier value token constructor prototype ' * 2_000
    shared = 'que con para como ' * 20
    samples = [
      { text: neutral + shared + ('el la los las ' * 80) },
      { text: neutral + shared + ('dos das uma são ' * 80) },
      { text: neutral + ('the and that for ' * 80) },
      { text: neutral + ('el la los las dos das uma são ' * 80) }
    ]
    expect(language_results(samples)).to eq(['es', 'pt', 'en', nil].map { |code| { 'language' => code, 'reads' => 1 } })
  end
end
