# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor materialized Slick carousels' do
  include_context 'extractor integration helpers'

  def slick_record(number, index:, active:, cloned: false, duplicate_url: nil,
                   unsafe: false, hard_hidden: false, css_hidden: false)
    destination = duplicate_url || number
    href = unsafe ? 'javascript:alert(1)' : "/writers/#{destination}"
    classes = ['slick-slide']
    classes << 'slick-active' if active
    classes << 'slick-cloned' if cloned
    classes << 'hard-hidden-slide' if css_hidden
    hidden_style = hard_hidden ? ' style="display: none"' : ''
    <<~HTML
      <div class="#{classes.join(" ")}" data-slick-index="#{index}" aria-hidden="#{!active}"#{hidden_style}>
        <figure>
          <a href="#{href}"><img src="/writers/#{number}.jpg" alt="Writer #{number}"></a>
          <a href="#{href}"><figcaption>Writer #{number} reports substantive analysis number #{number}</figcaption></a>
        </figure>
      </div>
    HTML
  end

  def slick_carousel_fixture(total: 9, active_count: 4, clones: true, duplicate_url: false,
                             unsafe_url: false, invalid_indexes: false, bad_clone: false,
                             hard_hidden_root: false, hard_hidden_original: false,
                             css_hidden_original: false, nonprefix_active: false,
                             interleaved_clone: false, static_layout: false,
                             duplicate_carousel: false)
    originals = (1..total).map do |number|
      index = number - 1
      index = total + 2 if invalid_indexes && number == total
      active = index < active_count
      active = number.between?(3, active_count + 2) if nonprefix_active
      slick_record(
        number,
        index: index,
        active: active,
        duplicate_url: duplicate_url && number == total ? 1 : nil,
        unsafe: unsafe_url && number == total,
        hard_hidden: hard_hidden_original && number == total,
        css_hidden: css_hidden_original && number == total
      )
    end.join
    clone_markup = if clones
                     leading = ((total - 2)..total).map.with_index do |number, offset|
                       clone_number = bad_clone && offset.zero? ? total + 50 : number
                       slick_record(
                         clone_number,
                         index: offset - 3,
                         active: false,
                         cloned: true,
                         duplicate_url: duplicate_url && clone_number == total ? 1 : nil
                       )
                     end
                     misplaced = interleaved_clone ? slick_record(4, index: -6, active: false, cloned: true) : nil
                     trailing = (1..3).map do |number|
                       slick_record(number, index: total + number - 1, active: false, cloned: true)
                     end.join
                     originals_with_misplaced = if misplaced
                                                  originals.sub('</div>', "</div>#{misplaced}")
                                                else
                                                  originals
                                                end
                     leading.join + originals_with_misplaced + trailing
                   else
                     originals
                   end
    root_style = hard_hidden_root ? ' style="display: none"' : ''
    reporting = (1..8).map do |number|
      <<~HTML
        <article class="report-card">
          <h2><a href="/reports/#{number}">Independent newsroom report #{number}</a></h2>
          <p>Substantive reporting context for newsroom report #{number}.</p>
        </article>
      HTML
    end.join
    carousel = <<~HTML
      <section class="writerItems slick-initialized slick-slider"#{root_style}>
        <div class="slick-list draggable"><div class="slick-track">#{clone_markup}</div></div>
      </section>
    HTML
    carousel_markup = duplicate_carousel ? carousel + carousel : carousel
    <<~HTML
      <html><head><title>Opinion writers</title><style>
        .slick-list { width: 640px; overflow: hidden; }
        .slick-track { display: flex; transform: #{static_layout ? "none" : "translateX(-480px)"}; }
        .slick-slide { flex: 0 0 160px; }
        .hard-hidden-slide { display: none; }
      </style></head><body><main>
        <h1>Opinion writers</h1>
        <p>Independent analysis from every member of the editorial team.</p>
        #{carousel_markup}
        <section class="news-grid"><h2>More reporting</h2>#{reporting}</section>
      </main></body></html>
    HTML
  end

  def writer_numbers(markdown)
    markdown.scan(%r{\]\(https://news.example/writers/(\d+)\)}).flatten.map(&:to_i)
  end

  it 'inserts every missing original after the represented prefix without materializing clones' do
    with_url_page('https://news.example/', slick_carousel_fixture) do |page|
      source = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload.fetch('markdown')

      expect(payload.fetch('contentType')).to eq('list')
      expect(writer_numbers(markdown)).to eq((1..9).to_a)
      expect(markdown.scan('/writers/9').length).to eq(1)
      (5..9).each do |number|
        expect(markdown).to include(
          "[Writer #{number} reports substantive analysis number #{number}](https://news.example/writers/#{number})"
        )
      end
      expect(markdown).not_to include('[undefined]')
      expect(markdown.index('/writers/9')).to be < markdown.index('/reports/1')
      expect(page.evaluate('document.body.innerHTML')).to eq(source)
    end
  end

  it 'preserves an uncapped complete original inventory' do
    with_url_page('https://news.example/', slick_carousel_fixture(total: 125)) do |page|
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

      expect(writer_numbers(markdown)).to eq((1..125).to_a)
    end
  end

  it 'does not expose ambiguous, unsafe, or hard-hidden Slick inventories' do
    fixtures = [
      slick_carousel_fixture(clones: false),
      slick_carousel_fixture(bad_clone: true),
      slick_carousel_fixture(duplicate_url: true),
      slick_carousel_fixture(unsafe_url: true),
      slick_carousel_fixture(invalid_indexes: true),
      slick_carousel_fixture(hard_hidden_root: true),
      slick_carousel_fixture(hard_hidden_original: true),
      slick_carousel_fixture(css_hidden_original: true),
      slick_carousel_fixture(nonprefix_active: true),
      slick_carousel_fixture(interleaved_clone: true),
      slick_carousel_fixture(static_layout: true),
      slick_carousel_fixture(duplicate_carousel: true)
    ]

    fixtures.each do |html|
      with_url_page('https://news.example/', html) do |page|
        markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')

        expect(writer_numbers(markdown) & (5..9).to_a).to eq([])
      end
    end
  end
end
