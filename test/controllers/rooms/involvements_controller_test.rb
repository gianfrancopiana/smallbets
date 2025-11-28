require "test_helper"

class Rooms::InvolvementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show" do
    get room_involvement_url(rooms(:designers))
    assert_response :success
  end

  test "update involvement sends turbo update when becoming visible and when going invisible" do
    ActionCable.server.pubsub.clear
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 4 do
    assert_changes -> { memberships(:david_watercooler).reload.involvement }, from: "everything", to: "invisible" do
      put room_involvement_url(rooms(:watercooler)), params: { involvement: "invisible" }
      assert_redirected_to room_involvement_url(rooms(:watercooler))
    end
    end

    ActionCable.server.pubsub.clear
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 4 do
    assert_changes -> { memberships(:david_watercooler).reload.involvement }, from: "invisible", to: "everything" do
      put room_involvement_url(rooms(:watercooler)), params: { involvement: "everything" }
      assert_redirected_to room_involvement_url(rooms(:watercooler))
    end
    end
  end

  test "updating involvement sends turbo update when changing visible states" do
    ActionCable.server.pubsub.clear
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 2 do
    assert_changes -> { memberships(:david_watercooler).reload.involvement }, from: "everything", to: "mentions" do
      put room_involvement_url(rooms(:watercooler)), params: { involvement: "mentions" }
      assert_redirected_to room_involvement_url(rooms(:watercooler))
    end
    end
  end

  test "updating involvement sends turbo update for direct rooms" do
    ActionCable.server.pubsub.clear
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 2 do
    assert_changes -> { memberships(:david_david_and_jason).reload.involvement }, from: "everything", to: "nothing" do
      put room_involvement_url(rooms(:david_and_jason)), params: { involvement: "nothing" }
      assert_redirected_to room_involvement_url(rooms(:david_and_jason))
    end
    end
  end

  test "conversation rooms never broadcast to the sidebar" do
    parent_room = rooms(:watercooler)
    conversation_room = Rooms::Closed.create!(name: "Spin-off", creator: users(:david), source_room: parent_room)
    membership = conversation_room.memberships.create!(user: users(:david), involvement: :mentions)

    ActionCable.server.pubsub.clear
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 0 do
    assert_changes -> { membership.reload.involvement }, from: "mentions", to: "everything" do
      put room_involvement_url(conversation_room), params: { involvement: "everything" }
      assert_redirected_to room_involvement_url(conversation_room)
    end
    end
  end
end
