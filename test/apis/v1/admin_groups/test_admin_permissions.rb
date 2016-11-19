require_relative "../../../test_helper"

class TestApisV1AdminGroupsAdminPermissions < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    AdminGroup.delete_all
    ApiScope.delete_all
  end

  def test_default_permissions_single_scope
    factory = :google_admin_group
    assert_default_admin_permissions(factory, :required_permissions => ["admin_manage"])
  end

  def test_multi_scope_permitted_as_superuser
    factory = :google_and_yahoo_multi_scope_admin_group
    admin = FactoryGirl.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_multi_scope_permitted_as_multi_scope_admin
    factory = :google_and_yahoo_multi_scope_admin_group
    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_multi_scope_forbidden_as_single_scope_admin
    factory = :google_and_yahoo_multi_scope_admin_group

    google_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, google_admin)

    yahoo_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, yahoo_admin)
  end

  def test_forbids_updating_permitted_groups_with_unpermitted_values
    record = FactoryGirl.create(:google_admin_group)
    yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
    admin = FactoryGirl.create(:limited_admin, :groups => [record])

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))
    assert_equal(204, response.code, response.body)

    attributes["api_scope_ids"] << yahoo_api_scope.id
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = AdminGroup.find(record.id)
    assert_equal(1, record.api_scope_ids.length)
  end

  def test_forbids_updating_unpermitted_groups_with_permitted_values
    record = FactoryGirl.create(:yahoo_admin_group)
    yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
    google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))
    admin = FactoryGirl.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))
    assert_equal(403, response.code, response.body)

    attributes["api_scope_ids"] = [google_api_scope.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = AdminGroup.find(record.id)
    assert_equal([yahoo_api_scope.id], record.api_scope_ids)
  end

  private

  def assert_admin_permitted(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    assert_admin_permitted_create(factory, admin)
    assert_admin_permitted_update(factory, admin)
    assert_admin_permitted_destroy(factory, admin)
  end

  def assert_admin_forbidden(factory, admin)
    assert_admin_forbidden_index(factory, admin)
    assert_admin_forbidden_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_admin_forbidden_destroy(factory, admin)
  end

  def assert_admin_permitted_index(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", @@http_options.deep_merge(admin_token(admin)))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", @@http_options.deep_merge(admin_token(admin)))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["admin_group"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin)
    attributes = FactoryGirl.build(factory).serializable_hash
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))

    assert_equal(201, response.code, response.body)
    data = MultiJson.load(response.body)
    refute_equal(nil, data["admin_group"]["name"])
    assert_equal(attributes["name"], data["admin_group"]["name"])
    assert_equal(1, active_count - initial_count)
  end

  def assert_admin_forbidden_create(factory, admin)
    attributes = FactoryGirl.build(factory).serializable_hash
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin)
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))

    assert_equal(204, response.code, response.body)
    record = AdminGroup.find(record.id)
    refute_equal(nil, record.name)
    assert_equal(attributes["name"], record.name)
  end

  def assert_admin_forbidden_update(factory, admin)
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin_group => attributes },
    }))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = AdminGroup.find(record.id)
    refute_equal(nil, record.name)
    refute_equal(attributes["name"], record.name)
  end

  def assert_admin_permitted_destroy(factory, admin)
    record = FactoryGirl.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)))
    assert_equal(204, response.code, response.body)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    record = FactoryGirl.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    AdminGroup.where(:deleted_at => nil).count
  end
end
