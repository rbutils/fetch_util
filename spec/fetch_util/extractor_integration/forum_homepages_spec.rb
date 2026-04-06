# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - forum homepages' do
  include_context 'extractor integration helpers'

  it "extracts thread links from a Discourse-style topic list and strips forum chrome" do
    html = <<~HTML
      <html>
        <head><title>Ruby Community Forum</title></head>
        <body>
          <header>
            <a href="/">Ruby Community Forum</a>
            <nav>
              <a href="/categories">Categories</a>
              <a href="/latest">Latest</a>
              <a href="/top">Top</a>
              <a href="/login">Log In</a>
            </nav>
          </header>
          <main>
            <div class="topic-list">
              <div class="topic-list-item"><h3><a href="/t/how-to-use-ractors-in-ruby-3/1234">How to use Ractors in Ruby 3</a></h3><span>42 replies - Last post 2h ago</span></div>
              <div class="topic-list-item"><h3><a href="/t/best-practices-for-testing-rails-apps/1235">Best practices for testing Rails apps</a></h3><span>18 replies - Last post 5h ago</span></div>
              <div class="topic-list-item"><h3><a href="/t/understanding-ruby-memory-allocation/1236">Understanding Ruby memory allocation</a></h3><span>27 replies - Last post 1d ago</span></div>
              <div class="topic-list-item"><h3><a href="/t/migrating-from-minitest-to-rspec/1237">Migrating from Minitest to RSpec</a></h3><span>15 replies - Last post 2d ago</span></div>
              <div class="topic-list-item"><h3><a href="/t/ruby-pattern-matching-real-world-examples/1238">Ruby pattern matching real world examples</a></h3><span>31 replies - Last post 3d ago</span></div>
            </div>
            <div class="forum-stats">
              <p>Forum Statistics</p>
              <p>Members online: 142</p>
              <p>Active threads: 847</p>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://forum.ruby-lang.org/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("How to use Ractors in Ruby 3")
      expect(payload["markdown"]).to include("Best practices for testing Rails apps")
      expect(payload["markdown"]).not_to include("Forum Statistics")
      expect(payload["markdown"]).not_to include("Members online")
      expect(payload["markdown"]).not_to include("Categories")
    end
  end

  it "filters forum meta-links like Last Post and Mark Forum Read from list items" do
    html = <<~HTML
      <html>
        <head><title>Tech Forums</title></head>
        <body>
          <main>
            <div class="threadlist">
              <div class="threadbit">
                <h3><a href="/threads/gpu-benchmarks-2026.5001/">GPU benchmarks 2026 comprehensive comparison</a></h3>
                <span>124 replies</span>
                <a href="/threads/gpu-benchmarks-2026.5001/page-12#post-last">Last Post</a>
                <a href="/threads/gpu-benchmarks-2026.5001/#post-1">First Unread</a>
              </div>
              <div class="threadbit">
                <h3><a href="/threads/best-linux-distro-for-devs.5002/">Best Linux distro for developers in 2026</a></h3>
                <span>87 replies</span>
                <a href="/threads/best-linux-distro-for-devs.5002/page-8#post-last">Last Post</a>
              </div>
              <div class="threadbit">
                <h3><a href="/threads/mechanical-keyboard-recommendations.5003/">Mechanical keyboard recommendations thread</a></h3>
                <span>203 replies</span>
                <a href="/threads/mechanical-keyboard-recommendations.5003/page-15#post-last">Last Post</a>
              </div>
              <div class="threadbit">
                <h3><a href="/threads/homelab-setup-guide.5004/">Complete homelab setup guide and tips</a></h3>
                <span>56 replies</span>
              </div>
              <div class="threadbit">
                <h3><a href="/threads/rust-vs-go-2026.5005/">Rust vs Go in 2026 which to choose</a></h3>
                <span>312 replies</span>
              </div>
            </div>
            <div class="sidebar">
              <a href="/forums/mark-read">Mark Forum Read</a>
              <a href="/forums/new-thread">Post New Thread</a>
              <a href="/forums/rules">Forum Rules</a>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://forums.example.com/forums/hardware/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("GPU benchmarks 2026")
      expect(payload["markdown"]).to include("Best Linux distro for developers")
      expect(payload["markdown"]).to include("Mechanical keyboard recommendations")
      expect(payload["markdown"]).not_to match(/\bLast Post\b/)
      expect(payload["markdown"]).not_to match(/\bFirst Unread\b/)
      expect(payload["markdown"]).not_to match(/\bMark Forum Read\b/)
      expect(payload["markdown"]).not_to match(/\bPost New Thread\b/)
      expect(payload["markdown"]).not_to match(/\bForum Rules\b/)
    end
  end

  it "strips Who Is Online and Members Online noise from forum index pages" do
    html = <<~HTML
      <html>
        <head><title>Community Discussion Board</title></head>
        <body>
          <main>
            <table class="forumlist">
              <tr><td><h3><a href="/forum/general-discussion/">General Discussion</a></h3><p>Talk about anything and everything</p></td><td>1,432 threads</td></tr>
              <tr><td><h3><a href="/forum/tech-support/">Technical Support and Troubleshooting</a></h3><p>Get help with hardware and software issues</p></td><td>876 threads</td></tr>
              <tr><td><h3><a href="/forum/marketplace/">Buy Sell Trade Marketplace</a></h3><p>Buy sell and trade with community members</p></td><td>543 threads</td></tr>
              <tr><td><h3><a href="/forum/off-topic/">Off Topic Lounge and Chat</a></h3><p>Relax and chat about non-tech topics</p></td><td>2,100 threads</td></tr>
              <tr><td><h3><a href="/forum/gaming/">Gaming Discussion and Reviews</a></h3><p>Discuss the latest games and gaming hardware</p></td><td>1,876 threads</td></tr>
              <tr><td><h3><a href="/forum/networking/">Networking and Server Administration</a></h3><p>Home and enterprise networking topics</p></td><td>654 threads</td></tr>
              <tr><td><h3><a href="/forum/programming/">Programming and Software Development</a></h3><p>Code discussions and development help</p></td><td>2,341 threads</td></tr>
              <tr><td><h3><a href="/forum/mobile/">Mobile Devices and Tablets</a></h3><p>Smartphones tablets and mobile accessories</p></td><td>987 threads</td></tr>
              <tr><td><h3><a href="/forum/security/">Security and Privacy Forum</a></h3><p>Cybersecurity privacy and data protection</p></td><td>432 threads</td></tr>
            </table>
          </main>
          <aside class="board-stats">
            <h4>Board Statistics</h4>
            <p>Who is online: 234 users browsing this forum</p>
            <p>Currently active users: admin, moderator1, user42</p>
            <p>Forum contains no new posts since your last visit</p>
          </aside>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-forum.com/community/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("General Discussion")
      expect(payload["markdown"]).to include("Technical Support")
      expect(payload["markdown"]).not_to include("Board Statistics")
      expect(payload["markdown"]).not_to include("Who is online")
      expect(payload["markdown"]).not_to include("Currently active users")
    end
  end

  it "preserves thread content containers with thread/discussion class names as non-chrome" do
    html = <<~HTML
      <html>
        <head><title>Developer Forum - Latest Threads</title></head>
        <body>
          <header>
            <nav><a href="/">Home</a><a href="/forums">Forums</a></nav>
          </header>
          <div class="discussion-list">
            <div class="discussion-item"><h3><a href="/d/100">How to optimize PostgreSQL queries for large datasets</a></h3><p>Started 3 days ago - 24 replies</p></div>
            <div class="discussion-item"><h3><a href="/d/101">Docker container networking best practices</a></h3><p>Started 1 week ago - 18 replies</p></div>
            <div class="discussion-item"><h3><a href="/d/102">Understanding WebSocket connection handling</a></h3><p>Started 2 weeks ago - 45 replies</p></div>
            <div class="discussion-item"><h3><a href="/d/103">Kubernetes pod scheduling and resource limits</a></h3><p>Started 3 weeks ago - 12 replies</p></div>
            <div class="discussion-item"><h3><a href="/d/104">Redis caching strategies for high traffic apps</a></h3><p>Started 1 month ago - 67 replies</p></div>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://devforum.example.com/discussions", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("How to optimize PostgreSQL queries")
      expect(payload["markdown"]).to include("Docker container networking")
      expect(payload["markdown"]).to include("Redis caching strategies")
    end
  end

  it "extracts XenForo-style structItem thread containers with noise sidebar stripped" do
    html = <<~HTML
      <html>
        <head><title>Hardware Enthusiasts Forum</title></head>
        <body>
          <main>
            <div class="structItemContainer">
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/ryzen-9000-series-review.10001/">Ryzen 9000 series comprehensive review and benchmarks</a></h3></div>
                <div class="structItem-minor">Replies: 89 - Views: 4,521</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/best-nvme-drives-2026.10002/">Best NVMe drives for gaming and productivity in 2026</a></h3></div>
                <div class="structItem-minor">Replies: 45 - Views: 2,103</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/ddr5-vs-ddr4-real-world.10003/">DDR5 vs DDR4 real world performance comparison</a></h3></div>
                <div class="structItem-minor">Replies: 112 - Views: 8,234</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/psu-tier-list-2026.10004/">Power supply tier list and recommendations 2026</a></h3></div>
                <div class="structItem-minor">Replies: 67 - Views: 3,891</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/monitor-buyer-guide.10005/">Ultimate monitor buying guide for all budgets</a></h3></div>
                <div class="structItem-minor">Replies: 156 - Views: 12,045</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/cpu-cooler-roundup.10006/">CPU cooler roundup air versus liquid cooling tested</a></h3></div>
                <div class="structItem-minor">Replies: 78 - Views: 5,432</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/gpu-undervolting-guide.10007/">GPU undervolting guide for better thermals and efficiency</a></h3></div>
                <div class="structItem-minor">Replies: 134 - Views: 9,876</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/best-budget-peripherals.10008/">Best budget gaming peripherals under fifty dollars</a></h3></div>
                <div class="structItem-minor">Replies: 92 - Views: 6,210</div>
              </div>
              <div class="structItem">
                <div class="structItem-title"><h3><a href="/threads/mini-itx-build-log.10009/">Mini ITX build log compact powerhouse workstation</a></h3></div>
                <div class="structItem-minor">Replies: 41 - Views: 3,102</div>
              </div>
            </div>
            <div class="online-users">
              <h4>Members Online</h4>
              <p>42 members, 312 guests</p>
            </div>
            <div class="quick-reply">
              <a href="/threads/new">Post New Thread</a>
              <a href="/forums/mark-read">Mark Forums Read</a>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://forums.example.com/forums/hardware.5/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("Ryzen 9000 series comprehensive review")
      expect(payload["markdown"]).to include("DDR5 vs DDR4 real world performance")
      expect(payload["markdown"]).to include("Ultimate monitor buying guide")
      expect(payload["markdown"]).not_to include("Members Online")
      expect(payload["markdown"]).not_to include("42 members, 312 guests")
      expect(payload["markdown"]).not_to match(/\bMark Forums Read\b/)
    end
  end
end
