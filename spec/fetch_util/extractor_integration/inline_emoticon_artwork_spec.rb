# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Inline emoticon artwork cleanup' do
  include_context 'extractor integration helpers'

  def extract_owned_article(page)
    extractor_for(true).__send__(:inject_assets, page)
    page.evaluate <<~JS
      (() => {
        const Reader = function() {};
        Reader.prototype.parse = function() {
          const article = document.querySelector('main article');
          return {title: 'Public field report', content: article.outerHTML,
            textContent: article.textContent};
        };
        window.Readability = Reader;
        return window.FetchUtilExtract.extract({reader_mode: true});
      })()
    JS
  end

  it 'keeps all body prose and independent images while omitting inline pictogram assets' do
    html = <<~HTML
      <html><body><main><article><h1>Public field report</h1>
        <p><img src="/images/emoji/cheer.png" alt="Cheer">The opening report explains the verified findings and their impact.</p>
        <p><img src="/images/emoticon/orange.png" alt="Orange">A second paragraph explains the findings in more detail.</p>
        <figure><img src="/images/emoji/evidence.png" alt="Evidence photograph"><figcaption>Evidence remains visible.</figcaption></figure>
        <p>The closing paragraph summarizes further context for readers.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://reports.example/field-report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_owned_article(page)

      expect(payload.fetch('markdown')).to include(
        'The opening report explains', 'A second paragraph explains',
        'The closing paragraph summarizes', 'Evidence photograph', 'Evidence remains visible'
      )
      expect(payload.fetch('markdown')).not_to include('![Cheer]', '![Orange]')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains substantive inline media without an emoticon-path proof' do
    html = <<~HTML
      <html><body><main><article><h1>Public field report</h1>
        <p><img src="/images/evidence.png" alt="Evidence chart">The accompanying chart documents the reported measurements.</p>
        <p>The article continues with independent evidence and full contextual explanation for readers.</p>
        <p>The final paragraph identifies the source and publication timeline.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://reports.example/field-report', html) do |page|
      payload = extract_owned_article(page)

      expect(payload.fetch('markdown')).to include('![Evidence chart](https://reports.example/images/evidence.png)')
    end
  end
end
