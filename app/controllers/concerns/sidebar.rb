module Sidebar
  extend ActiveSupport::Concern

  module Visibility
    module_function

    def room_visible?(room)
      room.present? && !room.conversation_room?
    end

  end

  module Broadcasting
    module_function

    def append_to(stream, *stream_names, room: nil, membership: nil, **options)
      broadcast(:append, stream, *stream_names, room:, membership:, **options)
    end

    def replace_to(stream, *stream_names, room: nil, membership: nil, **options)
      broadcast(:replace, stream, *stream_names, room:, membership:, **options)
    end

    def prepend_to(stream, *stream_names, room: nil, membership: nil, **options)
      broadcast(:prepend, stream, *stream_names, room:, membership:, **options)
    end

    def broadcast(action, stream, *stream_names, room:, membership:, **options)
      visible_room = room || membership&.room
      return unless Visibility.room_visible?(visible_room)

      Turbo::StreamsChannel.public_send("broadcast_#{action}_to", stream, *stream_names, **options)
    end
    private_class_method :broadcast
  end

  included do
    helper_method :for_each_sidebar_section, :sidebar_room_visible?
  end

  def set_sidebar_memberships
    memberships = Current.user.memberships.visible.without_thread_rooms.joins(:room).where(rooms: { active: true }).with_has_unread_notifications.includes(:room).with_room_by_last_active_newest_first

    # Get all direct memberships and filter them
    all_direct_memberships = memberships.select { |m| m.room.direct? }
    @direct_memberships   = filter_direct_memberships(all_direct_memberships)

    # Get other memberships using the without_direct_rooms scope
    other_memberships     = Current.user.memberships.visible.without_thread_rooms.without_direct_rooms.without_conversation_rooms
                                 .joins(:room)
                                 .where(rooms: { active: true })
                                 .with_has_unread_notifications
                                 .includes(:room)
                                 .with_room_by_last_active_newest_first
    @all_memberships      = other_memberships
    @starred_memberships  = other_memberships

    @direct_memberships.select! { |m| m.room.messages_count > 0 }
  end

  def for_each_sidebar_section
    [ :starred_rooms, :shared_rooms ].each do |name|
      yield name
    end
  end

  private

  def sidebar_room_visible?(room)
    Visibility.room_visible?(room)
  end

  def broadcast_sidebar_append_to(stream, *stream_names, **options)
    Broadcasting.append_to(stream, *stream_names, **options)
  end

  def broadcast_sidebar_replace_to(stream, *stream_names, **options)
    Broadcasting.replace_to(stream, *stream_names, **options)
  end

  def broadcast_sidebar_prepend_to(stream, *stream_names, **options)
    Broadcasting.prepend_to(stream, *stream_names, **options)
  end

  def filter_direct_memberships(direct_memberships)
    # Filter direct memberships to only include:
    # 1. Memberships with unread messages
    # 2. Memberships updated in the last 7 days
    direct_memberships.select do |membership|
      membership.unread? ||
        membership.has_unread_notifications? ||
        (membership.room.updated_at.present? && membership.room.updated_at >= 7.days.ago)
    end.sort_by { |m| m.room.updated_at || Time.at(0) }.reverse
  end
end
