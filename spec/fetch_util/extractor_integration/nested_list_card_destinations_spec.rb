# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'

RSpec.describe 'Heading-card destinations with authored lists' do
  include_context 'extractor integration helpers'

  %w[ul ol].each do |list_tag|
    it "retains the heading destination and complete #{list_tag} card body" do
      destination = 'https://docs.publication.example.test/tools/workbench/'
      image = 'https://images.publication.example.test/workbench.png'
      html = <<~HTML
        <html><head><title>Public data tools</title><meta name="generator" content="MkDocs 1.6"></head><body>
        <main class="md-main"><article class="md-content__inner md-typeset">
        <h1>Public data tools</h1>
        <p>A complete directory explains each published tool and its independently maintained source.</p>
        <a href="#{destination}" class="tool-card">
          <figure><img src="#{image}" alt=""></figure>
          <h3>Public data workbench</h3>
          <p>The workbench retains the complete archive and its documented update procedure.</p>
          <#{list_tag}>
            <li>Stable snapshots include every published record.</li>
            <li>Use <code>data sync --verify</code> without discarding records.</li>
          </#{list_tag}>
        </a>
        <p>The closing source note remains separate from the linked card.</p>
        </article></main></body></html>
      HTML

      with_url_page('https://docs.publication.example.test/tools/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        markdown = payload.fetch('markdown')
        public_card = Nokogiri::HTML5.fragment(payload.fetch('html')).css('a[href]').find { |node| node['href'] == destination }

        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        expect(public_card).not_to be_nil
        expect(public_card.at_css('h3').text).to eq('Public data workbench')
        expect(public_card.css("#{list_tag} > li").map(&:text)).to eq(
          [
            'Stable snapshots include every published record.',
            'Use data sync --verify without discarding records.'
          ]
        )
        expect(markdown).to include('A complete directory explains each published tool and its independently maintained source.',
                                    'The workbench retains the complete archive and its documented update procedure.',
                                    'The closing source note remains separate from the linked card.',
                                    "![](#{image})", '`data sync --verify`')
        marker = list_tag == 'ol' ? '\d+\.' : '[-*]'
        expect(markdown).to match(/^#{marker}\s+Stable snapshots include every published record\.$/)
        expect(markdown).to match(/^#{marker}\s+Use `data sync --verify` without discarding records\.$/)
        expect(markdown).to include("### [Public data workbench](#{destination})")
      end
    end
  end
end
