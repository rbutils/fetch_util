# frozen_string_literal: true

require 'nokogiri'
require 'uri'

RSpec.shared_context 'complete block reference expectations' do
  include_context 'extractor integration helpers'

  def retained_reference_node_material(node, literal: false)
    return node.text if literal && node.text?
    return node.text.gsub(/[[:space:]]+/, ' ').strip if node.text?
    return [node.type, node.name, node.content] unless node.element?

    attributes = node.attribute_nodes.map { |attribute| [attribute.name, attribute.value] }.sort
    children = node.children.map do |child|
      retained_reference_node_material(child, literal: literal || %w[pre code].include?(node.name))
    end.reject { |value| value == '' }
    [node.name, attributes, children]
  end

  def retained_reference_markup(markdown)
    fence = nil
    markdown.lines.filter_map do |line|
      content = line.sub(/\A {0,3}(?:> ?)+/, '')
      if fence
        fence = nil if content.match?(/\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*\r?\n?\z/)
        next
      end
      opening = content.match(/\A {0,3}(`{3,}|~{3,})/)
      if opening
        fence = opening[1]
        next
      end

      line
    end.join
  end

  def expect_complete_raw_references(markdown, href, expected_html, base_url: nil)
    expected = Nokogiri::HTML5.fragment(expected_html)
    if base_url
      expected.css('a[href], img[src]').each do |node|
        attribute = node.name == 'a' ? 'href' : 'src'
        node[attribute] = URI.join(base_url, node[attribute]).to_s
      end
    end
    expected_links = expected.css('a[href]').select { |link| link['href'] == href }
    retained = Nokogiri::HTML5.fragment(retained_reference_markup(markdown))
    actual_links = retained.css('a[href]').select { |link| link['href'] == href }

    expect(expected_links).not_to be_empty
    expect(actual_links.length).to eq(expected_links.length)
    actual_links.zip(expected_links).each do |actual, source|
      expect(retained_reference_node_material(actual)).to eq(retained_reference_node_material(source))
      expect(actual.text.gsub(/[[:space:]]+/, ' ').strip).to eq(source.text.gsub(/[[:space:]]+/, ' ').strip)
    end
    actual_links
  end
end
