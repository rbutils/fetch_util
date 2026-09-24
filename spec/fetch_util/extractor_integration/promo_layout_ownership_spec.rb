# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil CTA-layout content ownership' do
  include_context 'extractor integration helpers'

  def clean_promo_root(html)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__cleanPromoRoot = function(input) {
        var template = document.createElement("template");
        template.innerHTML = input;
        var sourceNode = template.content.firstElementChild;
        var before = sourceNode.outerHTML;
        var clone = sourceNode.cloneNode(true);
        stripPromoAdModules(clone);
        return {clone: clone.outerHTML, sourceUnchanged: sourceNode.outerHTML === before};
      };
    JS

    with_page('<main>Unchanged source page</main>') do |page|
      page.add_script_tag(content: source)
      page.evaluate("window.__cleanPromoRoot(#{JSON.generate(html)})")
    end
  end

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

  it 'removes compact recirculation slogans without deleting substantive analysis' do
    html = <<~HTML
      <html><head><title>Public policy briefing</title></head><body><main><article>
        <h1>Public policy briefing</h1>
        <p>The briefing explains the enacted policy and records the evidence considered by legislators.</p>
        <p>Independent analysts supplied historical context, implementation costs, and regional comparisons.</p>
        <p>Officials published the final timetable and committed to quarterly progress reports.</p>
        <p class="article-recirculacao">TUDO SOBRE A COPA, EM UM SÓ LUGAR</p>
      </article></main></body></html>
    HTML

    with_url_page('https://reports.example/public-policy-briefing', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload.fetch('markdown')).not_to include('TUDO SOBRE A COPA, EM UM SÓ LUGAR')
      expect(payload.fetch('html')).not_to include('TUDO SOBRE A COPA, EM UM SÓ LUGAR')
      expect(payload.fetch('markdown')).to include('Independent analysts supplied historical context')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end

    analysis = clean_promo_root(<<~HTML)
      <section class="recirculation-analysis">
        <h2>How water recirculation works</h2>
        <p>Closed-loop systems filter and reuse water while sensors monitor flow and contamination.</p>
      </section>
    HTML
    expect(analysis.fetch('clone')).to include('How water recirculation works',
                                               'Closed-loop systems filter and reuse water')
    expect(analysis.fetch('sourceUnchanged')).to be(true)
  end
end
