# frozen_string_literal: true

RSpec.describe 'Typed runtime detail arbitration' do
  include_context 'extractor integration helpers'

  def runtime_detail_html
    <<~HTML
      <html><head><title>Normal in 03:27.083 by Cartwell - Record host</title>
        <script id="__NEXT_DATA__" type="application/json">
          {"page":"/[game]/runs/[recordId]","props":{"pageProps":{
            "recordData":{"run":{"id":"zxrxolqz","comment":"Mod Note: Retimed with the complete timing evidence from the verified run."},
              "players":[{"name":"Cartwell"}]},
            "recentRunsData":{"runs":[{"id":"zxrxolqz","comment":"Mod Note: Retimed with the complete timing evidence from the verified run."}]}
          }}}
        </script>
      </head><body><main><div class="run-detail">
        <div>Normal in 03:27.083 by <span>Cartwell</span></div>
        <p>Mod Note: Retimed with the complete timing evidence from the verified run.</p>
        <a href="/runs/zxrxolqz">Current run record</a>
      </div><nav><a href="/leaderboards">Leaderboards</a></nav></main></body></html>
    HTML
  end

  def install_runtime_detail_probe(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, 'websieve', entry))
    end.join("\n")
    page.add_script_tag(
      content: source.sub('})(window);', 'global.runtimeDetailListLossProbe = sourceOwnedTypedRuntimeDetailListLoss; })(window);')
    )
  end

  it 'blocks a list takeover when a typed record note is omitted from the focal excerpt' do
    with_url_page('https://records.example/game/runs/zxrxolqz', runtime_detail_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      install_runtime_detail_probe(page)
      article = {
        contentType: 'article',
        html: '<div>Normal in 03:27.083 by Cartwell</div>' \
          '<p>Mod Note: Retimed with the complete timing evidence from the verified run.</p>'
      }
      list = {
        contentType: 'list',
        excerpt: 'Join for $3.99/month',
        markdown: '- [Join for $3.99/month](https://records.example/supporter)' \
          "\n\nMod Note: Retimed with the complete timing evidence from the verified run."
      }
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(true)
      page.evaluate("history.replaceState({}, '', '/different-game/runs/zxrxolqz')")
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'declines collection-only, mismatched-route, and list-preserving controls' do
    html = runtime_detail_html.sub('"recordData":{"run":{"id":"zxrxolqz",', '"recordData":{"run":{"id":"other-run",')
    with_url_page('https://records.example/game/runs/zxrxolqz', html) do |page|
      install_runtime_detail_probe(page)
      article = {
        contentType: 'article',
        html: '<div>Normal in 03:27.083 by Cartwell</div>' \
          '<p>Mod Note: Retimed with the complete timing evidence from the verified run.</p>'
      }
      list = { contentType: 'list', markdown: '- [Join for $3.99/month](https://records.example/supporter)' }
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(false)

      page.evaluate("history.replaceState({}, '', '/different-game/runs/zxrxolqz')")
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(false)

      page.evaluate("history.replaceState({}, '', '/game/leaderboards/zxrxolqz')")
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(false)

      page.evaluate("history.replaceState({}, '', '/game/runs/another-run')")
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(false)

      page.evaluate("history.replaceState({}, '', '/game/runs/zxrxolqz')")
      list_with_detail = list.merge(
        excerpt: 'Mod Note: Retimed with the complete timing evidence from the verified run.',
        markdown: "#{list[:markdown]}\n\nCartwell\nMod Note: Retimed with the complete timing evidence from the verified run."
      )
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list_with_detail)})")).to be(false)
    end
  end

  it 'ignores a parent banner omitted by the list when the identified run detail is retained' do
    banner = 'A separate donation banner for all users.'
    html = runtime_detail_html
           .sub('"recordData":{"run":', "\"recordData\":{\"bannerMessage\":\"#{banner}\",\"run\":")
           .sub('<main><div class="run-detail">', "<main><div class=\"banner\">#{banner}</div><div class=\"run-detail\">")
    article = {
      contentType: 'article',
      html: "<div>#{banner}</div><div>Normal in 03:27.083 by Cartwell</div>" \
        '<p>Mod Note: Retimed with the complete timing evidence from the verified run.</p>'
    }
    list = {
      contentType: 'list',
      excerpt: 'Mod Note: Retimed with the complete timing evidence from the verified run.',
      markdown: '- [Join for $3.99/month](https://records.example/supporter)' \
        "\n\nNormal in 03:27.083 by Cartwell\nMod Note: Retimed with the complete timing evidence from the verified run."
    }

    with_url_page('https://records.example/game/runs/zxrxolqz', html) do |page|
      install_runtime_detail_probe(page)
      expect(page.evaluate("runtimeDetailListLossProbe(#{JSON.generate(article)}, #{JSON.generate(list)})")).to be(false)
    end
  end
end
