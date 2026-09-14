# frozen_string_literal: true

RSpec.describe 'List section heading context' do
  include_context 'extractor integration helpers'

  def heading_context_source
    root = File.expand_path('../../..', __dir__)
    File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).filter_map do |path|
      next if path.empty? || path.start_with?('#')

      source = File.read(File.join(root, 'websieve', path))
      next source unless path == '99_outro.js'

      "global.headingContextList = function() { return listContent(collectMetadata()); };\n#{source}"
    end.join("\n")
  end

  it 'preserves locally owned headings despite header presentation and keeps their records ordered' do
    regions = %w[Morning Evening].map do |label|
      records = (1..3).map do |number|
        "<a class='card' href='/#{label}/#{number}'><h3>#{label} regional investigation #{number}</h3>" \
          '<p>Correspondents explain the evidence and the next steps for local residents.</p></a>'
      end.join
      "<div class='report-section'><div class='section-colored-header'><h2>#{label}</h2></div>#{records}</div>"
    end.join
    html = '<html><head><title>Regional bulletin</title></head><body><h1>Regional bulletin</h1>' \
           '<div>The reporting desk publishes independently verified updates from every part of the region.</div>' \
           "#{regions}" \
           '<nav><div class="section-header"><h2>Navigation services</h2></div>' \
           '<a href="/menu">Complete site menu</a></nav></body></html>'

    with_url_page('https://bulletin.example/', html) do |page|
      page.add_script_tag(content: heading_context_source)
      markdown = page.evaluate('headingContextList().markdown')

      expect(markdown).to include('## Morning', '## Evening')
      expect(markdown.index('## Morning')).to be < markdown.index('/Morning/1')
      expect(markdown.index('/Morning/3')).to be < markdown.index('## Evening')
      expect(markdown.index('## Evening')).to be < markdown.index('/Evening/1')
      expect(markdown).not_to include('Navigation services', 'Complete site menu')
    end

    with_url_page('https://bulletin.example/', html) do |page|
      markdown = FetchUtil::Extractor.new.extract(page).fetch('markdown')
      expect(markdown).to include('## Morning', '## Evening', 'The reporting desk publishes independently verified updates')
      expect(markdown.index('/Morning/3')).to be < markdown.index('## Evening')
      expect(markdown.index('## Evening')).to be < markdown.index('/Evening/1')
    end
  end

  it 'does not preserve an unowned header-like utility wrapper' do
    html = '<html><body><main><h1>Community reports</h1>' \
           '<p>Residents can read the latest verified information from their community.</p></main>' \
           '<div><div class="section-header"><h2>Account shortcuts</h2></div>' \
           '<a href="/account">Manage your account</a></div></body></html>'

    with_url_page('https://bulletin.example/', html) do |page|
      page.add_script_tag(content: heading_context_source)
      expect(page.evaluate('headingContextList().html')).not_to include('Account shortcuts')
    end
  end

  it 'preserves the owning label of named image records without heading tags' do
    html = '<html><body><h1>Community bulletin</h1><section>' \
           '<div class="section-header"><h2>Illustrated reports</h2></div>' \
           '<a class="card" href="/photos/north"><img src="/north.png">Northern district photo report</a>' \
           '<a class="card" href="/photos/south"><img src="/south.png">Southern district photo report</a>' \
           '</section></body></html>'

    with_url_page('https://bulletin.example/', html) do |page|
      page.add_script_tag(content: heading_context_source)
      markdown = page.evaluate('headingContextList().markdown')
      expect(markdown).to include('## Illustrated reports', 'Northern district photo report', 'Southern district photo report')
    end
  end
end
