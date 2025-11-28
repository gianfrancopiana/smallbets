require "test_helper"

class RoomMembershipBroadcastJobTest < ActiveJob::TestCase
  test "does not broadcast sidebar HTML for conversation rooms" do
    parent_room = rooms(:watercooler)
    conversation_room = Rooms::Closed.create!(name: "Spinoff", creator: users(:david), source_room: parent_room)
    membership = conversation_room.memberships.create!(user: users(:david), involvement: :mentions)

    ActionCable.server.pubsub.clear
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 0 do
      RoomMembershipBroadcastJob.perform_now(membership)
    end
  end
end

