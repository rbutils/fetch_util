# frozen_string_literal: true

RSpec.describe 'Complete source-owned article title' do
  include_context 'extractor integration helpers'

  let(:document_html) do
    <<~HTML
      <html><head><title>Public observation register</title></head><body>
        <div><h1>INDEPENDENT PUBLICATION</h1></div>
        <main><article><header><h2>Public observation register</h2></header>
          <table><thead><tr><th>Record</th><th>Evidence</th></tr></thead><tbody>
            <tr><td>First observation</td><td><a href="/records/first">Complete first record</a></td></tr>
            <tr><td>Second observation</td><td><a href="/records/second">Complete second record</a></td></tr>
          </tbody></table>
          <pre>value = "unchanged"\n  verify(value)</pre>
          <p>The register preserves every recorded observation and its complete supporting evidence.</p>
        </article></main>
      </body></html>
    HTML
  end

  it 'corrects an exterior reader title without changing the complete owned body' do
    with_url_page('https://publication.example.test/register', document_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const Reader = function() {};
          Reader.prototype.parse = function() {
            const owner = document.querySelector('article');
            return {title: 'INDEPENDENT PUBLICATION', content: owner.outerHTML, textContent: owner.textContent};
          };
          window.Readability = Reader;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS

      expect(payload.fetch('title')).to eq('Public observation register')
      expect(payload.fetch('html')).to include('<h2>Public observation register</h2>', 'Second observation')
      expect(payload.fetch('markdown')).to start_with("# Public observation register\n")
      expect(payload.fetch('markdown')).not_to include('INDEPENDENT PUBLICATION')
      expect(payload.fetch('markdown')).to include('[Complete first record](https://publication.example.test/records/first)')
      expect(payload.fetch('markdown')).to include('[Complete second record](https://publication.example.test/records/second)')
      expect(payload.fetch('markdown')).to include("value = \"unchanged\"\n  verify(value)")
      expect(payload.fetch('byline')).to be_nil
      expect(payload.fetch('publishedTime')).to be_nil
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'declines incomplete, hidden, ambiguous and conflicting source ownership' do
    cases = [
      ['partial selected body', '', "selected.querySelector('p').remove();"],
      ['hidden article header', "document.querySelector('article header').hidden = true;", ''],
      ['ambiguous articles', "document.querySelector('main').append(document.querySelector('article').cloneNode(true));", ''],
      ['conflicting declared title', "document.title = 'Another publication';", ''],
      ['conflicting social title', <<~JS, ''],
        const meta = document.createElement('meta');
        meta.setAttribute('property', 'og:title');
        meta.content = 'Another publication';
        document.head.append(meta);
      JS
      ['conflicting current article record', <<~JS, '']
        const record = document.createElement('script');
        record.type = 'application/ld+json';
        record.textContent = JSON.stringify({
          '@type': 'Article', url: location.href, headline: 'Another publication'
        });
        document.head.append(record);
      JS
    ]
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, 'websieve', entry))
    end.join("\n")
    probe_source = source.sub('})(window);', 'global.completeOwnedTitleProbe = articleTitleFromCompletePageHeading; })(window);')

    cases.each do |label, source_change, selected_change|
      with_url_page('https://publication.example.test/register', document_html) do |page|
        page.add_script_tag(content: probe_source)
        actual = page.evaluate <<~JS
          (() => {
            #{source_change}
            const selected = document.querySelector('article').cloneNode(true);
            #{selected_change}
            return completeOwnedTitleProbe({contentType: 'article'}, selected.outerHTML, 'INDEPENDENT PUBLICATION');
          })()
        JS
        expect(actual).to eq('INDEPENDENT PUBLICATION'), label
      end
    end
  end
end
