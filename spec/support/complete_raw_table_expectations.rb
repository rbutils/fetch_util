require 'nokogiri'

RSpec.shared_context 'complete raw table expectations' do
  include_context 'extractor integration helpers'

  def retained_table_node_material(node)
    return [:text, node.text] if node.text?
    return [:comment, node.text] if node.comment?

    attributes = node.attribute_nodes.map { |attribute| [attribute.name, attribute.value] }.sort
    [:element, node.name, attributes, node.children.map { |child| retained_table_node_material(child) }]
  end

  def retained_table_rows(table)
    table.css('tr').select { |row| row.ancestors('table').first == table }.map do |row|
      row.element_children.select { |cell| %w[th td].include?(cell.name) }.map do |cell|
        retained_table_node_material(cell)
      end
    end
  end

  def retained_raw_table_blocks(markdown)
    blocks = []
    fence = nil

    markdown.each_line do |line|
      content = line.sub(/\A(?: {0,3}> ?)+/, '')
      if fence
        closing = /\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}\s*\z/
        fence = nil if closing.match?(content)
      elsif (opening = /\A {0,3}(`{3,}|~{3,})/.match(content))
        fence = opening[1]
      elsif /\A<table(?:\s|>)/i.match?(content)
        fragment = Nokogiri::HTML5.fragment(content)
        material = fragment.children.reject { |node| node.text? && /\A[ \t\r\n]*\z/.match?(node.text) }
        expect(material.map(&:name)).to eq(['table'])
        blocks << content
      end
    end

    blocks
  end

  def expect_complete_raw_table_material(payload, source_html: nil)
    native_tables = Nokogiri::HTML5.fragment(payload.fetch('html')).css('table')
    blocks = retained_raw_table_blocks(payload.fetch('markdown'))
    outer_tables = native_tables.reject { |table| table.ancestors('table').any? }
    expect(blocks.length).to eq(outer_tables.length)

    rendered_tables = Nokogiri::HTML5.fragment(blocks.join("\n")).css('table')
    expect(rendered_tables.map { |table| retained_table_node_material(table) }).to eq(
      native_tables.map { |table| retained_table_node_material(table) }
    )

    return unless source_html

    source_tables = Nokogiri::HTML5.fragment(source_html).css('table')
    expect(native_tables.map { |table| retained_table_rows(table) }).to eq(
      source_tables.map { |table| retained_table_rows(table) }
    )
  end
end
