# frozen_string_literal: true

require 'nokogiri'

RSpec.shared_context 'literal title heading assertions' do
  def expect_literal_title_heading(payload, title)
    native = Nokogiri::HTML5.fragment(payload.fetch("html"))
    heading_lines = payload.fetch("markdown").lines.grep(/\A# /).map(&:chomp)
    # These fixtures contain plain, single-line titles. Decode punctuation only
    # in those headings, leaving literal programs and other content untouched.
    titles = heading_lines.map { |line| line.delete_prefix("# ").gsub(/\\([[:punct:]])/, '\1') }

    expect(native.css("h1").map(&:text)).to eq([title])
    expect(titles).to eq([title])
    expect(heading_lines.join).not_to match(/(?<!\\)</)
  end
end
