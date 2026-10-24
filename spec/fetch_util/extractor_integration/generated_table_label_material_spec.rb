# frozen_string_literal: true

require 'support/extractor_integration_helpers'
require 'nokogiri'

RSpec.describe 'Generated table labels and authored repetition' do
  include_context 'extractor integration helpers'

  def raw_table_resource_probe
    root = File.expand_path('../../../websieve', __dir__)
    paths = File.readlines(File.join(root, 'manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |name| File.read(File.join(root, name)) }.join("\n")
    body = <<~JS
      window.rawTableResources = withComposedDomRead(function(options) {
        return markdownFor(document.body.innerHTML, false, options.allowMailto, true);
      });
    JS
    source.sub('})(window);', "#{body}})(window);")
  end

  def with_raw_table(html, allow_mailto: true)
    with_url_page('https://publication.example.test/docs/manual/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: raw_table_resource_probe)
      markdown = page.evaluate("rawTableResources({allowMailto: #{allow_mailto ? "true" : "false"}})")
      rendered = Nokogiri::HTML.fragment(markdown)
      yield rendered, markdown
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'removes only the duplicate generated leading labels while retaining complete declarations and references' do
    rows = %w[Alpha Beta Gamma].each_with_index.map do |label, index|
      note = index + 7
      <<~HTML
        <tr><td><p>Record #{label}<sup><a href='https://publication.example.test/notes##{note}'>#{note}</a></sup></p>
        <div id='ctl00_Registry_Data_ctl0#{index + 1}_Body'>
        <p>Record #{label}<superscript>#{note}</superscript></p>
        <p><i>Record annotation:</i></p><p>Record #{label} retains its authored declaration.</p>
        <pre><code>published_#{index}()

        finish_#{index}()</code></pre></div></td></tr>
      HTML
    end.join
    with_raw_table("<table id='ctl00_Registry_Data'>#{rows}</table>") do |rendered, _markdown|
      cells = rendered.css('td')
      expect(cells.length).to eq(3)
      %w[Alpha Beta Gamma].each_with_index do |label, index|
        cell = cells[index]
        expect(cell.css('p').map { |p| p.text.strip }).to eq(
          ["Record #{label}#{index + 7}", 'Record annotation:', "Record #{label} retains its authored declaration."]
        )
        expect(cell.at_css('i').text).to eq('Record annotation:')
        expect(cell.at_css('div')['id']).to eq("ctl00_Registry_Data_ctl0#{index + 1}_Body")
        expect(cell.at_css('pre code').text).to eq("published_#{index}()\n\nfinish_#{index}()")
      end
      expect(rendered.css('a').map { |link| [link.text, link['href']] }).to eq(
        (7..9).map { |note| [note.to_s, "https://publication.example.test/notes##{note}"] }
      )
    end
  end

  it 'retains an independent reference even when a generated label has the same words' do
    html = <<~HTML
      <table id='ctl00_Registry_Data'><tr><td><p>Record Alpha</p>
      <div id='ctl00_Registry_Data_ctl01_Body'><p><a href='https://publication.example.test/independent'>Record Alpha</a></p>
      <p>Complete declaration.</p></div></td></tr></table>
    HTML
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.css('p').map(&:text)).to eq(['Record Alpha', 'Record Alpha', 'Complete declaration.'])
      expect(rendered.css('a').map { |link| [link.text, link['href']] }).to eq(
        [['Record Alpha', 'https://publication.example.test/independent']]
      )
    end
  end

  it 'retains a named target on a separately addressable generated label' do
    html = <<~HTML
      <table id='ctl00_Registry_Data'><tr><td><p>Record Alpha</p>
      <div id='ctl00_Registry_Data_ctl01_Body'><p id='published-label'>Record Alpha</p>
      <p>Complete declaration.</p></div></td></tr></table>
    HTML
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.css('p').map(&:text)).to eq(['Record Alpha', 'Record Alpha', 'Complete declaration.'])
      expect(rendered.css('#published-label').map(&:text)).to eq(['Record Alpha'])
    end
  end

  it 'preserves genuinely authored repeated prose and independent inline emphasis' do
    html = <<~HTML
      <table><tr><td><p>Published statement.</p><div><p>Published statement.</p><p>Complete context.</p></div></td></tr></table>
      <table id='ctl00_Registry_Data'><tr><td><p>Record Alpha</p>
      <div id='ctl00_Registry_Data_ctl01_Body'><p><em>Record Alpha</em></p><p>Independent emphasis.</p></div></td></tr></table>
    HTML
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.css('table').first.css('p').map(&:text)).to eq(
        ['Published statement.', 'Published statement.', 'Complete context.']
      )
      expect(rendered.css('table').last.css('p').map(&:text)).to eq(
        ['Record Alpha', 'Record Alpha', 'Independent emphasis.']
      )
      expect(rendered.css('em').map(&:text)).to eq(['Record Alpha'])
    end
  end

  it 'retains equal labels in independent physical records and literal comparison text' do
    rows = (1..2).map do |index|
      "<tr><td><p>Record Alpha</p><div id='ctl00_Registry_Data_ctl0#{index}_Body'>" \
        "<p>Independent declaration #{index}.</p><pre><code>left &lt; right &amp;&amp; repeat_label()</code></pre></div></td></tr>"
    end.join
    with_raw_table("<table id='ctl00_Registry_Data'>#{rows}</table>") do |rendered, _markdown|
      expect(rendered.css('td').map { |cell| cell.css('p').map(&:text) }).to eq(
        [['Record Alpha', 'Independent declaration 1.'], ['Record Alpha', 'Independent declaration 2.']]
      )
      expect(rendered.css('pre code').map(&:text)).to eq(['left < right && repeat_label()'] * 2)
    end
  end

  it 'keeps distinct footnote numbers rather than joining their whitespace' do
    html = <<~HTML
      <table id="ctl00_Registry_Data"><tr><td>
        <p>Record Alpha <sup><a href="#1">1</a> <a href="#2">2</a></sup></p>
        <div id="ctl00_Registry_Data_ctl01_Body">
          <p>Record Alpha<superscript>12</superscript></p>
          <p>Independent authored annotation.</p>
        </div>
      </td></tr></table>
    HTML
    with_raw_table(html) do |table, _markdown|
      body = table.at_css('#ctl00_Registry_Data_ctl01_Body')
      expect(body.css('p').map(&:text)).to eq(['Record Alpha12', 'Independent authored annotation.'])
      expect(table.css('a').map { |link| [link.text, link['href']] }).to eq(
        [['1', 'https://publication.example.test/docs/manual/#1'], ['2', 'https://publication.example.test/docs/manual/#2']]
      )
    end
  end

  it 'keeps a label whose footnote has a different physical word position' do
    html = <<~HTML
      <table id="ctl00_Registry_Data"><tr><td>
        <p>Record <sup><a href="#1">1</a></sup> Alpha</p>
        <div id="ctl00_Registry_Data_ctl01_Body">
          <p>Record Alpha<superscript>1</superscript></p>
          <p>Independent authored annotation.</p>
        </div>
      </td></tr></table>
    HTML
    with_raw_table(html) do |table, _markdown|
      body = table.at_css('#ctl00_Registry_Data_ctl01_Body')
      expect(body.css('p').map(&:text)).to eq(['Record Alpha1', 'Independent authored annotation.'])
      expect(table.css('a').map { |link| [link.text, link['href']] }).to eq(
        [['1', 'https://publication.example.test/docs/manual/#1']]
      )
    end
  end
end
