RSpec.describe 'Activity labels in named program illustrations' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://software.publication.example.test/overview' }
  let(:paragraph) do
    'This publication explains the complete workflow, its independently documented observations and the resulting ' \
      'operational guarantees. The examples retain their participants, status labels and literal program output.'
  end
  let(:program) { "plan_result = { created: 3, changed: 1 }\nputs plan_result.inspect" }

  def activity_page(labelled: true, action: true, code: true, global_author: nil, declared_author: nil, named_author: false)
    name_class = named_author ? 'author-name' : 'event-name'
    label = labelled ? " aria-label='An example review and its resulting program output'" : ''
    action_html = action ? "<span class='event-action'>commented</span>" : ''
    program_html = code ? "<pre>#{program}</pre>" : ''
    page_author = global_author ? "<p class='byline'>#{global_author}</p>" : ''
    meta = declared_author ? "<meta name='author' content='#{declared_author}'>" : ''
    <<~HTML
      <html><head><title>Workflow overview</title>#{meta}</head><body><main>
        <h1>Workflow overview</h1><p>#{paragraph}</p>
        <div role='group'#{label}>
          <div class='review-comment'>
            <div class='event-author'><span class='#{name_class}'>Ari Reader</span> #{action_html}</div>
            #{program_html}<ul><li>All review checks remain available.</li></ul>
            <p><a href='/reference'>Complete workflow reference</a></p>
          </div>
        </div>
        #{page_author}<p>#{paragraph}</p>
      </main></body></html>
    HTML
  end

  def inspect_activity(html, expected_byline, code: true)
    with_url_page(url, html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(payload['byline']).to eq(expected_byline)
      expect(payload['html']).to include(paragraph, 'Ari Reader', 'All review checks remain available.')
      expect(payload['markdown']).to include(paragraph, 'Ari Reader', 'All review checks remain available.')
      expect(payload['html']).to include('https://software.publication.example.test/reference')
      expect(payload['markdown']).to include('https://software.publication.example.test/reference')
      expect(Nokogiri::HTML.fragment(payload['html']).css('pre').map(&:text)).to eq(code ? [program] : [])
      expect(payload['markdown']).to include(program) if code
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    end
  end

  it 'does not promote a named illustration activity label to page attribution' do
    inspect_activity(activity_page, nil)
  end

  it 'retains an independent page author after the illustration' do
    inspect_activity(activity_page(global_author: 'Editorial Team'), 'Editorial Team')
  end

  it 'retains a declared page author without borrowing illustration participants' do
    inspect_activity(activity_page(declared_author: 'Editorial Team'), 'Editorial Team')
  end

  it 'retains an ordinary author beside a program without a separate activity field' do
    inspect_activity(activity_page(action: false), 'Ari Reader')
  end

  it 'keeps an independently marked author name separate from its status' do
    inspect_activity(activity_page(named_author: true), 'Ari Reader')
  end

  it 'does not infer an illustration from an unlabelled group alone' do
    inspect_activity(activity_page(labelled: false), 'Ari Reader commented')
  end

  it 'does not infer a program illustration where no program exists' do
    inspect_activity(activity_page(code: false), 'Ari Reader commented', code: false)
  end
end
