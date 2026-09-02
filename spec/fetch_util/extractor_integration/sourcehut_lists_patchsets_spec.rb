# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - SourceHut lists patchsets' do
  include_context 'extractor integration helpers'

  def sourcehut_patchset_fixture
    fixture_contents(File.expand_path('../fixtures/sourcehut_lists_patchset.html', __dir__))
  end

  it 'preserves a host-agnostic patchset conversation and traversal inventory' do
    extract_from_url('https://lists.example.test/~alice/project-list/patches/42', sourcehut_patchset_fixture,
                     reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'SourceHut',
                                 'handle' => 'Alice', 'replyCount' => nil, 'community' => '~alice/project-list',
                                 'publishedTime' => '2025-02-03 04:05 UTC')
      expect(markdown).to include(
        '# PATCH: Preserve patchset review', '- Version: v2', '- Status: NEEDS REVISION',
        '## Cover letter', 'Authored cover letter for the patchset.', 'Restored cover detail.',
        'Continuous integration passed.', 'Restored tool event.', 'older revision', 'newer revision',
        '[Feedback by Bob](https://lists.example.test/~alice/project-list/patches/42#feedback-standalone)',
        'Standalone review feedback.', 'Restored standalone feedback.',
        '[PATCH 1/3: Add parser by Alice](https://lists.example.test/~alice/project-list/patch-one/raw)',
        'Patch one body.', 'Restored patch line.', 'Inline rendering of standalone feedback.',
        'Quoted raw URL.',
        'Patch two body.', 'Patch three body.',
        '[Patchset mbox](https://lists.example.test/~alice/project-list/patches/42/mbox): Patches only',
        '[Archive thread](https://lists.example.test/~alice/project-list/thread/message)',
        '[Full thread mbox](https://lists.example.test/~alice/project-list/thread/message/mbox)',
        '[Raw patch: PATCH 2/3: Add tests](https://lists.example.test/~alice/project-list/patch/two/raw)',
        '[PATCH 3/3: Add docs by Unregistered Author]',
        '[Source repository](https://git.example.test/~alice/project)'
      )
      expect(markdown.scan('Repeated idless feedback.').length).to eq(2)
      expect(markdown.scan('Repeated dangling feedback.').length).to eq(2)
      expect(markdown.scan('Standalone review feedback.').length).to eq(1)
      expect(markdown).not_to include('Duplicate stable feedback must not render', 'Hidden standalone feedback',
                                      'Hidden cover text', 'Hidden tool event', 'Hidden patch body')
      expect(markdown.index('Continuous integration passed.')).to be < markdown.index('Standalone review feedback.')
      expect(markdown.index('Standalone review feedback.')).to be < markdown.index('Patch one body.')
      expect(markdown.index('Patch one body.')).to be < markdown.index('Patch three body.')
      expect(payload.fetch('html')).not_to include('Hidden standalone feedback', '<style')
    end
  end

  it 'labels generated patch summaries without fabricating a cover letter' do
    html = sourcehut_patchset_fixture
           .sub('id="cover-42" href="#cover-42"', 'id="patch-one" href="#patch-one"')
           .sub('Authored cover letter for the patchset.', 'Alice: 3 generated patch summaries.')

    extract_from_url('https://lists.example.test/~alice/project-list/patches/42', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## Generated patch summary', '3 generated patch summaries')
      expect(payload.fetch('markdown')).not_to include('## Cover letter')
    end
  end

  it 'preserves an uncapped patchset in source order' do
    records = (1..25).map do |index|
      <<~HTML
        <h3>PATCH bulk #{index} <a class="btn" href="/~alice/project-list/bulk-#{index}/raw">Export</a></h3>
        <div class="message-header"><div class="from"><a href="/~bulk">Bulk Author</a></div><div class="date"><a id="bulk-#{index}" href="#bulk-#{index}">2025-03-#{format("%02d", index)} UTC</a></div></div>
        <pre class="message-body">Uncapped SourceHut patch #{index}.</pre>
      HTML
    end.join
    html = sourcehut_patchset_fixture.sub('<!-- bulk-patches -->', records)

    extract_from_url('https://lists.example.test/~alice/project-list/patches/42', html, reader_mode: false) do |payload|
      found = payload.fetch('markdown').scan(/Uncapped SourceHut patch (\d+)\./).flatten.map(&:to_i)
      expect(found).to eq((1..25).to_a)
    end
  end

  it 'requires independent SourceHut lists product evidence' do
    variants = {
      without_asset: sourcehut_patchset_fixture.gsub(%r{\s*<link rel="stylesheet" href="/static/lists\.sr\.ht/[^"]+">}, ''),
      off_origin_asset: sourcehut_patchset_fixture.sub('href="/static/', 'href="https://lookalike.invalid/static/'),
      off_origin_navigation: sourcehut_patchset_fixture.gsub(
        'href="/~alice/project-list',
        'href="https://lookalike.invalid/~alice/project-list'
      ),
      without_mbox: sourcehut_patchset_fixture.sub('/patches/42/mbox', '/patches/42/download'),
      without_archive: sourcehut_patchset_fixture.sub('View this thread in the archives', 'Unrelated resource'),
      without_raw_patch: sourcehut_patchset_fixture.gsub('/raw"', '/download"')
    }

    variants.each do |name, html|
      aggregate_failures(name) do
        extract_from_url('https://lists.example.test/~alice/project-list/patches/42', html, reader_mode: false) do |payload|
          expect(payload['platform']).not_to eq('SourceHut')
        end
      end
    end
  end

  it 'keeps malformed and non-patchset routes outside SourceHut lists extraction' do
    [
      'https://lists.example.test/~alice/project-list/patches',
      'https://lists.example.test/~alice/project-list/patches/not-a-number',
      'https://lists.example.test/~alice/.git/patches/42',
      'https://lists.example.test/~alice/project-list/patches/42/extra',
      'https://lists.example.test//~alice/project-list/patches/42'
    ].each do |url|
      extract_from_url(url, sourcehut_patchset_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('SourceHut')
      end
    end
  end
end
