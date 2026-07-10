# frozen_string_literal: true

require 'uri'

module ContentFidelity
  Inventory = Struct.new(:shape, :types, :social_kinds, :regions, :items, :chrome, :focal, keyword_init: true)
  Result = Struct.new(:metrics, :missing, :failures, keyword_init: true) do
    def success?
      failures.empty?
    end
  end

  module DSL
    def inventory(shape:, types:, regions:, social_kinds: nil, items: [], chrome: [], focal: [])
      Inventory.new(shape:, types: Array(types), social_kinds: Array(social_kinds), regions:, items:, chrome:, focal:)
    end
  end

  extend DSL

  module_function

  def canonical_key(href, title = '')
    uri = URI.parse(href.to_s)
    path = uri.path.to_s.sub(%r{/$}, '')
    [uri.host.to_s.downcase, path, title.to_s.downcase.gsub(/\s+/, ' ').strip].join('|')
  rescue URI::InvalidURIError
    "|#{href}|#{title.to_s.downcase.strip}"
  end

  def markdown_blocks(markdown)
    markdown.to_s.split(/\n{2,}/).map(&:strip).reject(&:empty?)
  end

  def match(payload, contract)
    markdown = payload.fetch('markdown', '').to_s
    positions = ->(values) { values.map { |value| markdown.index(value.to_s) } }
    classification_ok = contract.types.include?(payload['contentType']) &&
                        (contract.social_kinds.empty? || contract.social_kinds.include?(payload['socialKind']))
    required_regions = contract.regions.select { |region| region.fetch(:required, true) }
    found_regions = required_regions.select { |region| heading?(markdown, region.fetch(:label)) }
    missing_regions = required_regions.reject { |region| found_regions.include?(region) }.map { |region| region[:id] }
    section_coverage = ratio(found_regions.length, required_regions.length)
    ordered_regions = increasing?(found_regions.map { |region| heading_position(markdown, region[:label]) })
    item_positions = contract.items.map { |item| markdown.index(item.fetch(:title)) }
    found_items = contract.items.each_with_index.select { |_item, index| item_positions[index] }.map(&:first)
    ordered_item_ratio = ratio(in_order_count(item_positions), contract.items.length)
    blocks = markdown_blocks(markdown)
    contextual_items = found_items.select { |item| paired?(blocks, item) }
    context_ratio = ratio(contextual_items.length, contract.items.length)
    emitted_keys = markdown.scan(/\[([^\]]+)\]\(([^)]+)\)/).map { |title, href| canonical_key(href, title) }
    duplicate_ratio = contract.items.empty? ? 0.0 : ratio(emitted_keys.length - emitted_keys.uniq.length, emitted_keys.length)
    duplicate_focals = contract.items.select { |item| item[:focal] }.select do |item|
      emitted_keys.count(canonical_key(item.fetch(:href), item.fetch(:title))) > 1
    end
    chrome_hits = contract.chrome.select { |marker| markdown.include?(marker) }
    missing_focal = contract.focal.reject { |marker| markdown.include?(marker) }
    focal_positions = positions.call(contract.focal)
    metrics = {
      region_coverage: ratio(found_regions.length, required_regions.length),
      section_coverage:,
      ordered_item_ratio:,
      context_ratio:,
      duplicate_ratio:,
      chrome_hits:,
      focal_coverage: ratio(contract.focal.length - missing_focal.length, contract.focal.length),
      classification_ok:
    }
    failures = []
    failures << :classification_ok unless classification_ok
    failures << :region_coverage if metrics[:region_coverage] < 0.8 || required_regions.any? { |region| region[:focal] && !found_regions.include?(region) }
    failures << :section_coverage unless missing_regions.empty? && ordered_regions
    failures << :ordered_item_ratio if ordered_item_ratio < 1.0
    failures << :context_ratio if context_ratio < 0.75
    failures << :duplicate_ratio if duplicate_ratio > 0.10 || duplicate_focals.any?
    failures << :chrome_hits unless chrome_hits.empty?
    failures << :focal_coverage if missing_focal.any? || !increasing?(focal_positions)
    Result.new(metrics:, missing: { regions: missing_regions, focal: missing_focal, context: found_items.reject do |item|
      contextual_items.include?(item)
    end.map { |item| item[:id] } }, failures:)
  end

  def ratio(numerator, denominator)
    return 1.0 if denominator.zero?

    numerator.to_f / denominator
  end

  def increasing?(positions)
    positions.compact.each_cons(2).all? { |left, right| left < right }
  end

  def in_order_count(positions)
    positions.compact.each_cons(2).count { |left, right| left < right } + (positions.compact.empty? ? 0 : 1)
  end

  def paired?(blocks, item)
    blocks.any? do |block|
      values = [item[:title], item[:summary], item[:metadata]].compact
      values.all? { |value| block.include?(value) } && block.include?(item[:href])
    end
  end

  def heading?(markdown, label)
    !heading_position(markdown, label).nil?
  end

  def heading_position(markdown, label)
    markdown.match(/^\s*#+\s+#{Regexp.escape(label)}\s*$/)&.begin(0)
  end
end

RSpec.shared_context 'content fidelity contracts' do
  include ContentFidelity::DSL

  def expect_content_fidelity(payload, contract)
    result = ContentFidelity.match(payload, contract)
    expect(result.failures).to be_empty, "fidelity failures=#{result.failures.inspect} metrics=#{result.metrics.inspect} missing=#{result.missing.inspect}"
    result
  end
end
