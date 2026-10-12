# frozen_string_literal: true

RSpec.describe 'FetchUtil scoped physical visibility reads' do
  include_context 'extractor integration helpers'

  def visibility_read_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.withVisibilityRead = withSourceVisibilityRead;
      global.subtreeHidden = elementSubtreeHiddenWithin;
      })(window);
    JAVASCRIPT
  end

  def visibility_read_page(html)
    with_url_page('https://publication.example.test/reports/complete', html) do |page|
      page.add_script_tag(content: visibility_read_source)
      yield page
    end
  end

  it 'checks each immutable physical element once while retaining every repeated record' do
    records = (1..200).map { |number| "<p><a href='/records/#{number}'>Complete published record #{number}</a></p>" }.join
    wrappers = '<div>' * 12
    endings = '</div>' * 12
    html = "<main>#{wrappers}#{records}#{endings}</main>"
    result = visibility_read_page(html) do |page|
      page.evaluate(<<~JAVASCRIPT)
        (() => {
          var original = window.getComputedStyle;
          var descriptor = Object.getOwnPropertyDescriptor(window, 'getComputedStyle');
          var calls = 0;
          window.getComputedStyle = function() { calls += 1; return original.apply(this, arguments); };
          try {
            var links = Array.from(document.querySelectorAll('main a[href]'));
            var expected = links.map(function(link) { return subtreeHidden(link, null); });
            var baseline = calls;
            calls = 0;
            var answers = withVisibilityRead(function() {
              return [1, 2, 3].map(function() {
                return links.map(function(link) { return subtreeHidden(link, null); });
              });
            });
            return {expected: expected, answers: answers, calls: calls, baseline: baseline,
              sourceElements: document.querySelectorAll('*').length,
              records: links.map(function(link) { return link.textContent; })};
          } finally {
            if (descriptor) Object.defineProperty(window, 'getComputedStyle', descriptor);
            else delete window.getComputedStyle;
          }
        })()
      JAVASCRIPT
    end

    expect(result.fetch('expected')).to eq(Array.new(200, false))
    expect(result.fetch('answers')).to eq(Array.new(3) { Array.new(200, false) })
    expect(result.fetch('baseline')).to be > result.fetch('sourceElements')
    expect(result.fetch('calls')).to be <= result.fetch('sourceElements')
    expect(result.fetch('records')).to eq((1..200).map { |number| "Complete published record #{number}" })
  end

  it 'preserves clipping, source boundaries and composed shadow or slot ownership' do
    html = <<~HTML
      <div hidden><div id="boundary"><p id="bounded">Preserved boundary text</p></div></div>
      <div style="display:none"><p id="display">Hidden display text</p></div>
      <div style="opacity:0"><p id="opacity">Hidden opacity text</p></div>
      <div style="height:0;overflow:hidden"><p id="clipped">Clipped text</p></div>
      <div style="height:0;overflow:hidden"><p id="escaping" style="position:absolute">Out of flow text</p></div>
      <div id="shadow"><p id="unassigned">Unassigned light text</p></div>
      <div id="slotted"><p id="assigned">Assigned light text</p></div>
      <p id="visible">Visible published text</p>
    HTML
    result = visibility_read_page(html) do |page|
      page.evaluate(<<~JAVASCRIPT)
        (() => {
          document.getElementById('shadow').attachShadow({mode: 'open'}).innerHTML = '<p>Shadow content</p>';
          document.getElementById('slotted').attachShadow({mode: 'open'}).innerHTML = '<slot></slot>';
          return withVisibilityRead(function() {
            var bounded = document.getElementById('bounded');
            var answers = [subtreeHidden(bounded, null), subtreeHidden(bounded, document.getElementById('boundary'))];
            ['display', 'opacity', 'clipped', 'escaping', 'unassigned', 'assigned', 'visible'].forEach(function(id) {
              answers.push(subtreeHidden(document.getElementById(id), null));
            });
            return answers;
          });
        })()
      JAVASCRIPT
    end

    expect(result).to eq([true, false, true, true, true, false, true, false, false])
  end

  it 'keeps detached mutations fresh and restores nested or exceptional source reads' do
    result = visibility_read_page('<p id="source">Physical source text</p>') do |page|
      page.evaluate(<<~JAVASCRIPT)
        (() => {
          var source = document.getElementById('source');
          var detached = document.createElement('div');
          var answers = [];
          try {
            withVisibilityRead(function() {
              answers.push(subtreeHidden(source, null), subtreeHidden(detached, null));
              detached.hidden = true;
              answers.push(subtreeHidden(detached, null));
              source.hidden = true;
              try {
                withVisibilityRead(function() { answers.push(subtreeHidden(source, null)); throw new Error('nested'); });
              } catch (error) { if (error.message !== 'nested') throw error; }
              source.hidden = false;
              answers.push(subtreeHidden(source, null));
              throw new Error('outer');
            });
          } catch (error) { if (error.message !== 'outer') throw error; }
          source.hidden = true;
          answers.push(subtreeHidden(source, null));
          source.hidden = false;
          answers.push(subtreeHidden(source, null));
          return answers;
        })()
      JAVASCRIPT
    end

    expect(result).to eq([false, false, true, true, false, true, false])
  end
end
