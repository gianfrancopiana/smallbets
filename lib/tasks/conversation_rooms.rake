namespace :conversation_rooms do
  desc "Deduplicate copied conversation room messages to use canonical content"
  task dedupe_copies: :environment do
    ConversationRooms::CopyDeduper.new.call
  end
end

module ConversationRooms
  class CopyDeduper
    BATCH_SIZE = 100

    def call
      scope = Message.where.not(original_message_id: nil)
      puts "Processing #{scope.count} copied messages"

      scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        Message.transaction do
          batch.each { |copy| dedupe_copy(copy) }
        end
      end

      puts "Conversation room dedupe finished"
    end

    private

    def dedupe_copy(copy)
      canonical = copy.original_message
      return unless canonical

      transfer_boosts(copy, canonical)
      purge_copy_rich_text(copy)
      purge_copy_attachment(copy)
    end

    def transfer_boosts(copy, canonical)
      Boost.unscoped.where(message_id: copy.id).find_each do |boost|
        # Check if this boost already exists on the canonical message
        existing = Boost.unscoped.exists?(
          message_id: canonical.id,
          booster_id: boost.booster_id,
          content: boost.content
        )

        if existing
          # Delete the duplicate boost from the copy
          boost.destroy
        else
          # Transfer the boost to the canonical message
          boost.update_columns(message_id: canonical.id)
        end
      end
    end

    # Use local_ methods to avoid delegating to original_message
    def purge_copy_rich_text(copy)
      copy.local_rich_text_body_record&.destroy
    end

    # Use local_ methods to avoid delegating to original_message
    def purge_copy_attachment(copy)
      copy.local_attachment_record.purge if copy.local_attachment?
    end
  end
end
