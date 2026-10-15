# frozen_string_literal: true

RSpec.describe 'FetchUtil synchronous shadow reader capability' do
  include_context 'extractor integration helpers'

  def shadow_reader_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source = source.sub('(function(global) {', '(function(global) { var window = global;')
    export = <<~JS
      global.shadowReaderProbe = withComposedDomRead(function(options) {
        var rows = Array.from(document.querySelectorAll('p'));
        var text = rows.map(function(node) {
          var detached = document.createElement('span');
          detached.id = 'unrelated-named-item';
          return composedDomChildren(node).map(function(child) { return child.textContent; }).join('');
        });
        var host = document.querySelector('#host');
        var before = host && composedDomChildren(host).map(function(node) { return node.textContent; }).join('');
        var nested = host && withComposedDomRead(function() {
          return composedDomChildren(host).map(function(node) { return node.textContent; }).join('');
        })({ shadow_root_reader_property: 'absent_nested_reader', shadow_root_token: 'token' });
        var after = host && composedDomChildren(host).map(function(node) { return node.textContent; }).join('');
        return {text: text, before: before, nested: nested, after: after};
      });
      })(new Proxy(window, {
        get: function(target, property) {
          if (property === 'probe_reader') target.readerLookups++;
          return Reflect.get(target, property, target);
        }
      }));
    JS
    source.sub('})(window);', export)
  end

  it 'retains every physical record without repeated named-window lookups for an absent private bridge' do
    records = (1..240).map { |number| "<p>Published record #{number}</p>" }.join
    with_url_page('https://publication.example.test/reference/capability', records) do |page|
      page.evaluate('window.readerLookups = 0')
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: shadow_reader_probe)
      result = page.evaluate("window.shadowReaderProbe({shadow_root_reader_property:'probe_reader',shadow_root_token:'token'})")
      expect(result.fetch('text')).to eq((1..240).map { |number| "Published record #{number}" })
      expect(page.evaluate('window.readerLookups')).to eq(0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'rediscovers installed immutable readers and restores their owner after a nested absent read' do
    with_url_page('https://publication.example.test/reference/capability', '<div id="host"></div><p>Published body</p>') do |page|
      page.evaluate('window.readerLookups = 0')
      page.add_script_tag(content: shadow_reader_probe)
      options = "{shadow_root_reader_property:'probe_reader',shadow_root_token:'token'}"
      expect(page.evaluate("window.shadowReaderProbe(#{options})").fetch('before')).to eq('')
      page.evaluate(<<~JS)
        (() => {
          var host = document.querySelector('#host');
          var root = host.attachShadow({mode:'closed'});
          root.innerHTML = '<p>Complete closed reporting</p>';
          Object.defineProperty(window, 'probe_reader', {value:function(token, operation, node) {
            return token === 'token' && operation === 'get' && node === host ? root : null;
          }});
        })()
      JS
      result = page.evaluate("window.shadowReaderProbe(#{options})")
      expect(result.values_at('before', 'nested', 'after')).to eq(['Complete closed reporting', '', 'Complete closed reporting'])
      expect(result.fetch('text')).to eq(['Published body'])
      expect(page.evaluate('window.readerLookups')).to eq(0)
    end
  end

  it 'keeps mutable accessor readers fresh instead of caching a getter result' do
    records = (1..24).map { |number| "<p>Published value #{number}</p>" }.join
    with_url_page('https://publication.example.test/reference/capability', records) do |page|
      page.evaluate(<<~JS)
        (() => {
          window.readerLookups = 0;
          window.readerGetterCalls = 0;
          Object.defineProperty(window, 'probe_reader', {configurable:true, get:function() {
            window.readerGetterCalls++;
            return function() { return null; };
          }});
        })()
      JS
      page.add_script_tag(content: shadow_reader_probe)
      result = page.evaluate("window.shadowReaderProbe({shadow_root_reader_property:'probe_reader',shadow_root_token:'token'})")
      expect(result.fetch('text')).to eq((1..24).map { |number| "Published value #{number}" })
      expect(page.evaluate('window.readerGetterCalls')).to be >= 24
      expect(page.evaluate('window.readerLookups')).to be >= 24
    end
  end
end
