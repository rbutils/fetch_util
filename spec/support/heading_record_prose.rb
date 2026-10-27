require 'open3'

RSpec.shared_context 'heading record prose' do
  def heading_record_prose(markdown, destination:, rank: 3)
    output, error, status = Open3.capture3(
      'python3', '-c',
      "import sys; from markdown_it import MarkdownIt; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()), end='')",
      stdin_data: markdown
    )
    raise "independent Markdown parser failed: #{error}" unless status.success?

    document = Nokogiri::HTML5.fragment(output)
    headings = document.css("h#{rank}").select do |heading|
      heading.css('a[href]').any? { |link| link['href'] == destination }
    end
    expect(headings.length).to eq(1)
    heading = headings.fetch(0)
    expect(heading.css('a[href]').map { |link| link['href'] }).to eq([destination])

    record = Nokogiri::HTML5.fragment('')
    record.add_child(heading.dup)
    sibling = heading.next_sibling
    while sibling
      if sibling.text? && sibling.text.strip.empty?
        sibling = sibling.next_sibling
        next
      end
      break unless sibling.element? && sibling.name == 'p'

      record.add_child(sibling.dup)
      sibling = sibling.next_sibling
    end
    record
  end
end
