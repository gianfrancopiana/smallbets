class RemoveStarsFromConversationRooms < ActiveRecord::Migration[7.2]
  def up
    # Remove stars from all existing conversation rooms
    # Conversation rooms are identified by having a source_room_id
    conversation_room_ids = Room.where.not(source_room_id: nil).pluck(:id)
    
    return if conversation_room_ids.empty?
    
    Membership.where(room_id: conversation_room_ids, involvement: "everything")
              .update_all(involvement: "mentions", updated_at: Time.current)
  end

  def down
    # No-op: we can't know which memberships were previously starred
  end
end
