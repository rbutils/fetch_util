RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  it 'preserves repeated quoted paragraphs, references, and boundaries after quoted lists' do
    repeated = (1..5).map do |number|
      <<~HTML
        <p>Repeat the <a href="/manual/">manual</a> instructions.</p>
        <p>Unique quoted paragraph #{number} has its own complete source value.</p>
      HTML
    end.join
    html = <<~HTML
      <html>
        <head><title>Quoted procedure</title><meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.1"></head>
        <body><main><article class="md-content__inner">
          <h1>Quoted procedure</h1>
          <p>Every repeated instruction and every source paragraph boundary remains meaningful.</p>
          <blockquote>
            <p>Quoted procedure introduction.</p>
            #{repeated}
            <ul><li>First quoted item.</li><li>Second quoted item.</li></ul>
            <p>This paragraph follows the list.</p>
            <p>This final quoted paragraph remains separate.</p>
          </blockquote>
        </article></main></body>
      </html>
    HTML

    with_url_page('https://docs.publication.example.test/guide/quoted-procedure/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      source_paragraphs = page.evaluate('Array.from(document.querySelectorAll("blockquote p")).map(function(node) { return node.textContent; })')
      payload = extract(page)
      actual_paragraphs = page.evaluate(<<~JS)
        (function() {
          var root = document.createElement("div");
          root.innerHTML = #{JSON.generate(payload.fetch("html"))};
          return Array.from(root.querySelectorAll("blockquote p")).map(function(node) { return node.textContent; });
        })()
      JS

      expect(actual_paragraphs).to eq(source_paragraphs)
      markdown = payload.fetch('markdown')
      expect(markdown.scan('[manual](https://docs.publication.example.test/manual/)').length).to eq(5)
      expect(markdown).to match(/> Quoted procedure introduction\.\n>[ \t]*\n> Repeat the/)
      expect(markdown).to match(
        /> This paragraph follows the list\.\n>[ \t]*\n> This final quoted paragraph remains separate\./
      )
      expect(markdown).to match(/> [-+*][ \t]{1,4}Second quoted item\.\n>[ \t]*\n> This paragraph follows the list\./)
      (1..5).each do |number|
        expect(markdown).to include("> Unique quoted paragraph #{number} has its own complete source value.")
      end
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
