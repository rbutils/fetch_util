require 'open3'
require 'uri'

RSpec.describe 'Linked editorial card heading roles' do
  include_context 'extractor integration helpers'

  def editorial_record(number, destination: number, title: "Complete research record #{number}", extra: '')
    <<~HTML
      <a class="story-preview" href="/records/#{destination}?view=full%2Frecord#context">
        <div class="story-preview__image">
          <img src="https://images.example.test/width=120,height=80/record-#{number}.png"
            srcset="https://images.example.test/width=120,height=80/record-#{number}.png 120w,
              https://images.example.test/width=240,height=160/record-#{number}.png 240w"
            sizes="(min-width: 600px) 240px, 120px" alt="" loading="lazy">
        </div>
        <div class="story-preview__meta"><p>Independent field reporting</p></div>
        <h2 class="story-preview__heading">#{title}</h2>
        <p class="story-preview__body">The complete contextual paragraph for physical record #{number}
          preserves its independently authored evidence and every source value.</p>
        #{extra}
      </a>
    HTML
  end

  def editorial_page(records, extra: '')
    <<~HTML
      <!doctype html><html lang="en"><head>
      <title>Independent Publication | Homepage</title>
      <link rel="canonical" href="https://publication.example.test/">
      <meta name="description" content="Complete independent field reporting and public-interest research.">
      </head><body><div class="publication-root">
      <section class="story-previews"><h2>Latest research records</h2>
      #{records.join}
      </section>#{extra}</div></body></html>
    HTML
  end

  def with_editorial_observation(source)
    with_url_page('https://publication.example.test/', source) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: false)
      expect(payload).to include('html', 'markdown')
      parser = 'import sys; from markdown_it import MarkdownIt; print(MarkdownIt("commonmark").enable("table").render(sys.stdin.read()))'
      parsed, error, status = Open3.capture3('python3', '-c', parser, stdin_data: payload.fetch('markdown'))
      raise "independent CommonMark parser failed: #{error}" unless status.success?
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      if payload.fetch('html').empty?
        native_or_physical_source = Nokogiri::HTML.fragment(before)
        native_or_physical_source.css('a[href]').each do |link|
          link['href'] = URI.join('https://publication.example.test/', link['href']).to_s
        end
      else
        native_or_physical_source = Nokogiri::HTML.fragment(payload.fetch('html'))
      end
      yield native_or_physical_source, Nokogiri::HTML.fragment(parsed), payload
    end
  end

  it 'retains every physical H2 role as well as complete independently linked card material' do
    source = editorial_page((1..6).map { |number| editorial_record(number) })
    with_editorial_observation(source) do |native, markdown, _payload|
      expected = (1..6).map { |number| "Complete research record #{number}" }
      [native, markdown].each do |document|
        expect(document.css('h2').map { |node| node.text.strip }).to include(*expected)
        expect(document.css('h2').count { |node| expected.include?(node.text.strip) }).to eq(6)
        expect(document.css('img').length).to eq(6)
        (1..6).each do |number|
          destination = "https://publication.example.test/records/#{number}?view=full%2Frecord#context"
          expect(document.css('a[href]').count { |node| node['href'] == destination }).to eq(1)
          expect(document.text).to include("The complete contextual paragraph for physical record #{number}")
        end
      end
    end
  end

  it 'keeps independent headings when destinations repeat without borrowing literal or hidden headings' do
    program = <<~HTML
      <pre><code>first_line('&lt;h2&gt;literal only&lt;/h2&gt;')

      final_line('&amp;complete')</code></pre>
    HTML
    records = (1..6).map do |number|
      editorial_record(number, extra: number == 1 ? program : '')
    end
    records << editorial_record(7, destination: 1, title: 'Another independently authored research record')
    extra = <<~HTML
      <div hidden><a href="/hidden"><h2>Hidden record heading</h2><p>Hidden record evidence</p></a></div>
      <details><summary>Deferred source context</summary><h2>Closed record heading</h2><p>Closed record evidence</p></details>
    HTML
    with_editorial_observation(editorial_page(records, extra: extra)) do |native, markdown, _payload|
      destination = 'https://publication.example.test/records/1?view=full%2Frecord#context'
      [native, markdown].each do |document|
        expect(document.css('a[href]').count { |node| node['href'] == destination }).to eq(2)
        expect(document.css('h2').map { |node| node.text.strip }).to include(
          'Complete research record 1', 'Another independently authored research record'
        )
      end
      source_program = "first_line('<h2>literal only</h2>')\n\nfinal_line('&complete')"
      expect(native.css('pre').map(&:text)).to eq([source_program])
      # A CommonMark fenced-code node includes its required terminal line ending.
      expect(markdown.css('pre').map(&:text)).to eq(["#{source_program}\n"])
      expect(markdown.css('h2').map(&:text)).not_to include('Hidden record heading', 'Closed record heading')
      expect(markdown.text).not_to include('Hidden record evidence', 'Closed record evidence')
    end
  end

  it 'keeps both physically independent records when complete heading, destination and markup are identical' do
    records = (1..6).map { |number| editorial_record(number) }
    repeated = editorial_record(7, destination: 1, title: 'Repeated complete source record')
    records.concat([repeated, repeated])
    with_editorial_observation(editorial_page(records)) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('h2').count { |node| node.text.strip == 'Repeated complete source record' }).to eq(2)
        expect(document.css('a[href]').count do |node|
          node['href'] == 'https://publication.example.test/records/1?view=full%2Frecord#context'
        end).to eq(3)
        expect(document.css('img').length).to eq(8)
        expect(document.text.scan('The complete contextual paragraph for physical record 7').length).to eq(2)
      end
    end
  end

  it 'binds the actual heading destination without turning a preceding literal program heading into a link' do
    program_value = "## Literal program heading\n\nkeep_raw_value()\n"
    records = (1..6).map { |number| editorial_record(number) }
    heading = '<h2 class="story-preview__heading">'
    records[0] = records[0].sub(heading, "<pre><code>#{program_value}</code></pre>" + heading)
    with_editorial_observation(editorial_page(records)) do |native, markdown, _payload|
      destination = 'https://publication.example.test/records/1?view=full%2Frecord#context'
      [native, markdown].each do |document|
        expect(document.css('a[href]').count { |node| node['href'] == destination }).to eq(1)
        expect(document.css('h2').map { |node| node.text.strip }).to include('Complete research record 1')
        expect(document.css('h2').map { |node| node.text.strip }).not_to include('Literal program heading')
        expect(document.css('pre').map(&:text)).to eq([program_value])
      end
    end
  end

  it 'keeps every image outside independently authored text-only paragraphs of adjacent records' do
    source = editorial_page((1..6).map { |number| editorial_record(number) })
    with_editorial_observation(source) do |native, markdown, _payload|
      source_paragraphs = native.css('a.story-preview p').select { |node| node.element_children.empty? }
      expect(source_paragraphs.length).to eq(12)
      source_paragraphs.group_by { |node| node.text.gsub(/\s+/, ' ').strip }.each do |text, physical|
        rendered = markdown.css('p').select { |node| node.text.gsub(/\s+/, ' ').strip == text }
        expect(rendered.length).to eq(physical.length)
        expect(rendered.map { |node| node.element_children.map(&:name) }).to eq(Array.new(physical.length) { [] })
      end
      expect(markdown.css('img').length).to eq(6)
    end
  end
end
