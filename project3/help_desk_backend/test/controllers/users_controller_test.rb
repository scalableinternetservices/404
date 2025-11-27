require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "POST /users/register creates a user" do
    post "/users/register", params: { username: "newuser", password: "password123" }
    assert_response :created
    data = JSON.parse(response.body)
    assert_equal "newuser", data["username"]
    assert data["id"].present?
  end

  test "POST /users/register fails on duplicate username" do
    User.create!(username: "dup", password: "password123")
    post "/users/register", params: { username: "dup", password: "anotherpass" }
    assert_response :unprocessable_entity
    data = JSON.parse(response.body)
    assert data.key?("errors")
  end
end
