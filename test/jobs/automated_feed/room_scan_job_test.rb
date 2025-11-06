require "test_helper"

module AutomatedDigest
  class RoomScanJobTest < ActiveSupport::TestCase
    setup do
      AutomatedDigest.config.enable_automated_scans = true
      @room = rooms(:pets)
    end

    teardown do
      AutomatedDigest.config.enable_automated_scans = true
    end

    test "perform returns early when scans disabled" do
      AutomatedDigest.config.enable_automated_scans = false

      AutomatedDigest::Scanner.expects(:scan).never
      AutomatedDigest::ActivityTracker.expects(:mark_scanned).never

      AutomatedDigest::RoomScanJob.new.perform(@room.id)
    end

    test "perform resets tracker when room missing" do
      missing_id = -1

      AutomatedDigest::ActivityTracker.expects(:reset).with(missing_id)

      AutomatedDigest::RoomScanJob.new.perform(missing_id)
    end

    test "perform scans room and marks tracker" do
      conversation = {
        message_ids: [1, 2],
        title: "Test",
        summary: "Test summary",
        participants: [],
        topic_tags: [],
        key_insight: "Key",
        preview_message_id: 1
      }

      AutomatedDigest::Scanner.expects(:scan).with(room: @room).returns([conversation])

      runner = mock("scan_runner")
      AutomatedDigest::ScanRunner.expects(:new)
                                  .with(conversations: [conversation], source: "room", room: @room)
                                  .returns(runner)
      runner.expects(:run)

      AutomatedDigest::ActivityTracker.expects(:mark_scanned).with(@room.id)

      AutomatedDigest::RoomScanJob.new.perform(@room.id, trigger_status: :message_threshold)
    end

    test "perform resets tracker and re-raises errors" do
      AutomatedDigest::Scanner.stubs(:scan).returns([{ message_ids: [1], title: "T", summary: "S", participants: [], topic_tags: [], key_insight: "K", preview_message_id: 1 }])

      runner = mock("scan_runner")
      AutomatedDigest::ScanRunner.stubs(:new).returns(runner)
      runner.stubs(:run).raises(StandardError.new("boom"))

      AutomatedDigest::ActivityTracker.expects(:reset).with(@room.id)
      AutomatedDigest::ActivityTracker.expects(:mark_scanned).never

      assert_raises(StandardError) do
        AutomatedDigest::RoomScanJob.new.perform(@room.id)
      end
    end
  end
end
