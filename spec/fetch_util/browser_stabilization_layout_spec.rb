# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'browser stabilization layout' do
  let(:root) { File.expand_path('../../lib/fetch_util/browser/site_stabilization', __dir__) }

  it 'keeps only top-level stabilization families at the root' do
    expect(Dir.children(root).sort).to eq([
                                            'communities',
                                            'communities.rb',
                                            'forges',
                                            'forges.rb',
                                            'marketplaces',
                                            'marketplaces.rb',
                                            'social',
                                            'social.rb',
                                            'travel',
                                            'travel.rb'
                                          ])
  end

  it 'keeps community and marketplace stabilizers in separate families' do
    expect(Dir[File.join(root, 'communities/**/*.rb')].map { |path| path.delete_prefix("#{root}/") }).to eq([
                                                                                                              'communities/reddit.rb'
                                                                                                            ])
    expect(Dir[File.join(root, 'marketplaces/**/*.rb')].map { |path| path.delete_prefix("#{root}/") }).to eq([
                                                                                                               'marketplaces/ebay.rb'
                                                                                                             ])
  end

  it 'keeps social stabilizers grouped by platform' do
    expect(Dir[File.join(root, 'social/**/*.rb')].map { |path| path.delete_prefix("#{root}/") }.sort).to eq([
                                                                                                              'social/facebook.rb',
                                                                                                              'social/instagram.rb'
                                                                                                            ])
  end

  it 'keeps travel stabilizers grouped by content family' do
    expect(Dir[File.join(root, 'travel/**/*.rb')].map { |path| path.delete_prefix("#{root}/") }.sort).to eq([
                                                                                                              'travel/lodging.rb'
                                                                                                            ])
  end

  it 'keeps forge stabilizers grouped by product and resource family' do
    forge_root = File.join(root, 'forges')
    paths = Dir[File.join(forge_root, '**/*.rb')]
            .map { |path| path.delete_prefix("#{forge_root}/") }
            .sort

    expect(paths).to eq([
                          'azure_devops/pull_requests/commit_details_script.rb',
                          'azure_devops/pull_requests/product_state_script.rb',
                          'azure_devops/pull_requests/request_helpers_script.rb',
                          'azure_devops/pull_requests/request_state_script.rb',
                          'azure_devops/pull_requests/stabilization.rb',
                          'azure_devops/pull_requests/state.rb',
                          'bitbucket/pulls/diff/product_state.rb',
                          'bitbucket/pulls/diff/request_state.rb',
                          'bitbucket/pulls/diff/state.rb',
                          'bitbucket/pulls/resource_modules.rb',
                          'bitbucket/pulls/resource_state.rb',
                          'bitbucket/pulls/resources.rb',
                          'bitbucket/threads/index.rb',
                          'bitbucket/threads/state.rb',
                          'gerrit/changes/product_state_script.rb',
                          'gerrit/changes/request_state_script.rb',
                          'gerrit/changes/stabilization.rb',
                          'gerrit/changes/state.rb',
                          'gerrit/resources/fetch_state_script.rb',
                          'gerrit/resources/product_state_script.rb',
                          'gerrit/resources/request_state_script.rb',
                          'gerrit/resources/route_state_script.rb',
                          'gerrit/resources/stabilization.rb',
                          'gerrit/resources/state.rb',
                          'gerrit/resources/validation_state_script.rb',
                          'gitea/pulls/product_state.rb',
                          'gitea/pulls/resources.rb',
                          'gitea/pulls/state.rb',
                          'gitea/stabilization.rb',
                          'gitea/threads/index.rb',
                          'gitea/threads/product_state.rb',
                          'gitea/threads/timeline_state.rb',
                          'gitea/visibility_script.rb',
                          'github/pull_resource_stabilization.rb',
                          'github/pull_resources.rb',
                          'github/threads.rb',
                          'gitlab/merge_requests/resource_state.rb',
                          'gitlab/merge_requests/resource_state_script.rb',
                          'gitlab/merge_requests/resource_visibility_script.rb',
                          'gitlab/merge_requests/resources.rb',
                          'gitlab/repository.rb',
                          'gitlab/stabilization.rb',
                          'gitlab/threads.rb'
                        ])
  end
end
