namespace :conversation_rooms do
  desc "Deduplicate copied conversation room messages (use DRY_RUN=true to preview)"
  task dedupe_copies: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    ConversationRooms::CopyDeduper.new.call(dry_run: dry_run)
  end
end

module ConversationRooms
  class CopyDeduper
    BATCH_SIZE = 100

    def call(dry_run: false)
      scope = Message.where.not(original_message_id: nil)
      total = scope.count
      puts "Processing #{total} copied messages#{' (DRY RUN - no changes will be made)' if dry_run}"

      if total == 0
        puts "Nothing to process"
        return
      end

      stats = { boosts_transferred: 0, boosts_deleted: 0, rich_texts_purged: 0, attachments_purged: 0, skipped: 0 }
      processed = 0

      scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        Message.transaction do
          batch.each { |copy| dedupe_copy(copy, dry_run: dry_run, stats: stats) }
        end
        processed += batch.size
        puts "Progress: #{processed}/#{total} (#{(processed * 100.0 / total).round(1)}%)"
      end

      puts "\n#{'[DRY RUN] ' if dry_run}Summary:"
      puts "  Boosts transferred: #{stats[:boosts_transferred]}"
      puts "  Duplicate boosts deleted: #{stats[:boosts_deleted]}"
      puts "  Rich texts purged: #{stats[:rich_texts_purged]}"
      puts "  Attachments purged: #{stats[:attachments_purged]}"
      puts "  Copies skipped (missing original): #{stats[:skipped]}"
      puts "\nConversation room dedupe finished"
    end

    private

    def dedupe_copy(copy, dry_run:, stats:)
      canonical = copy.original_message
      unless canonical
        stats[:skipped] += 1
        return
      end

      transfer_boosts(copy, canonical, dry_run: dry_run, stats: stats)
      purge_copy_rich_text(copy, dry_run: dry_run, stats: stats)
      purge_copy_attachment(copy, dry_run: dry_run, stats: stats)
    end

    def transfer_boosts(copy, canonical, dry_run:, stats:)
      Boost.unscoped.where(message_id: copy.id).find_each do |boost|
        existing = Boost.unscoped.exists?(
          message_id: canonical.id,
          booster_id: boost.booster_id,
          content: boost.content
        )

        if existing
          stats[:boosts_deleted] += 1
          boost.delete unless dry_run
        else
          stats[:boosts_transferred] += 1
          boost.update_columns(message_id: canonical.id) unless dry_run
        end
      end
    end

    def purge_copy_rich_text(copy, dry_run:, stats:)
      record = copy.local_rich_text_body_record
      return unless record

      stats[:rich_texts_purged] += 1
      record.destroy unless dry_run
    end

    def purge_copy_attachment(copy, dry_run:, stats:)
      return unless copy.local_attachment?

      stats[:attachments_purged] += 1
      copy.local_attachment_record.purge_later unless dry_run
    end
  end
end
