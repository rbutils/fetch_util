require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def description_links_markdown(html)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source = source.sub("})(window);", "global.__descriptionParts = listDescriptionParts; " \
                                         "global.__visibleListClone = visibleListClone; })(window);")
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: source)
      page.evaluate(<<~JS)
        (() => {
          const root = __visibleListClone(document.querySelector('main'));
          const items = [{ text: 'An independently accepted record', url: 'https://research.example/record' }];
          return __descriptionParts(root, items, { preserveTextLengths: true }).map(part => part.markdown);
        })()
      JS
    end
  end

  it "preserves every inline description destination in DOM order, including table prose" do
    rows = 125.times.map do |index|
      "<tr><td><p>Read the <a href='/reference/#{index}'>reference #{index}</a> before using this dataset.</p></td></tr>"
    end.join
    actual = description_links_markdown("<html><body><main><table>#{rows}</table></main></body></html>")
    expect(actual).to eq(125.times.map do |index|
      "Read the [reference #{index}](https://research.example/reference/#{index}) before using this dataset."
    end)
  end

  it "preserves labels without emitting unsafe or hidden destinations" do
    html = <<~HTML
      <html><body><main>
      <p>This explanation keeps an <a href='https://user:secret@example.net/private'>unsafe destination</a>
      and a <a href='javascript:void(0)'>local action</a> as ordinary readable labels.</p>
      <p>Read the <a href='https://docs.example/guide'>public guide</a> for the complete documented procedure.</p>
      <p hidden>Hidden <a href='https://hidden.example/guide'>documentation</a> must remain excluded.</p>
      </main></body></html>
    HTML
    actual = description_links_markdown(html)
    expect(actual).to eq([
                           "This explanation keeps an unsafe destination and a local action as ordinary readable labels.",
                           "Read the [public guide](https://docs.example/guide) for the complete documented procedure."
                         ])
  end
end
