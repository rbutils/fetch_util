# frozen_string_literal: true

RSpec.describe FetchUtil::Extractor, 'card-owned headings' do
  include_context 'extractor integration helpers'

  it 'preserves headers inside linked cards and headers containing the primary link' do
    cards = (1..8).map do |number|
      title = "Independent regional investigation #{number}"
      image = "<img src='/photo/#{number}.jpg' alt='Image description #{number}'>"
      content = if number.odd?
                  "<a href='/story/#{number}'>#{image}<header class='news__header'><h2>#{title}</h2></header></a>"
                else
                  "#{image}<header class='news__header'><h2><a href='/story/#{number}'>#{title}</a></h2></header>"
                end
      "<article class='news'>#{content}</article>"
    end.join
    html = '<html><body><header><h1>Publisher navigation</h1><a href="/menu">Menu</a></header>' \
           "<main><h1>Regional bulletin</h1><section>#{cards}</section></main></body></html>"

    with_url_page('https://publisher.example/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = described_class.new.extract(page)
      markdown = result.fetch('markdown')
      expect(result.fetch('contentType')).to eq('list')
      (1..8).each do |number|
        expect(markdown).to include("[Independent regional investigation #{number}](https://publisher.example/story/#{number})")
      end
      expect(markdown).not_to include('Publisher navigation', '/menu)')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'does not restore card-like headings inside navigation or a site header' do
    records = (1..4).map do |number|
      "<article><a href='/menu/#{number}'><img src='/icon.png'><header><h2>Navigation shortcut #{number}</h2></header></a></article>"
    end.join
    html = "<html><body><header>#{records}</header><nav>#{records}</nav><main><h1>Community report</h1>" \
           "<p>#{"Researchers explain the evidence in detail for everyone in the community. " * 10}</p></main></body></html>"

    with_url_page('https://publisher.example/report', html) do |page|
      expect(described_class.new.extract(page).fetch('markdown')).not_to include('Navigation shortcut', '/menu/')
    end
  end

  it 'does not let a hidden fourth sibling qualify three visible owned records' do
    visible_records = (1..3).map do |number|
      "<article class='news'><a href='/visible/#{number}'><header><time datetime='2026-09-#{20 + number}'>September #{20 + number}</time>" \
        "<div class='news__title'>Visible report #{number}</div></header></a></article>"
    end.join
    hidden_records = (4..4).map do |number|
      "<article style='display:none'><a href='/hidden/#{number}'><header><time datetime='2026-09-#{20 + number}'>September #{20 + number}</time>" \
        "<div class='news__title'>Hidden report #{number}</div></header></a></article>"
    end.join
    html = <<~HTML
      <html><body><main>
        <article><h1>Community research report</h1>
          <p>Researchers document a detailed community study, its methods, the measured results, and the implications for local families.</p>
          <p>The report compares several seasons of observation and explains the uncertainty around future projections.</p>
          <section class='related'>#{visible_records}#{hidden_records}</section>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://publisher.example/research/report', html) do |page|
      result = described_class.new.extract(page)
      expect(result.fetch('html')).not_to include('<header>', 'Visible report', 'Hidden report', '/visible/', '/hidden/')
      expect(result.fetch('markdown')).to include('Researchers document a detailed community study')
      expect(result.fetch('markdown')).not_to include('Visible report', 'Hidden report', '/visible/', '/hidden/')
    end
  end

  it 'keeps structured card headings under explicit navigation chrome' do
    navigation_records = (1..4).map do |number|
      "<article class='news'><a href='/nav/#{number}'><img src='/nav-icon-#{number}.png'>" \
        "<header><h2>Navigation report #{number}</h2></header></a></article>"
    end.join
    html = <<~HTML
      <html><body><nav><div class='site-header'>#{navigation_records}</div></nav>
        <main><article class='article-content'><h1>Community research report</h1>
          <p>Researchers explain the evidence in detail for everyone in the community.</p>
          <p>The report compares several seasons of observation and explains future projections.</p>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://publisher.example/report', html) do |page|
      result = described_class.new.extract(page)

      expect(result.fetch('markdown')).to include('Researchers explain the evidence in detail')
      expect(result.fetch('html')).not_to include('Navigation report', '/nav/')
      expect(result.fetch('markdown')).not_to include('Navigation report', '/nav/')
    end
  end

  it 'does not restore inert headers without visible title and record evidence' do
    hidden_headings = (1..2).map do |number|
      "<article class='news'><a href='/hidden-title/#{number}'><img src='/visible/#{number}.jpg' alt='Visible card image'>" \
        "<header><h2 hidden>Hidden title #{number}</h2></header></a></article>"
    end.join
    nonsemantic_titles = (1..2).map do |number|
      "<article class='news'><a href='/hidden-evidence/#{number}'><header><div class='news__title'>Visible named title #{number}</div></header></a>" \
        "<p hidden>Hidden-only record evidence #{number}</p><img hidden src='/hidden/#{number}.jpg' alt='Hidden evidence'></article>"
    end.join
    html = <<~HTML
      <html><body><section class='publisher-header'>#{hidden_headings}#{nonsemantic_titles}</section>
        <main><article><h1>Community investigation</h1>
          <p>Researchers explain the evidence in a detailed community investigation with methods, results, and implications.</p>
          <p>The findings compare several seasons of observation and describe the remaining uncertainty.</p>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://publisher.example/research', html) do |page|
      result = described_class.new.extract(page)

      expect(result.fetch('markdown')).to include('Researchers explain the evidence')
      expect(result.fetch('html')).not_to include('Hidden title', 'Visible named title', '/hidden-title/', '/hidden-evidence/')
      expect(result.fetch('markdown')).not_to include('Hidden title', 'Visible named title', '/hidden-title/', '/hidden-evidence/')
    end
  end

  it 'preserves four visible long title headers and their source destinations on article pages' do
    records = (1..4).map do |number|
      title = "Regional archive investigation #{number} " + ('documents, interviews, and historical context remain part of this complete source heading. ' * 4)
      "<article class='news'><a href='/long-record/#{number}'><header><time datetime='2026-09-#{20 + number}'>September #{20 + number}, 2026</time>" \
        "<h2>#{title}</h2></header></a><p>Source-owned record summary #{number} remains visible.</p></article>"
    end.join
    html = "<html><body><main><h1>Regional archive</h1><section class='news-list'>#{records}</section></main></body></html>"

    with_url_page('https://publisher.example/archive', html) do |page|
      result = described_class.new.extract(page)
      markdown = result.fetch('markdown')

      (1..4).each do |number|
        title = "Regional archive investigation #{number} " + ('documents, interviews, and historical context remain part of this complete source heading. ' * 4)
        expect(title.length).to be > 220
        prefix = "[Regional archive investigation #{number} documents, interviews,"
        expect(markdown).to match(%r{#{Regexp.escape(prefix)}[^\]]*\]\(https://publisher\.example/long-record/#{number}\)})
      end
    end
  end

  it 'preserves headings and material timestamps in exactly four visible owned cards' do
    records = (1..4).map do |number|
      day = 20 + number
      "<article class='news'><a class='news__link' href='/visible/#{number}'><img src='/visible/#{number}.jpg'>" \
        "<header><time datetime='2026-09-#{day}'>September #{day}, 2026</time>" \
        "<h2>Visible owned report #{number}</h2></header></a></article>"
    end.join
    html = <<~HTML
      <html><body><main><h1>Regional report archive</h1>
        <section class='news-list'>#{records}</section>
      </main></body></html>
    HTML

    with_url_page('https://publisher.example/report', html) do |page|
      result = described_class.new.extract(page)
      markdown = result.fetch('markdown')

      expect(result.fetch('contentType')).to eq('list')
      (1..4).each do |number|
        day = 20 + number
        expect(markdown).to include("[Visible owned report #{number}](https://publisher.example/visible/#{number})")
        expect(markdown).to include("September #{day}, 2026")
        expect(result.fetch('html')).to include("datetime=\"2026-09-#{day}\"")
      end
      expect(page.evaluate('document.body.innerHTML')).to include('Visible owned report 4')
    end
  end

  it 'keeps explicit card headings when their lazy images have not become visible' do
    records = (1..6).map do |number|
      "<article><a class='news__link' href='/broadcast/#{number}'><img style='opacity:0' src='/#{number}.jpg'>" \
        '<noscript><img src="/fallback.jpg"></noscript>' \
        "<header><h2>Regional broadcast report number #{number}</h2></header></a></article>"
    end.join
    html = "<html><body><main><h1>Community broadcasts</h1>#{records}</main></body></html>"
    with_url_page('https://publisher.example/', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      (1..6).each do |number|
        expect(markdown).to include("[Regional broadcast report number #{number}](https://publisher.example/broadcast/#{number})")
      end
      expect(markdown).not_to include('fallback.jpg')
    end
  end

  it 'preserves named title fields inside owned headers without requiring heading tags' do
    records = (1..6).map do |number|
      tag = number.odd? ? 'div' : 'span'
      "<article class='news'><a class='news__link' href='/named/#{number}'>" \
        "<header><time>2026-09-14</time><span class='news__category'>Region #{number}</span>" \
        "<#{tag} class='news__title'>Named regional investigation number #{number}</#{tag}></header></a></article>"
    end.join
    html = '<html><body><header><a href="/navigation"><div class="news__title">Publisher navigation shortcut</div></a></header>' \
           "<main><h1>Regional investigations</h1>#{records}</main></body></html>"
    with_url_page('https://publisher.example/', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      (1..6).each do |number|
        expect(markdown).to include("[Named regional investigation number #{number}](https://publisher.example/named/#{number})")
      end
      expect(markdown).not_to include('Publisher navigation shortcut', '/navigation)')
    end
  end
end
