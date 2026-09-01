# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Bitbucket Cloud threads' do
  include_context 'extractor integration helpers'

  def bitbucket_fixture
    fixture_contents(File.expand_path('../fixtures/bitbucket_cloud_pull_request.html', __dir__))
  end

  it 'extracts every loaded pull-request comment and exposes traversal inventory' do
    extract_from_url('https://code.example.test/workspace/project/pull-requests/42', bitbucket_fixture,
                     reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Bitbucket',
                                 'handle' => 'alice', 'replyCount' => nil, 'community' => 'workspace/project')
      expect(markdown).to include(
        '# Preserve complete Bitbucket pull requests', 'Opening body keeps', 'Restored opening detail survives',
        '[Comment by bob](https://code.example.test/workspace/project/pull-requests/42#comment-101)',
        '[Comment by carol](https://code.example.test/workspace/project/pull-requests/42#comment-103)',
        '[Review by reviewer](https://code.example.test/workspace/project/pull-requests/42/diff#comment-102)',
        'Nested loaded reply', 'src/widget.js:42', 'Restored inline review survives',
        'Parent comment without nested metadata',
        '[Review by nested-reviewer](https://code.example.test/workspace/project/pull-requests/42/_/diff#comment-104)',
        'src/nested.js:7', 'Nested review keeps its own fields',
        '## Metadata', 'Reviewer: maintainer',
        '[Commits](https://code.example.test/workspace/project/pull-requests/42/commits)',
        '[Diff](https://code.example.test/workspace/project/pull-requests/42/diff)',
        '[Reports](https://code.example.test/workspace/project/pull-requests/42/reports)',
        'https://api.bitbucket.org/2.0/repositories/workspace/project/pullrequests/42/activity',
        "Follow the response's opaque next link until it is absent"
      )
      expect(markdown.scan('Repeated idless Bitbucket record.').length).to eq(2)
      expect(markdown).not_to include('Hidden opening text', 'Hidden inline review text', 'Hidden comment',
                                      'Duplicate permalink must not create another record',
                                      'Alias path duplicate must not create another record', 'Reply controls',
                                      'hidden-opening-author', 'hidden-comment-author', 'Hidden pull request title')
      expect(payload.fetch('html')).not_to include('Hidden opening text', 'Hidden inline review text', 'Reply controls')
      expect(payload.fetch('html').scan('Nested loaded reply.').length).to eq(1)
      expect(markdown.scan('src/nested.js:7').length).to eq(1)
      expect(markdown.index('First loaded comment.')).to be < markdown.index('Nested loaded reply.')
      expect(markdown.index('Nested loaded reply.')).to be < markdown.index('Restored inline review survives.')
    end
  end

  it 'preserves an uncapped conversation in DOM order' do
    bulk = (1..25).map do |index|
      <<~HTML
        <article data-testid="comment" id="comment-#{200 + index}">
          <a data-testid="comment-author">user#{index}</a>
          <a href="#comment-#{200 + index}"><time datetime="2026-09-01T10:#{index.to_s.rjust(2, "0")}:00Z">Sep 1</time></a>
          <div data-testid="comment-content"><p>Uncapped Bitbucket comment #{index}.</p></div>
        </article>
      HTML
    end.join
    html = bitbucket_fixture.sub('<!-- bulk-comments -->', bulk)

    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/overview', html,
                     reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped Bitbucket comment #{index}.") }).to be(true)
      expect(markdown.index('Uncapped Bitbucket comment 1.')).to be < markdown.index('Uncapped Bitbucket comment 25.')
    end
  end

  it 'requires matching runtime identity and independent product evidence' do
    mismatched = bitbucket_fixture.sub('full_name: "workspace/project"', 'full_name: "other/project"')
    lookalike = bitbucket_fixture.sub('<meta name="application-name" content="Bitbucket">', '')
    private_repository = bitbucket_fixture.sub('is_private: false', 'is_private: true')

    [mismatched, lookalike, private_repository].each do |html|
      extract_from_url('https://code.example.test/workspace/project/pull-requests/42', html, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Bitbucket')
      end
    end
  end

  it 'keeps resource, malformed, and unrelated routes outside conversation extraction' do
    [
      'https://code.example.test/workspace/project/pull-requests/42/commits',
      'https://code.example.test/workspace/project/pull-requests/not-a-number',
      'https://code.example.test/workspace/project/issues/42'
    ].each do |url|
      extract_from_url(url, bitbucket_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Bitbucket')
      end
    end
  end

  it 'executes the actual Browser state script against product and lookalike fixtures' do
    browser = FetchUtil::Browser.new(timeout: 1)
    with_url_page('https://code.example.test/workspace/project/pull-requests/42', bitbucket_fixture) do |page|
      state = page.evaluate(browser.send(:bitbucket_cloud_thread_state_script))
      expect(state).to include('product' => true, 'ready' => true, 'loading' => false)
      expect(state.fetch('signature')).to include('comment-101', 'comment-102')
    end

    without_opening = bitbucket_fixture.sub(%r{\s*<section id="pull-request-description-panel".*?</section>}m, '')
    with_url_page('https://code.example.test/workspace/project/pull-requests/42', without_opening) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_thread_state_script))).to include(
        'product' => true, 'ready' => false
      )
    end

    without_main = bitbucket_fixture.sub('<main>', '').sub('</main>', '')
    with_url_page('https://code.example.test/workspace/project/pull-requests/42', without_main) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_thread_state_script))).to include(
        'product' => true, 'ready' => true
      )
    end

    collapsed = bitbucket_fixture.gsub(
      /data-testid="comment-content"(?: style="[^"]*")?/,
      'data-testid="comment-content" style="visibility:collapse"'
    ).gsub('style="visibility:visible"', 'style="visibility:collapse"')
    with_url_page('https://code.example.test/workspace/project/pull-requests/42', collapsed) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_thread_state_script))).to include(
        'product' => true, 'ready' => false
      )
    end

    with_url_page('https://code.example.test/workspace/project/error', bitbucket_fixture) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_thread_state_script))).to include('product' => false)
    end

    lookalike = bitbucket_fixture.sub('full_name: "workspace/project"', 'full_name: "other/project"')
    with_url_page('https://code.example.test/workspace/project/pull-requests/42', lookalike) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_thread_state_script))).to include('product' => false)
    end
  end
end
