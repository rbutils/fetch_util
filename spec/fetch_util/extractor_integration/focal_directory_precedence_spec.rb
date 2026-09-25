# frozen_string_literal: true

RSpec.describe "FetchUtil focal article directory precedence" do
  include_context "extractor integration helpers"

  it "keeps hidden, sidebar and related record groups from displacing an owned article" do
    url = "https://example.test/news/directory-introduction?q=updates"
    records = 10.times.map do |index|
      %(<article><h2><a href="/directory/#{index}">Independent record #{index} with a distinct destination</a></h2></article>)
    end.join
    groups = [
      %(<section hidden><h2>Complete directory</h2>#{records}</section>),
      %(<aside><h2>Complete directory</h2>#{records}</aside>),
      %(<section class="related-stories"><h2>More records</h2>#{records}</section>),
      %(<section><h2>Related articles</h2>#{records}</section>)
    ]
    prose = 3.times.map do |index|
      %(<p>Source article paragraph #{index} contains independently reported details about the public investigation, its findings and the next steps for residents.</p>)
    end.join

    groups.each do |group|
      html = <<~HTML
        <html><head><title>Directory introduction</title>
          <link rel="canonical" href="#{url}">
          <script type="application/ld+json">{"@type":"NewsArticle","url":"#{url}","headline":"Directory introduction"}</script>
        </head><body><main>
          <article><h1>Directory introduction</h1>#{prose}</article>
          #{group}
        </main></body></html>
      HTML

      extract_from_url(url, html) do |payload|
        expect(payload.fetch("contentType")).to eq("article")
        expect(payload.fetch("markdown")).to include("Source article paragraph 0", "Source article paragraph 2")
      end
    end
  end
end
