require "test_helper"

class Users::SidebarsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in :david
  end

  test "show" do
    get user_sidebar_url

    users(:david).rooms.opens.each do |room|
      assert_match /#{room.name}/, @response.body
    end
  end

  test "unread directs" do
    rooms(:david_and_jason).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select "#direct_rooms .unread", count: users(:david).memberships.select { |m| m.room.direct? && m.unread? }.count
  end


  test "unread other" do
    rooms(:watercooler).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select "#shared_rooms .unread", count: users(:david).memberships.reject { |m| m.room.direct? || !m.unread? }.count
  end

  test "shared rooms render newest first on initial load" do
    rooms(:hq).update!(last_active_at: 1.hour.ago)
    rooms(:watercooler).update!(last_active_at: 2.hours.ago)
    rooms(:pets).update!(last_active_at: 3.hours.ago)

    get user_sidebar_url

    nodes = css_select("#shared_rooms [data-type='list_node']")
    ids = nodes.first(3).map { |node| node["id"] }

    expected = [
      dom_id(rooms(:hq), "shared_rooms_list_node"),
      dom_id(rooms(:watercooler), "shared_rooms_list_node"),
      dom_id(rooms(:pets), "shared_rooms_list_node")
    ]

    assert_equal expected, ids
  end
end
