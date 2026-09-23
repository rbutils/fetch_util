# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil CTA-layout content ownership' do
  include_context 'extractor integration helpers'

  it 'retains every heading and date in an actionless CTA layout' do
    venues = (1..12).map do |number|
      <<~HTML
        <section class="tour-stop">
          <div class="mol-header-block-with-detached-cta">
            <h2>Tour venue #{format("%02d", number)}</h2>
            <p>Tour date #{format("%02d", number)} in this city.</p>
          </div>
        </section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Tour dates</title></head><body><main><article>
        <h1>Tour dates</h1>
        <p>Our community tour brings performances to independent cities across the country.</p>
        <p>Each stop has its own venue and date so visitors can plan their journey.</p>
        #{venues}
        <div class="detached-cta"><h2>Subscribe today</h2><button>Subscribe now</button></div>
      </article></main></body></html>
    HTML

    with_url_page('https://events.example/story/tour-dates', html) do |page|
      markdown = FetchUtil::Extractor.new.extract(page).fetch('markdown')

      expect(markdown).not_to include('Subscribe today')
      positions = (1..12).map do |number|
        venue = format('Tour venue %02d', number)
        date = format('Tour date %02d', number)
        expect(markdown.scan(/^## #{venue}$/).length).to eq(1)
        expect(markdown.scan(date).length).to eq(1)
        expect(markdown.index(venue)).to be < markdown.index(date)
        markdown.index(venue)
      end
      expect(positions).to eq(positions.sort)
    end
  end
end
