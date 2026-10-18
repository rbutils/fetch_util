# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil extractor empty markdown link cleanup' do
  include_context 'extractor integration helpers'

  [true, false].each do |hidden|
    it "preserves a block boundary with #{hidden ? "hidden" : "visible"} supporting resources" do
      visibility = hidden ? 'style="display:none"' : ''
      resources = <<~HTML
        <a href="/tracking-placeholder" #{visibility}></a>
        <img src="/image-placeholder.png" alt="" #{visibility}>
        <img src="/image-placeholder.png" alt="" #{visibility}>
        <details><summary>Supporting details</summary><img src="/closed-support.png" alt=""></details>
        <button><img src="/interface-only.png" alt="">Open controls</button>
      HTML
      records = (1..8).map do |number|
        <<~HTML
          <article>
            <h3><a href="/stories/#{number}">Independent report number #{number}</a></h3>
            <p>Locally owned context for independent report number #{number}.</p>
            #{resources if number == 4}
          </article>
        HTML
      end
      html = <<~HTML
        <html><head><title>Daily reports</title></head><body><main>
          <h1>Daily reports</h1>
          <section><h2>Morning desk</h2>#{records.take(4).join}</section>
          <section><h2>Culture desk</h2>#{records.drop(4).join}</section>
        </main></body></html>
      HTML

      with_url_page('https://newsroom.example/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page, reader_mode: false)
        markdown = payload.fetch('markdown')
        public_root = Nokogiri::HTML5.fragment(payload.fetch('html'))

        expect(markdown).to include("\n\n## Culture desk\n\n- [Independent report number 5")
        expect(markdown).not_to include('- ## Culture desk')
        expect(markdown).to include('Supporting details')
        expect(markdown).not_to include('closed-support.png', 'interface-only.png')
        (1..8).each do |number|
          expect(markdown).to include("Independent report number #{number}", "Locally owned context for independent report number #{number}.")
        end
        if hidden
          expect(markdown).not_to include('tracking-placeholder', 'image-placeholder')
          expect(public_root.css('a[href$="/tracking-placeholder"], img[src$="/image-placeholder.png"]')).to be_empty
        else
          expect(markdown.scan(%r{\]\(https://newsroom\.example/tracking-placeholder\)}).size).to eq(1)
          expect(public_root.css('a[href="https://newsroom.example/tracking-placeholder"]').size).to eq(1)
          expect(public_root.css('img[src="https://newsroom.example/image-placeholder.png"][alt=""]').size).to eq(2)
          expect(markdown.scan('![](https://newsroom.example/image-placeholder.png)').size).to eq(2)
        end
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end
end
