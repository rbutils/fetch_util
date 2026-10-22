# frozen_string_literal: true

require 'cgi'

RSpec.describe 'Physical article preview images' do
  include_context 'extractor integration helpers'

  def preview_article(fragment, generator: '')
    program = 'const example = \'<input type="image" src="/literal-program.png">\';'
    [<<~HTML, program]
      <!doctype html><html><head><title>Published visualization</title>
      <meta name="generator" content="#{generator}"><meta property="og:type" content="article">
      <link rel="canonical" href="https://publication.example.test/visualization/"></head><body>
      <form id="external-submission"><input type="text" name="query"></form>
      <article class="entry-content"><h1>Published visualization</h1>
        <p>The publication explains these independent visual resources alongside the complete written method.
        Every displayed preview is part of the authored explanation, and the gallery remains closed.</p>
        <h2>Observed figures</h2>#{fragment}
        <p>Keep the <a href="/written-method">written method</a> and every literal program value.</p>
        <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
        <h2>Conclusion</h2><p>The final observation follows every visible image and the complete program.</p>
      </article></body></html>
    HTML
  end

  [
    ['Bootstrap', 'data-bs-toggle="modal" data-bs-target="#gallery"', ''],
    ['ARIA', 'aria-haspopup="dialog" aria-controls="gallery"', 'WordPress 6.9']
  ].each do |name, controls, generator|
    it "retains independent visible #{name} previews in source order without opening the gallery" do
      fragment = <<~HTML
        <div title="Published figures">
          <div style="display:none"><input type="image" src="/hidden-input.png" #{controls}></div>
          <div><input type="image" src="/figure.png" #{controls}></div>
          <p>The independent inline figure follows the first preview.</p>
          <img src="/figure.png" alt="Independent inline figure">
          <p>The second preview is a separate physical occurrence.</p>
          <div><input type="image" src="/figure.png" alt="Second preview" #{controls}></div>
          <div id="gallery" role="dialog" aria-hidden="true" style="display:none">
            <h2>Closed gallery title</h2><img src="/figure.png" alt="Hidden gallery label">
            <img src="/hidden-input.png" alt="Hidden input match">
            <img src="/gallery-only.png" alt="Hidden additional figure"><button>Close gallery</button>
          </div>
        </div>
      HTML
      html, program = preview_article(fragment, generator: generator)
      with_url_page('https://publication.example.test/visualization/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        result = extract_payload(page)
        native = Nokogiri::HTML5.fragment(result.fetch('html'))
        expected_images = [
          ['https://publication.example.test/figure.png', ''],
          ['https://publication.example.test/figure.png', 'Independent inline figure'],
          ['https://publication.example.test/figure.png', 'Second preview']
        ]
        expect(native.css('img').map { |image| [image['src'], image['alt'].to_s] }).to eq(expected_images)
        expect(native.css('h2').map(&:text)).to eq(['Observed figures', 'Conclusion'])
        expect(native.css('pre').map(&:text)).to eq([program])
        markdown = result.fetch('markdown')
        images = markdown.scan(%r{!\[[^\]]*\]\(https://publication\.example\.test/figure\.png\)})
        expected_markdown = [
          '![](https://publication.example.test/figure.png)',
          '![Independent inline figure](https://publication.example.test/figure.png)',
          '![Second preview](https://publication.example.test/figure.png)'
        ]
        expect(images).to eq(expected_markdown)
        ordered = [
          images[0], 'The independent inline figure follows the first preview.', images[1],
          'The second preview is a separate physical occurrence.', images[2]
        ]
        positions = ordered.map { |value| markdown.index(value) }
        expect(positions).not_to include(nil)
        expect(positions).to eq(positions.sort)
        expect(markdown).to include(program, '[written method](https://publication.example.test/written-method)')
        expect(markdown).not_to include('Closed gallery title', 'Hidden gallery label', '/gallery-only.png', '/hidden-input.png')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'excludes form and interface controls, hidden peers, unmatched and ambiguous targets' do
    attributes = 'type="image" src="/rejected.png" aria-haspopup="dialog" aria-controls="gallery"'
    controls = [
      "<form><input #{attributes}></form>",
      "<input #{attributes} form=\"external-submission\">",
      "<nav><input #{attributes}></nav>",
      "<aside><input #{attributes}></aside>",
      "<footer><input #{attributes}></footer>",
      "<div role=\"menu\"><input #{attributes}></div>",
      "<div role=\"dialog\"><input #{attributes}></div>",
      "<details><summary>Closed preview</summary><input #{attributes}></details>",
      "<input #{attributes} hidden>",
      "<div style=\"opacity:0\"><input #{attributes}></div>",
      '<input type="image" src="/rejected.png">',
      '<input type="image" src="/unmatched.png" aria-haspopup="dialog" aria-controls="gallery">',
      '<input type="image" src="/rejected.png" aria-haspopup="dialog" aria-controls="duplicate">',
      '<input type="image" src="/rejected.png" aria-haspopup="dialog" aria-controls="missing">',
      '<input type="image" src="javascript:void(0)" aria-haspopup="dialog" aria-controls="gallery">',
      "<input #{attributes} data-bs-toggle=\"modal\" data-bs-target=\"#duplicate\">",
      "<input #{attributes} formaction=\"/submission\">"
    ].join
    hidden = <<~HTML
      <div id="gallery" role="dialog" hidden><img src="/rejected.png" alt="Hidden gallery image"></div>
      <div id="duplicate" role="dialog" hidden><img src="/rejected.png" alt="First ambiguous image"></div>
      <div id="duplicate" role="dialog" hidden><img src="/rejected.png" alt="Second ambiguous image"></div>
    HTML
    html, program = preview_article(controls + hidden)
    with_url_page('https://publication.example.test/visualization/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract_payload(page)
      native = Nokogiri::HTML5.fragment(result.fetch('html'))
      expect(native.css('img')).to be_empty
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(result.fetch('markdown')).to include(program, 'The final observation follows every visible image and the complete program.')
      expect(result.fetch('markdown')).not_to include('/rejected.png', '/unmatched.png', 'Hidden gallery image')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
