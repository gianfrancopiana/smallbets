require "test_helper"

module AutomatedDigest
  class ScheduledScanJobTest < ActiveSupport::TestCase
    setup do
      AutomatedDigest.config.enable_automated_scans = true
    end

    teardown do
      AutomatedDigest.config.enable_automated_scans = true
    end

    test "perform returns early when disabled" do
      AutomatedDigest.config.enable_automated_scans = false

      AutomatedDigest::Scanner.expects(:scan).never
      AutomatedDigest::ActivityTracker.expects(:active_room_ids).never

      AutomatedDigest::ScheduledScanJob.new.perform
    end

    test "perform runs scan runner for conversations" do
      conversation = {
        message_ids: [1, 2],
        title: "Test",
        summary: "Test summary",
        participants: [],
        topic_tags: [],
        key_insight: "Key",
        preview_message_id: 1
      }

      AutomatedDigest::Scanner.stubs(:scan).returns([conversation])

      runner = mock("scan_runner")
      AutomatedDigest::ScanRunner.expects(:new)
                                  .with(conversations: [conversation], source: "scheduled")
                                  .returns(runner)
      runner.expects(:run)

      AutomatedDigest::ActivityTracker.expects(:active_room_ids).returns(["1"])
      AutomatedDigest::ActivityTracker.expects(:mark_scanned).with("1")

      AutomatedDigest::ScheduledScanJob.new.perform
    end

    test "perform resets activity tracker when no conversations" do
      AutomatedDigest::Scanner.stubs(:scan).returns([])

      AutomatedDigest::ScanRunner.expects(:new).never

      AutomatedDigest::ActivityTracker.expects(:active_room_ids).returns(["2", "3"])
      AutomatedDigest::ActivityTracker.expects(:mark_scanned).with("2")
      AutomatedDigest::ActivityTracker.expects(:mark_scanned).with("3")

      AutomatedDigest::ScheduledScanJob.new.perform
    end

    test "perform still resets tracker when scan raises" do
      AutomatedDigest::Scanner.stubs(:scan).raises(StandardError.new("boom"))

      AutomatedDigest::ActivityTracker.expects(:active_room_ids).returns(["4"])
      AutomatedDigest::ActivityTracker.expects(:mark_scanned).with("4")

      assert_raises(StandardError) do
        AutomatedDigest::ScheduledScanJob.new.perform
      end
    end
  end
end
