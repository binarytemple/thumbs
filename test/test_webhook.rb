
class WebhookTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Thumbs

  def app
    ThumbsWeb
  end


  def test_can_access_repo

    cassette(:simple_repo) do
      repository = Octokit.repo 'thumbot/prtester'
      assert_not_nil repository
      assert_equal 'prtester', repository.name
    end

  end

  def test_can_get_pr

    cassette(:get_basic_pr) do
      prw = Thumbs::PullRequestWorker.new(:repo => TESTREPO, :pr => TESTPR)
      assert !prw.nil?
      assert prw.kind_of?(Thumbs::PullRequestWorker)
      assert_equal "thumbot/prtester", prw.pr.base.repo.full_name
      assert_equal "thumbot/prtester", prw.repo
      assert_equal TESTPR, prw.pr.number
    end

  end

  def test_can_get_status
    cassette(:get_ratelimit) do
      get '/status'
      assert last_response.body.include?("<pre>"), last_response.body
      last_response_yaml=last_response.body.gsub!(/(\<pre\>|\<\/pre\>)/, '')
      status_hash=YAML.load(last_response_yaml)
      assert status_hash.key?(:status), status_hash.inspect
      assert status_hash.key?(:version)
      assert status_hash.key?(:rate_limit)
    end
  end
  def test_new_push_hook

  end
  def test_new_comment_hook

  end
  def test_new_pr_hook
    cassette(:load_pr, :record => :new_episodes) do
      prw = Thumbs::PullRequestWorker.new(:repo => 'thumbot/prtester', :pr => TESTPR)

      build_dir="/tmp/thumbs/#{prw.repo.gsub(/\//, '_')}_#{prw.pr.head.sha.slice(0, 8)}"
      FileUtils.rm_rf(build_dir)
      assert_equal false, File.exist?(build_dir)

      new_pr_webhook_payload = {
          'repository' => {'full_name' => prw.repo},
          'number' => prw.pr.number,
          'pull_request' => {'number' => prw.pr.number, 'body' => prw.pr.body}
      }
      assert prw.build_status[:steps].keys.length == 1
      assert prw.build_status[:steps].key?(:merge)
      remove_comments(prw.repo, prw.pr.number)
      cassette(:get_comments, :record => :all) do
        cassette(:get_issue_comments, :record => :all) do
          original_comments_length=prw.comments.length

          cassette(:post_webhook_new_pr, :record => :all) do

            post '/webhook', new_pr_webhook_payload.to_json do
              assert last_response.body.include?("OK"), last_response.body

              cassette(:get_pullrequest_update, :record => :all) do
                cassette(:get_open, :record => :all) do
                  assert prw.open?
                  new_review_count = prw.review_count
                end
                assert_equal :completed, prw.build_progress_status
              end
            end
          end
        end
      end
    end
  end
end


# def test_webhook_mergeable_pr_test
#   VCR.use_cassette(:create_pr) do
#
#     prw = create_test_pr("thumbot/prtester")
#
#
#   assert prw.comments.length == 0
#   assert prw.review_count == 0
#   assert prw.bot_comments.length == 0
#
#   new_pr_webhook_payload = {
#       'repository' => {'full_name' => prw.repo},
#       'number' => prw.pr.number,
#       'pull_request' => {'number' => prw.pr.number, 'body' => prw.pr.body}
#   }
#
#   post '/webhook', new_pr_webhook_payload.to_json
#
#   assert_true last_response.body.include?("OK"), last_response.body
#
#   assert_true prw.open?
#   assert prw.review_count == 0
#
#   assert prw.comments.length == 1
#   assert prw.bot_comments.length == 1
#   assert_true prw.open?
#
#   assert prw.comments.first['body'] =~ /Build Status/
#
#   create_test_code_reviews(prw.repo, prw.pr.number)
#
#   assert prw.review_count >= 2
#
#   new_comment_payload = {
#       'repository' => {'full_name' => prw.repo},
#       'issue' => {'number' => prw.pr.number,
#                   'pull_request' => {}
#       },
#       'comment' => {'body' => "looks good"}
#   }
#
#   assert payload_type(new_comment_payload) == :new_comment, payload_type(new_comment_payload).to_s
#
#   post "/webhook", new_comment_payload.to_json
#
#   assert last_response.body.include?("OK"), last_response.body
#
#   assert_false prw.open?
#   prw.close
#
# end


# end
