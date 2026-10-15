# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Complete text normalization work' do
  include_context 'extractor integration helpers'

  def normalization_source(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.normalizationWorkProbe = function() { #{body} }; })(window);")
  end

  it 'retains every word without allocating replacement records for normalized separators' do
    with_url_page('https://publication.example.test/reference/manual', '<p>Complete published reference.</p>') do |page|
      page.add_script_tag(content: normalization_source(<<~'JS'))
        var words = Array.from({length: 20000}, function(_, index) { return 'published_word_' + index; });
        var text = words.join(' ');
        var descriptor = Object.getOwnPropertyDescriptor(RegExp.prototype, Symbol.replace);
        var matches = 0;
        Object.defineProperty(RegExp.prototype, Symbol.replace, {value: function(input, replacement) {
          if (input === text) {
            var probe = new RegExp(this.source, this.flags);
            var match;
            while ((match = probe.exec(input))) {
              matches++;
              if (!probe.global) break;
              if (!match[0]) probe.lastIndex++;
            }
          }
          return descriptor.value.call(this, input, replacement);
        }});
        try { return {complete: normalizeText(text) === text, matches: matches}; }
        finally { Object.defineProperty(RegExp.prototype, Symbol.replace, descriptor); }
      JS
      expect(page.evaluate('normalizationWorkProbe()')).to eq('complete' => true, 'matches' => 0)
    end
  end

  it 'keeps all ECMAScript whitespace, mixed runs, Unicode content and input coercion semantics' do
    with_url_page('https://publication.example.test/reference/manual', '<p>Complete published reference.</p>') do |page|
      page.add_script_tag(content: normalization_source(<<~'JS'))
        var spaces = ['\t', '\n', '\v', '\f', '\r', ' ', '\u00a0', '\u1680', '\u2000', '\u2001',
          '\u2002', '\u2003', '\u2004', '\u2005', '\u2006', '\u2007', '\u2008', '\u2009', '\u200a',
          '\u2028', '\u2029', '\u202f', '\u205f', '\u3000', '\ufeff'];
        var samples = [];
        spaces.forEach(function(first) {
          spaces.forEach(function(second) {
            samples.push(normalizeText(first + 'Published' + first + second + 'Ω' + second + 'material' + second));
          });
        });
        return {samples: samples, literal: normalizeText('漢字\u200b🙂'), empty: normalizeText(' \t\n\u00a0'),
          coerced: [null, undefined, 0, -0, false, 123n, Symbol('field'), ['complete', 'value'],
            {toString: function() { return '  Published\tvalue  '; }}].map(normalizeText)};
      JS
      result = page.evaluate('normalizationWorkProbe()')
      expect(result.fetch('samples')).to eq(Array.new(625, 'Published Ω material'))
      expect(result).to include('literal' => "漢字\u200b🙂", 'empty' => '')
      expect(result.fetch('coerced')).to eq(['', '', '0', '0', 'false', '123', 'Symbol(field)', 'complete,value', 'Published value'])
    end
  end
end
