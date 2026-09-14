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
