# frozen_string_literal: true

RSpec.describe "generic article audio-control cleanup" do
  include_context "extractor integration helpers"

  def article_with_audio_widgets(widgets)
    body = Array.new(4) do |index|
      "<p>Article paragraph #{index} preserves detailed reporting, source context, and enough substantive prose for stable reader extraction.</p>"
    end.join
    "<article><h1>Public investigation</h1>#{widgets}<div class='article-body'>#{body}</div></article>"
  end

  def cleaned_article_widgets(html, source_html: "<main>Unchanged source page</main>")
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__cleanArticleWidgets = function(input) {
        var root = document.createElement("div");
        root.innerHTML = input;
        stripArticleWidgets(root);
        return root.innerHTML;
      };
    JS

    with_page(source_html) do |page|
      before = page.evaluate("document.body.innerHTML")
      page.add_script_tag(content: source)
      result = page.evaluate("window.__cleanArticleWidgets(#{JSON.generate(html)})")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      result
    end
  end

  it "removes only source-proven save and listen prompts transformed into article paragraphs" do
    body = (1..4).map do |index|
      "<p>Public reporting paragraph #{index} preserves the full account, independently reported details, and a complete source-owned explanation.</p>"
    end.join
    source_html = <<~HTML
      <article id="report"><h1>Public investigation</h1>
        <div class="save-article">Uložiť článok</div>
        <div class="beyondwords-player">Listen to this article 6 min</div>
        <p>Visible introduction remains part of the article.</p>#{body}
      </article>
    HTML
    selected = <<~HTML
      <article id="report"><h1>Public investigation</h1>
        <p>Uložiť článok</p><p>Listen to this article 6 min</p>
        <p>Visible introduction remains part of the article.</p>#{body}
      </article>
    HTML

    cleaned = cleaned_article_widgets(selected, source_html: source_html)
    expect(cleaned).not_to include("Uložiť článok", "Listen to this article 6 min")
    expect(cleaned).to include("Visible introduction", "Public reporting paragraph 1", "Public reporting paragraph 4")
  end

  it "removes a coherent group of compact article actions without removing reporting or media" do
    body = (1..4).map do |index|
      "<p>Reported paragraph #{index} preserves independently verified details, substantial public context, and the complete factual account for readers.</p>"
    end.join
    source_html = <<~HTML
      <article><h1>Public investigation</h1>
        <p>Show article summary</p><p>Listen to this article</p><p>Share this article</p>
        <p><a href="/transcript">Read the complete transcript</a></p>
        <audio src="/interview.mp3" controls></audio>#{body}
      </article>
    HTML
    cleaned = cleaned_article_widgets(source_html, source_html: source_html)
    expect(cleaned).not_to include("Show article summary", "Listen to this article", "Share this article")
    expect(cleaned).to include("Reported paragraph 1", "Reported paragraph 4", "/transcript", "/interview.mp3")

    incomplete = source_html.sub("<p>Listen to this article</p>", "<p>The article explains how to listen to an interview.</p>")
    expect(cleaned_article_widgets(incomplete, source_html: incomplete)).to include("Show article summary", "Share this article")
  end

  it "keeps ordinary prose, ambiguous prompts and material audio owned by an article" do
    source_html = <<~HTML
      <article id="report"><h1>Audio accessibility report</h1>
        <p>Listen to this article 6 min</p>
        <div class="beyondwords-player">Listen to this article 6 min</div>
        <div class="save-article"><a href="/read-later">Save article</a></div>
        <div class="audio-player"><audio src="/recording.mp3"></audio>Listen to this story 5 min</div>
        <p>Save article</p><p>Independent editorial context remains material.</p>
      </article>
    HTML
    selected = <<~HTML
      <article id="report"><h1>Audio accessibility report</h1>
        <p>Listen to this article 6 min</p><p>Save article</p>
        <p>Independent editorial context remains material.</p>
      </article>
    HTML

    cleaned = cleaned_article_widgets(selected, source_html: source_html)
    expect(cleaned).to include("Listen to this article 6 min", "Save article", "Independent editorial context")
  end

  it "removes short localized audio control bars from article output without mutating the page" do
    widgets = <<~HTML
      <div class="audioStory__label-bar">Slušaj vest 05:47</div>
      <div data-component="audio-controls"><button>听新闻</button><span>04:21</span></div>
    HTML
    html = article_with_audio_widgets(widgets)

    with_url_page("https://news.example.test/investigation", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page)

      expect(payload["markdown"]).to include("Public investigation", "Article paragraph 3")
      expect(payload["markdown"]).not_to include("Slušaj vest", "听新闻", "05:47", "04:21")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "preserves media, transcripts, episode metadata, and unproved audio labels" do
    widgets = <<~HTML
      <p class="audio-player-label">Episode duration 05:47</p>
      <div class="audio-player-controls"><time datetime="PT5M47S">05:47</time></div>
      <div class="audio-player-controls"><span itemprop="duration">PT5M47S</span><span>05:47</span></div>
      <div class="audio-player-controls"><a href="/transcript">Read transcript 05:47</a></div>
      <div class="audio-player-controls"><audio controls src="/report.mp3"></audio><span>05:47</span></div>
      <section class="audio-player-card"><h2>Episode 27</h2><p>A complete interview transcript and episode summary remain material.</p></section>
      <div class="audio-player-controls"><label>Episode 42 05:47</label></div>
      <div class="audio-player-controls"><details><summary>Episode 43 05:47</summary></details></div>
      <div class="audio-player-controls"><episode-title>Episode 44 05:47</episode-title></div>
      <audio-player-controls>Episode 45 05:47</audio-player-controls>
      <div class="audio-player-controls"><address>Studio address 05:47</address></div>
      <div class="audio-player-controls"><cite>Source programme 05:47</cite></div>
      <div class="audio-player-controls"><svg><title>Waveform 05:47</title></svg></div>
      <div class="audio-player-controls"><canvas>Chart 05:47</canvas></div>
      <div class="audio-player-controls"><math><mtext>Formula 05:47</mtext></math></div>
      <div class="audio-player-controls"><select><option>Episode 46 05:47</option></select></div>
      <div class="audio-player-controls"><output>Episode output 05:47</output></div>
      <div class="audioStory__label-bar">Listen to this investigation</div>
      <div class="audio-player-controls"><button>Open transcript</button></div>
      <div class="audio-player-controls">Invalid duration 99:99</div>
    HTML

    cleaned = cleaned_article_widgets(article_with_audio_widgets(widgets))
    expect(cleaned).to include(
      "Episode duration 05:47",
      "Read transcript 05:47",
      "Episode 27",
      "Episode 42 05:47",
      "Episode 43 05:47",
      "Episode 44 05:47",
      "Episode 45 05:47",
      "Studio address 05:47",
      "Source programme 05:47",
      "Waveform 05:47",
      "Chart 05:47",
      "Formula 05:47",
      "Episode 46 05:47",
      "Episode output 05:47",
      "complete interview transcript",
      "Listen to this investigation",
      "Open transcript",
      "Invalid duration 99:99",
      "PT5M47S",
      "report.mp3"
    )
  end

  it "uses accessible control evidence inside an article-body owner" do
    short_text = "#{"x" * 154} 05:47"
    long_text = "#{"x" * 155} 05:47"
    html = <<~HTML
      <div itemprop="articleBody">
        <div id="accessible-control" role="audio-controls" aria-label="Audio controls 05:47"></div>
        <div id="short-control" class="audio-player-controls">#{short_text}</div>
        <div id="long-control" class="audio-player-controls">#{long_text}</div>
        <p>Substantive article text remains available to the reader.</p>
      </div>
    HTML

    cleaned = cleaned_article_widgets(html)
    expect(cleaned).not_to include("accessible-control", "short-control")
    expect(cleaned).to include("long-control", "Substantive article text")
  end

  it "removes plain browser fallback messages from exact audio players" do
    widgets = <<~HTML
      <div class="audio-player">Ihr Browser kann dieses Tondokument nicht wiedergeben.</div>
      <div data-component="article-audio-player">Your browser does not support audio playback.</div>
    HTML

    cleaned = cleaned_article_widgets(article_with_audio_widgets(widgets))
    expect(cleaned).not_to include("Tondokument", "does not support audio")
    expect(cleaned).to include("Public investigation", "Article paragraph 3")
  end

  it "removes bounded article audio prompts in fallback extraction" do
    widgets = <<~HTML
      <div class="audio-player"><div class="audio-player--title">Slušaj vest</div></div>
      <div data-component="audio-player"><div data-role="audio-player-title">Listen to this article</div></div>
      <div data-testid="audio-player"><div class="audio-player--title">Read this story aloud</div></div>
      <div id="audio-player"><div class="audio-player--title">Listen to the report</div></div>
    HTML
    html = article_with_audio_widgets(widgets)

    with_url_page("https://news.example.test/fallback-audio-prompt", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page, reader_mode: false)

      expect(payload).to include("contentType" => "article", "readerMode" => false)
      expect(payload.fetch("markdown")).to include("Public investigation", "Article paragraph 3")
      expect(payload.fetch("markdown")).not_to include(
        "Slušaj vest", "Listen to this article", "Read this story aloud", "Listen to the report"
      )
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "preserves durationless labels, transcripts, media, and browser prose" do
    widgets = <<~HTML
      <div class="audio-player">Listen to this investigation</div>
      <div class="audio-player">Listen to this article</div>
      <div class="audio-player">This browser audio investigation does not misrepresent sources.</div>
      <div class="audio-player">Your browser does not support audio playback. The transcript explains the accessibility impact.</div>
      <span class="audio-player">Ihr Browser kann dieses Tondokument nicht wiedergeben. Das Interview wird unten vollständig transkribiert.</span>
      <div class="not-audio-player">Your browser does not support audio playback.</div>
      <div class="audio-player-description">Your browser does not support audio playback.</div>
      <div class="audio-player"><a href="/transcript">Read the browser audio transcript</a></div>
      <div class="audio-player"><audio controls src="/investigation.mp3"></audio></div>
      <p class="audio-player">This browser audio investigation explains accessibility in detail.</p>
      <div class="audio-player"><button>Play this browser audio report</button></div>
      <div class="audio-player"><div class="audio-player--title">Episode 47: Public investigation</div></div>
      <div class="audio-player"><div class="audio-player--title"><span>Listen to this report</span></div></div>
      <div class="audio-player-shell"><div class="audio-player--title">Listen to this article</div></div>
      <div data-component="audio-player-shell"><div class="audio-player--title">Play this story</div></div>
      <div data-testid="news-audio-player"><div class="audio-player--title">Read news aloud</div></div>
      <div class="audio-player"><div class="audio-player--title">Listen to this news</div><button>Play</button></div>
    HTML

    cleaned = cleaned_article_widgets(article_with_audio_widgets(widgets))
    expect(cleaned).to include(
      "Listen to this investigation",
      "Listen to this article",
      "does not misrepresent sources",
      "transcript explains the accessibility impact",
      "vollständig transkribiert",
      "not-audio-player",
      "audio-player-description",
      "Read the browser audio transcript",
      "investigation.mp3",
      "explains accessibility",
      "Play this browser audio report",
      "Episode 47: Public investigation",
      "Listen to this report",
      "audio-player-shell",
      "Play this story",
      "Read news aloud",
      "Listen to this news"
    )
  end

  it "does not remove similarly named components outside an article" do
    html = <<~HTML
      <main>
        <h1>Podcast catalog</h1>
        <div class="audio-player-controls">Catalog duration 08:15</div>
        <div class="audio-player">Your browser does not support audio playback.</div>
        <div class="audio-player"><div class="audio-player--title">Listen to this article</div></div>
        <p>This catalog introduction remains visible outside a focal article owner.</p>
      </main>
    HTML

    expect(cleaned_article_widgets(html)).to include(
      "Catalog duration 08:15",
      "Your browser does not support audio playback",
      "Listen to this article",
      "catalog introduction"
    )
  end
end
