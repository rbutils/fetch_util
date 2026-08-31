# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'waits for delayed France24 article bodies after generic stabilization' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = browser_with_idle

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(browser).to receive(:safe_evaluate).and_return({})
    allow(browser).to receive(:wait_for_idle_or_content).with(page).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).with(page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener').and_return(true)
    allow(browser).to receive(:wait_for_spa_hydration).with(page)
    expect(browser).not_to receive(:accept_cookie_consent)
    expect(browser).not_to receive(:dismiss_privacy_preference_overlay)
    allow(browser).to receive(:sleep)
    expect(browser).to receive(:wait_for_france24_article).with(page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener')

    browser.send(:stabilize_page, page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener')
  end

  it 'waits for the requested Telegram preview message before extraction' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle

    expect(browser).to receive(:wait_for_anubis_challenge).with(page).and_return(true).ordered
    expect(browser).to receive(:wait_for_telegram_message).with(page).ordered

    browser.send(:stabilize_page, page, 'https://t.me/s/examplechannel/42')
  end

  it 'routes GitLab project roots through repository stabilization' do
    browser = browser_with_idle
    profiles = FetchUtil::Browser::Stabilization::PageFlow::PAGE_FLOW_STABILIZATION_PROFILES
    strategy_for = lambda do |url|
      browser.send(:matching_stabilization_profile, url, profiles)&.fetch(:strategy)
    end

    expect(strategy_for.call('https://gitlab.com/group/project')).to eq(:stabilize_gitlab_repo)
    expect(strategy_for.call('https://about.gitlab.com/group/project')).to eq(:stabilize_gitlab_repo)
    expect(strategy_for.call('https://gitlab.com/group/project/issues')).to be_nil
    expect(strategy_for.call('https://example.com/group/project')).to be_nil
    expect(strategy_for.call('not a URL')).to be_nil
  end

  it 'routes only GitHub thread roots through timeline stabilization' do
    browser = browser_with_idle
    profiles = FetchUtil::Browser::Stabilization::PageFlow::PAGE_FLOW_STABILIZATION_PROFILES
    strategy_for = lambda do |url|
      browser.send(:matching_stabilization_profile, url, profiles)&.fetch(:strategy)
    end

    expect(strategy_for.call('https://github.com/octo/example/issues/12')).to eq(:stabilize_github_thread)
    expect(strategy_for.call('https://github.com/octo/example/pull/42')).to eq(:stabilize_github_thread)
    expect(strategy_for.call('https://github.com/octo/example/discussions/9')).to eq(:stabilize_github_thread)
    expect(strategy_for.call('https://github.com/octo/example/pull/42/commits')).to eq(:stabilize_github_pull_resource)
    expect(strategy_for.call('https://github.com/octo/example/pull/42/checks?check_run_id=7')).to eq(:stabilize_github_pull_resource)
    expect(strategy_for.call('https://github.com/octo/example/pull/42/files#diff-123')).to eq(:stabilize_github_pull_resource)
    expect(strategy_for.call('https://github.com/octo/example/pull/42/unknown')).to be_nil
    expect(strategy_for.call('https://github.com/octo/example')).to be_nil
  end

  it 'routes host-agnostic GitLab conversations through product-aware stabilization' do
    browser = browser_with_idle
    profiles = FetchUtil::Browser::Stabilization::PageFlow::PAGE_FLOW_STABILIZATION_PROFILES
    strategy_for = lambda do |url|
      browser.send(:matching_stabilization_profile, url, profiles)&.fetch(:strategy)
    end

    expect(strategy_for.call('https://forge.example/group/project/-/issues/12')).to eq(:stabilize_gitlab_thread)
    expect(strategy_for.call('https://code.example/group/subgroup/project/-/work_items/12')).to eq(:stabilize_gitlab_thread)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42')).to eq(:stabilize_gitlab_thread)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/commits')).to eq(:stabilize_gitlab_merge_request_resource)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/pipelines')).to eq(:stabilize_gitlab_merge_request_resource)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/reports/codequality')).to eq(:stabilize_gitlab_merge_request_resource)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/reports/codequality/')).to eq(:stabilize_gitlab_merge_request_resource)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/diffs#diff-a')).to eq(:stabilize_gitlab_merge_request_resource)
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/commits/not-real')).to be_nil
    expect(strategy_for.call('https://git.example/group/project/-/merge_requests/42/reports/codequality/detail')).to be_nil
    expect(strategy_for.call('https://git.example/group/project/issues/12')).to eq(:stabilize_gitea_family_thread)
  end

  it 'routes host-agnostic Gitea-family conversations through product-aware stabilization' do
    browser = browser_with_idle
    profiles = FetchUtil::Browser::Stabilization::PageFlow::PAGE_FLOW_STABILIZATION_PROFILES
    strategy_for = lambda do |url|
      browser.send(:matching_stabilization_profile, url, profiles)&.fetch(:strategy)
    end

    expect(strategy_for.call('https://code.example/forgejo/repo/issues/42')).to eq(:stabilize_gitea_family_thread)
    expect(strategy_for.call('https://code.example/forgejo/repo/pulls/42')).to eq(:stabilize_gitea_family_thread)
    expect(strategy_for.call('https://git.example/forge/alice/project/issues/7')).to eq(:stabilize_gitea_family_thread)
    expect(strategy_for.call('https://code.example/forgejo/repo/pulls/42/files')).to be_nil
    expect(strategy_for.call('https://code.example/forgejo/repo/issues/not-a-number')).to be_nil
    expect(strategy_for.call('https://github.com/octo/example/issues/12')).to eq(:stabilize_github_thread)
  end

  it 'waits for a product-matched Gitea-family timeline to remain stable' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    scripts = []
    states = [
      { "product" => true, "ready" => false, "signature" => "1:1:0::true:40" },
      { "product" => true, "ready" => true, "signature" => "4:3:1:alice:false:400" },
      { "product" => true, "ready" => true, "signature" => "4:3:1:alice:false:400" },
      { "product" => true, "ready" => true, "signature" => "4:3:1:alice:false:400" }
    ]

    allow(browser).to receive(:safe_evaluate) do |_page, script, default:|
      scripts << script
      states.shift || { "product" => true, "ready" => true, "signature" => "4:3:1:alice:false:400" }
    end
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    expect(browser.send(:stabilize_gitea_family_thread, page)).to be(true)

    expect(scripts.first).to include('window.config || {}', 'runtime.appSubUrl', 'new URL(runtime.appUrl',
                                     'runtime.assetUrlPrefix',
                                     '.page-content.repository.view.issue .issue-content',
                                     '.timeline-item.comment.issue-content-comment', '.timeline-item-group',
                                     '.dropzone-attachments a[href]', '.timeline-item.comment.merge.box',
                                     '.pull-merge-box', 'some(visible)', 'openingReady', 'rowSignatures')
    expect(browser).to have_received(:safe_evaluate).exactly(4).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'resets Gitea-family stability when ordered row identities change without changing counts' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    states = [
      { "product" => true, "ready" => true, "signature" => "3:2:1:alice:true:false:row-a" },
      { "product" => true, "ready" => true, "signature" => "3:2:1:alice:true:false:row-b" },
      { "product" => true, "ready" => true, "signature" => "3:2:1:alice:true:false:row-b" },
      { "product" => true, "ready" => true, "signature" => "3:2:1:alice:true:false:row-b" }
    ]
    allow(browser).to receive(:safe_evaluate) { states.shift }
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    expect(browser.send(:stabilize_gitea_family_thread, page)).to be(true)
    expect(browser).to have_received(:safe_evaluate).exactly(4).times
  end

  it 'falls through after a stable non-loading Gitea-family skeleton remains incomplete' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 6.0)
    state = { "product" => true, "ready" => false, "loading" => false, "signature" => "skeleton" }
    allow(browser).to receive(:safe_evaluate).and_return(state)
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    expect(browser.send(:stabilize_gitea_family_thread, page)).to be(false)
    expect(browser).to have_received(:safe_evaluate).exactly(10).times
    expect(browser).not_to have_received(:settle_after_stabilization)
  end

  it 'falls through immediately when a Gitea-family-shaped route lacks product evidence' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 8.0)
    allow(browser).to receive(:safe_evaluate).and_return(
      { "product" => false, "ready" => false, "signature" => "" }
    )
    allow(browser).to receive(:sleep)
    allow(browser).to receive(:settle_after_stabilization)

    expect(browser.send(:stabilize_gitea_family_thread, page)).to be(false)
    expect(browser).to have_received(:safe_evaluate).once
    expect(browser).not_to have_received(:sleep)
    expect(browser).not_to have_received(:settle_after_stabilization)
  end

  it 'waits for a product-matched GitLab timeline to remain stable' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    scripts = []
    states = [
      { "product" => true, "ready" => false, "signature" => "0:0:false" },
      { "product" => true, "ready" => true, "signature" => "3:2:true" },
      { "product" => true, "ready" => true, "signature" => "3:2:true" },
      { "product" => true, "ready" => true, "signature" => "3:2:true" }
    ]

    allow(browser).to receive(:safe_evaluate) do |_page, script, default:|
      scripts << script
      states.shift || { "product" => true, "ready" => true, "signature" => "3:2:true" }
    end
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    expect(browser.send(:stabilize_gitlab_thread, page)).to be(true)

    expect(scripts.first).to include("document.documentElement.classList.contains('gl-system')", "window.gon || {}",
                                     "new URL(gon.gitlab_url, location.href).origin === location.origin",
                                     ".js-timeline-entry.timeline-entry", "continuation.click()", "textSize")
    expect(scripts.first.index('const loading')).to be < scripts.first.index('const continuation')
    expect(browser).to have_received(:safe_evaluate).exactly(4).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'falls through immediately when a GitLab-shaped route lacks product evidence' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 8.0)
    allow(browser).to receive(:safe_evaluate).and_return(
      { "product" => false, "ready" => false, "signature" => "" }
    )
    allow(browser).to receive(:sleep)
    allow(browser).to receive(:settle_after_stabilization)

    expect(browser.send(:stabilize_gitlab_thread, page)).to be(false)
    expect(browser).to have_received(:safe_evaluate).once
    expect(browser).not_to have_received(:sleep)
    expect(browser).not_to have_received(:settle_after_stabilization)
  end

  it 'waits for a selected GitLab merge-request resource to remain stable' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    scripts = []
    states = [
      { "product" => true, "ready" => false, "signature" => "diffs:0:false:false:0" },
      { "product" => true, "ready" => true, "signature" => "diffs:3:false:true:400" },
      { "product" => true, "ready" => true, "signature" => "diffs:3:false:true:400" },
      { "product" => true, "ready" => true, "signature" => "diffs:3:false:true:400" }
    ]

    allow(browser).to receive(:safe_evaluate) do |_page, script, default:|
      scripts << script
      states.shift || { "product" => true, "ready" => true, "signature" => "diffs:3:false:true:400" }
    end
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    expect(browser.send(:stabilize_gitlab_merge_request_resource, page)).to be(true)

    expect(scripts.first).to include("const surface = match[1].split('/')", "diff-file[data-testid=\"rd-diff-file\"]",
                                     "decodeURIComponent((location.hash || '').replace(/^#/, ''))", "data-diff-id",
                                     "row.getAttribute('data-file-path')", "other.contains(row)",
                                     "while (reserved.has(identity) || assigned.has(identity))", "const textSize",
                                     "document.querySelector('main') ||", "Object.prototype.hasOwnProperty.call",
                                     "Array.from(rows[selectedIndex].querySelectorAll(bodySelector)).some")
    expect(browser).to have_received(:safe_evaluate).exactly(4).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'falls through immediately when a GitLab resource route lacks product evidence' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 8.0)
    allow(browser).to receive(:safe_evaluate).and_return(
      { "product" => false, "ready" => false, "signature" => "" }
    )
    allow(browser).to receive(:sleep)
    allow(browser).to receive(:settle_after_stabilization)

    expect(browser.send(:stabilize_gitlab_merge_request_resource, page)).to be(false)
    expect(browser).to have_received(:safe_evaluate).once
    expect(browser).not_to have_received(:sleep)
    expect(browser).not_to have_received(:settle_after_stabilization)
  end

  it 'waits for stable GitHub pull-request resources' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    scripts = []
    states = [
      { "ready" => false, "signature" => "files:0:0::#diff-one" },
      { "ready" => true, "signature" => "files:12:400::#diff-one" },
      { "ready" => true, "signature" => "files:12:400::#diff-one" },
      { "ready" => true, "signature" => "files:12:400::#diff-one" }
    ]

    allow(browser).to receive(:safe_evaluate) do |_page, script, default:|
      scripts << script
      states.shift || { "ready" => true, "signature" => "files:12:400::#diff-one" }
    end
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    browser.send(:stabilize_github_pull_resource, page)

    expect(scripts.first).to include('[data-testid="commit-row-item"]', 'a[href*="check_run_id="]',
                                     '.file-header[data-path][data-anchor]', "document.getElementById('check_run_' + requestedCheckId)",
                                     'nodeVisible', 'selectedRequested', 'selectedReady')
    expect(browser).to have_received(:safe_evaluate).exactly(4).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'waits for a GitHub timeline after its opening body appears' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    scripts = []
    states = [
      { "ready" => false, "complete" => false, "signature" => "1:0:4 comments:false" },
      { "ready" => true, "complete" => false, "signature" => "4:1:4 comments:false" },
      { "ready" => true, "complete" => false, "signature" => "4:1:4 comments:false" },
      { "ready" => true, "complete" => false, "signature" => "4:1:4 comments:false" }
    ]

    allow(browser).to receive(:safe_evaluate) do |_page, script, default:|
      scripts << script
      states.shift || { "ready" => true, "complete" => false, "signature" => "4:1:4 comments:false" }
    end
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    browser.send(:stabilize_github_thread, page)

    expect(scripts.first).to include(
      'const commentRows',
      '#issuecomment-',
      'a[rel~="next"][href*="timeline_page="]',
      'button[data-testid*="timeline-load-more"]',
      "control.getAttribute('aria-disabled') === 'true'",
      'usableContinuation',
      'complete: false'
    )
    expect(scripts.first).not_to include('commentRows.length >= expected')
    expect(browser).to have_received(:safe_evaluate).exactly(4).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'requires an unknown-size GitHub timeline to remain stable' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    state = { "ready" => true, "complete" => false, "signature" => "3::false" }

    allow(browser).to receive(:safe_evaluate).and_return(state)
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    browser.send(:stabilize_github_thread, page)

    expect(browser).to have_received(:safe_evaluate).exactly(3).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'restarts GitHub stability when a continuation becomes usable' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    states = [
      { "ready" => true, "complete" => false, "signature" => "1:1:1 comment:false" },
      { "ready" => true, "complete" => false, "signature" => "1:1:1 comment:true" },
      { "ready" => true, "complete" => false, "signature" => "1:1:1 comment:true" },
      { "ready" => true, "complete" => false, "signature" => "1:1:1 comment:true" }
    ]

    allow(browser).to receive(:safe_evaluate) do
      states.shift || { "ready" => true, "complete" => false, "signature" => "1:1:1 comment:true" }
    end
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    browser.send(:stabilize_github_thread, page)

    expect(browser).to have_received(:safe_evaluate).exactly(4).times
    expect(browser).to have_received(:settle_after_stabilization).with(0.5)
  end

  it 'stabilizes a simple page fixture without the generic consent wait' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0.75, wait_for_idle: true)

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(browser).to receive(:safe_evaluate).and_return({})
    allow(browser).to receive(:wait_for_idle_or_content).with(page).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).with(page, 'https://example.com').and_return(false)
    allow(browser).to receive(:accept_cookie_consent).with(page).and_return(false)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).with(page).and_return(false)
    allow(browser).to receive(:wait_for_spa_hydration).with(page)
    allow(browser).to receive(:sleep)
    browser.send(:stabilize_page, page, 'https://example.com')

    expect(browser).not_to have_received(:sleep).with(0.75)
    expect(browser).to have_received(:accept_cookie_consent).once
    expect(browser).to have_received(:dismiss_privacy_preference_overlay).once
  end

  it 'uses a bounded lodging detail wait for Airbnb room pages' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle

    allow(browser).to receive(:accept_cookie_consent).with(page).and_return(false)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).with(page).and_return(false)
    allow(browser).to receive(:safe_evaluate).and_return(true)
    allow(browser).to receive(:settle_after_stabilization)

    browser.send(:stabilize_page, page, 'https://www.airbnb.com/rooms/123456789')

    expect(browser).to have_received(:safe_evaluate).with(page, include('LodgingBusiness'), default: false)
    expect(browser).not_to have_received(:settle_after_stabilization)
  end

  it 'continues Reddit readiness polling after an evaluation timeout' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    attempts = 0

    allow(page).to receive(:evaluate) do
      attempts += 1
      raise Ferrum::TimeoutError, 'timed out' if attempts == 1

      true
    end
    allow(browser).to receive(:dismiss_reddit_cookie_dialog).with(page).and_return(false)
    allow(browser).to receive(:settle_after_stabilization)
    allow(browser).to receive(:sleep)

    browser.send(:stabilize_reddit, page)

    expect(attempts).to eq(2)
    expect(browser).to have_received(:settle_after_stabilization).with(0.25)
  end

  it 'resolves a short same-URL page after a rendered Anubis shell' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    states = [
      { 'challenge' => true, 'document_ready' => false, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    ]

    allow(browser).to receive(:safe_evaluate) { states.shift || states.last }

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'accepts Anubis resolution that navigates to a different URL' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)

    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/.within.website/challenge' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/article' }
    )

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'does not resolve on a transient evaluation failure' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)

    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      {},
      { 'challenge' => false, 'document_ready' => false, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'retries an invalid initial Anubis observation once' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)

    allow(browser).to receive(:safe_evaluate).and_return(
      {},
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'stops at the browser timeout when Anubis remains unresolved' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 0.05)
    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )
    allow(browser).to receive(:sleep)

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(false)
  end

  it 'does not poll ordinary pages for challenge completion' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle
    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )
    expect(browser).not_to receive(:retry_until_timeout)

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(false)
  end
end
