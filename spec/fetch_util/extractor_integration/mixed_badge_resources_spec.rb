# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'fetch_util preserves resources beside status badges', type: :extractor_integration do
  include_context 'extractor integration helpers'

  %w[sphinx mkdocs].each do |framework|
    it "retains complete mixed resource paragraphs in #{framework}" do
      resources = [
        ['https://reference.publication.example.test/library', 'API reference'],
        ['https://build.publication.example.test/status', 'Build status'],
        ['https://community.publication.example.test/catalog', 'Community catalog']
      ]
      images = [
        'https://assets.publication.example.test/reference.svg',
        'https://assets.publication.example.test/build/badge.svg',
        'https://assets.publication.example.test/community.svg'
      ]
      group = resources.zip(images).map do |(href, label), src|
        %(<a href="#{href}"><img src="#{src}" alt="#{label}"></a>)
      end.join(' ')
      article = <<~HTML
        <h1>Published package resources</h1>
        <p>The published reference includes the complete operational instructions and independent community resources.</p>
        <p id="mixed-resources">#{group}</p>
        <p id="authored-resource">Consult the <a href="https://reference.publication.example.test/runbook">operations runbook</a> for the complete reporting procedure. <a href="#{resources[1][0]}"><img src="#{images[1]}" alt="Build status"></a></p>
        <pre><code class="language-python">print("resource review")\nprint("complete")</code></pre>
        <p><a href="https://status.publication.example.test/ci"><img src="https://assets.publication.example.test/ci/badge.svg" alt="CI workflow coverage"></a></p>
        <p style="display:none"><a href="https://hidden.publication.example.test/private"><img src="https://assets.publication.example.test/hidden.svg" alt="Hidden resource"></a></p>
        <p>The complete closing publication remains available after the resource group and literal program.</p>
      HTML
      owner = if framework == 'sphinx'
                %(<div class="rst-content"><div class="document">#{article}</div></div>)
              else
                %(<main class="md-main"><article class="md-content__inner md-typeset">#{article}</article></main>)
              end
      html = %(<html><head><title>Published package resources</title><meta name="generator" content="#{framework}"></head><body>#{owner}</body></html>)
      with_url_page('https://reference.publication.example.test/manual/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page, reader_mode: false)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        body = Nokogiri::HTML5.fragment(payload.fetch('html'))
        resource_group = body.at_css('#mixed-resources')
        expect(resource_group).not_to be_nil
        expect(resource_group.css('a[href]').map { |link| [link['href'], link.at_css('img')['alt']] }).to eq(resources)
        expect(body.css('#mixed-resources img').map { |image| image['src'] }).to eq(images)
        expect(body.at_css('#authored-resource').text).to include('Consult the operations runbook for the complete reporting procedure.')
        expect(body.css('pre code').map(&:text)).to include("print(\"resource review\")\nprint(\"complete\")")
        expect(payload.fetch('markdown')).to include(*images, resources[0][0], resources[1][0], resources[2][0], 'https://reference.publication.example.test/runbook')
        expect(payload.fetch('markdown').scan(resources[1][0]).size).to eq(2)
        expect(payload.fetch('html') + payload.fetch('markdown')).not_to include('https://status.publication.example.test/ci', 'hidden.publication.example.test')
      end
    end
  end
end
