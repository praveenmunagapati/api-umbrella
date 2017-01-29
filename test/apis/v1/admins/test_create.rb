require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestCreate < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_downcases_username
    attributes = FactoryGirl.build(:admin, :username => "HELLO@example.com").serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal("HELLO@example.com", attributes["username"])
    assert_equal("hello@example.com", data["admin"]["username"])

    admin = Admin.find(data["admin"]["id"])
    assert_equal("hello@example.com", admin.username)
  end

  def test_required_validations
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => {} },
    }))
    assert_response_code(422, response)

    data = MultiJson.load(response.body)
    assert_equal([
      "Email: can't be blank",
      "Groups: must belong to at least one group or be a superuser",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)
  end
end
