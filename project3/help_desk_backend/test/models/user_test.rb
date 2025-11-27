require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with username and password" do
    user = User.new(username: "alice", password: "password123")
    assert user.valid?, user.errors.full_messages.join(", ")
  end

  test "requires unique username" do
    User.create!(username: "boba", password: "password123")
    dup = User.new(username: "boba", password: "password123")
    assert_not dup.valid?
    assert_includes dup.errors[:username], "has already been taken"
  end

  test "password must be at least 5 characters" do
    user = User.new(username: "shawtie", password: "1234")
    assert_not user.valid?
  end

  test "authenticate works" do
    user = User.create!(username: "charlie", password: "password123")
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong")
  end
end
