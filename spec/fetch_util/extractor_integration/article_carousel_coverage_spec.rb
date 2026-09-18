# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor article carousel coverage' do
  include_context 'extractor integration helpers'

  def carousel_card(number, attributes: '', image: nil, title: nil, extra: '')
    image ||= number
    title ||= "Solution model #{number}"
    <<~HTML
      <div class="keen-slider__slide" #{attributes}>
        <img src="/images/solution-#{image}.jpg" alt="Solution #{number}" width="160" height="90">
        <p>#{title}</p>
        <p>Detailed operating guidance for solution #{number} helps teams coordinate services, measure outcomes, and support every customer consistently.</p>
        #{extra}
      </div>
    HTML
  end

  def carousel_article(cards)
    <<~HTML
      <html><head><title>Wellness operations platform</title>
        <style>
          .carousel-window { width: 540px; overflow: hidden; }
          .keen-slider { display: flex; width: max-content; }
          .keen-slider__slide { flex: 0 0 170px; width: 170px; }
        </style>
      </head><body><main><article>
        <h1>Wellness operations platform</h1>
        <p>Our platform coordinates bookings, coaching, communications, and reporting for organizations that deliver wellness programs around the world.</p>
        <p>Teams use the service to personalize customer journeys while retaining complete operational evidence and local service context.</p>
        <p>The solution catalog below explains the supported operating models and preserves every materialized option for comparison.</p>
        <div class="carousel-window"><div class="keen-slider">#{cards}</div></div>
        <p>Implementation support helps each organization configure workflows and measure long-term outcomes.</p>
      </article></main></body></html>
    HTML
  end

  def extracted_carousel(html)
    with_url_page('https://wellness.example/catalog/solutions', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: true).extract(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      payload
    end
  end

  it 'preserves every structured card after a proved visible prefix without a cap' do
    payload = extracted_carousel(carousel_article((1..125).map { |number| carousel_card(number) }.join))
    markdown = payload.fetch('markdown')

    expect(payload.fetch('contentType')).to eq('article')
    expect(payload.fetch('readerMode')).to be(true)
    expect(markdown.scan(/Solution model (\d+)/).flatten.map(&:to_i)).to eq((1..125).to_a)
    expect(markdown.scan(%r{https://wellness\.example/images/solution-(\d+)\.jpg}).flatten.map(&:to_i)).to eq((1..125).to_a)
  end

  it 'accepts the minimum three-record prefix for a four-record carousel' do
    added_detail = 'Additional locally owned solution detail. ' * 4
    cards = (1..4).map do |number|
      carousel_card(number).sub(
        'Detailed operating guidance',
        "#{added_detail}Detailed operating guidance"
      )
    end.join
    html = carousel_article(cards)
           .sub('width: 540px', 'width: 510px')
    markdown = extracted_carousel(html).fetch('markdown')

    expect(markdown.scan(/Solution model (\d+)/).flatten.map(&:to_i)).to eq((1..4).to_a)
  end

  it 'rejects non-prefix, hidden, duplicate, interactive, and related carousel records' do
    variants = {
      non_prefix: (1..7).map { |number| carousel_card(number, attributes: (number == 1 ? 'style="transform: translateX(-1200px)"' : '')) }.join,
      hidden: (1..7).map { |number| carousel_card(number, attributes: (number == 5 ? 'hidden' : '')) }.join,
      duplicate: (1..7).map { |number| carousel_card(number, image: (number == 7 ? 6 : number), title: (number == 7 ? 'Solution model 6' : nil)) }.join,
      interactive: (1..7).map { |number| carousel_card(number, extra: (number == 6 ? '<button>Open dialog</button>' : '')) }.join,
      editable: (1..7).map { |number| carousel_card(number, attributes: (number == 6 ? 'contenteditable="plaintext-only"' : '')) }.join,
      aria_false: (1..7).map { |number| carousel_card(number, attributes: (number == 6 ? 'aria-selected="FALSE"' : '')) }.join,
      aria_disabled: (1..7).map { |number| carousel_card(number, attributes: (number == 6 ? 'aria-disabled="TRUE"' : '')) }.join,
      disabled: (1..7).map { |number| carousel_card(number, attributes: (number == 6 ? 'disabled' : '')) }.join,
      inert: (1..7).map { |number| carousel_card(number, attributes: (number == 6 ? 'inert' : '')) }.join
    }

    variants.each do |kind, cards|
      markdown = extracted_carousel(carousel_article(cards)).fetch('markdown')
      expected = kind == :non_prefix ? [2, 3, 4] : [1, 2, 3, 4]
      expect(markdown.scan(/Solution model (\d+)/).flatten.map(&:to_i)).to eq(expected)
      expect(markdown).not_to include('Open dialog') if kind == :interactive
    end

    related = carousel_article((1..7).map { |number| carousel_card(number) }.join)
              .sub('<div class="carousel-window">', '<aside class="read-next carousel-window">')
              .sub("</div>\n        <p>Implementation", "</aside>\n        <p>Implementation")
    related_markdown = extracted_carousel(related).fetch('markdown')
    expect(related_markdown.scan(/Solution model (\d+)/)).to be_empty

    hidden_ancestor = carousel_article((1..7).map { |number| carousel_card(number) }.join)
                      .sub('<div class="carousel-window">', '<div aria-hidden="true"><div class="carousel-window">')
                      .sub("</div>\n        <p>Implementation", "</div></div>\n        <p>Implementation")
    hidden_markdown = extracted_carousel(hidden_ancestor).fetch('markdown')
    expect(hidden_markdown.scan(/Solution model (\d+)/)).to be_empty

    linked_root = carousel_article((1..7).map { |number| carousel_card(number) }.join)
                  .sub('<div class="keen-slider">', '<a href="/carousel-action" class="keen-slider">')
                  .sub("</div></div>\n        <p>Implementation", "</a></div>\n        <p>Implementation")
    linked_markdown = extracted_carousel(linked_root).fetch('markdown')
    expect(linked_markdown.scan(/Solution model (\d+)/).flatten.map(&:to_i)).to eq([1, 2, 3, 4])

    first_carousel = (1..7).map { |number| carousel_card(number) }.join
    second_carousel = (101..107).map do |number|
      carousel_card(number, image: (number == 101 ? 1 : number))
    end.join
    shared_image = carousel_article(first_carousel).sub(
      '<p>Implementation support',
      "<div class=\"carousel-window\"><div class=\"keen-slider\">#{second_carousel}</div></div><p>Implementation support"
    )
    shared_markdown = extracted_carousel(shared_image).fetch('markdown')
    expect(shared_markdown.scan(/Solution model (\d+)/).flatten.map(&:to_i)).to eq([1, 2, 3, 4, 101, 102, 103, 104])
  end
end
