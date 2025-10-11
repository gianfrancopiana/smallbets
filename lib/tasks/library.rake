namespace :library do
  desc "Populate library database from config/library_videos.yml"
  task populate: :environment do
    yaml = YAML.load_file(Rails.root.join("config", "library_videos.yml"))
    sections = yaml.fetch("sections", [])

    puts "Starting to populate library database..."
    puts "Found #{sections.count} classes in config file"

    ActiveRecord::Base.transaction do
      # Clear existing data
      LibrarySession.delete_all
      LibraryClass.delete_all

      sections.each_with_index do |section, class_index|
        raw_title = section.fetch("title")
        puts "\nProcessing: #{raw_title}"

        # Extract creator and title from "Title - Creator" format
        title, creator = raw_title.split(" - ", 2).map(&:strip)

        # If no dash found, use the whole title and set creator to empty
        if creator.nil?
          creator = title
          title = raw_title
        end

        library_class = LibraryClass.create!(
          slug: section.fetch("slug"),
          title: title,
          creator: creator,
          position: class_index
        )

        videos = section.fetch("videos", [])
        puts "  - Found #{videos.count} session(s)"

        videos.each_with_index do |video, video_index|
          library_class.library_sessions.create!(
            vimeo_id: video.fetch("vimeo_id"),
            vimeo_hash: video["hash"],
            padding: video.fetch("padding", 56.25).to_f,
            quality: video["quality"].presence,
            position: video_index
          )
        end

        puts "  - Created #{library_class.library_sessions.count} session(s)"
      end
    end

    puts "\n✓ Successfully populated library database!"
    puts "Total classes: #{LibraryClass.count}"
    puts "Total sessions: #{LibrarySession.count}"
  end
end
