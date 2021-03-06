namespace :toggl do

  desc 'Sync user time entries'
  task :sync_time_entries, [:start_date, :end_date] => :environment do |t, args|
    sync_args = {}
    sync_args[:start_date] = args[:start_date] if args[:start_date].present?
    sync_args[:end_date] = args[:end_date] if args[:end_date].present?

    TogglService.sync_toggl_time_entries(sync_args)
  end

  desc 'Sync user time entries and remove entries still in Redmine but deleted from Toggl'
  task :sync_time_entries_remove_missing, [:start_date, :end_date] => :environment do |t, args|
    sync_args = {}
    sync_args[:start_date] = args[:start_date] if args[:start_date].present?
    sync_args[:end_date] = args[:end_date] if args[:end_date].present?

    TogglService.sync_toggl_time_entries(sync_args, true)
  end

  desc 'Sync workspace, project and task base data, delete workspaces without users'
  task :sync_base_data, [:user] => :environment do |t, args|
    user_login = args[:user]

    if user_login.blank?
      puts 'Please provide a user. User Toggl API key will be used to sync base data. Sample command for user with login "bob"'
      puts '  RAILS_ENV=production bundle exec rake toggl:sync_base_data[bob]'
      exit
    end

    user = User.find_by_login(user_login)

    unless user
      puts "User #{user_login} not found"
      exit
    end

    apikey = user.cf_toggl_api_key

    if apikey.blank?
      puts "Toggl API Key for user #{user_login} is not setup. Please set it up in users settings."
      exit
    end

    puts "Before sync Workspace: #{TogglWorkspace.count} Project: #{TogglProject.count} Task: #{TogglTask.count}"
    TogglService.sync_base_data(apikey)
    puts "After sync  Workspace: #{TogglWorkspace.count} Project: #{TogglProject.count} Task: #{TogglTask.count}"
  end

  desc 'Sync workspace for a specific user and keep workspaces already saved'
  task :sync_base_data_for_user, [:user, :workspace] => :environment do |t, args|
    user_login = args[:user]
    workspace_name = args[:workspace]

    if user_login.blank? || workspace_name.blank?
      puts 'Please provide a user and workspace name. User Toggl API key will be used to sync base data. Sample command for user with login "bob" and workspace "My Workspace"'
      puts '  RAILS_ENV=production bundle exec rake toggl:sync_base_data_for_user[bob,"My Workspace"]'
      exit
    end

    user = User.find_by_login(user_login)

    unless user
      puts "User #{user_login} not found"
      exit
    end

    apikey = user.cf_toggl_api_key

    if apikey.blank?
      puts "Toggl API Key for user #{user_login} is not setup. Please set it up in users settings."
      exit
    end

    puts "Before sync Workspace: #{TogglWorkspace.count} Project: #{TogglProject.count} Task: #{TogglTask.count}"
    TogglService.sync_base_data(apikey, workspace_name, user)
    puts "After sync  Workspace: #{TogglWorkspace.count} Project: #{TogglProject.count} Task: #{TogglTask.count}"
  end

  desc 'Sends email with a list of Toggl entries that are not assigned to an issue'
  task :report_without_issue, [:hours_ago, :recipients, :language] => :environment do |t, args|
    hours_ago = args[:hours_ago].to_i > 0 ? args[:hours_ago].to_i.hours.ago : nil
    recipients = args[:recipients].to_s.split('|')
    language = args[:language]

    if recipients.blank?
      puts 'Please provide recipient email address, you can provide multiple address pipe "|" separated'
      exit
    else
      recipients.each do |recipient|
        next unless recipient.match(TogglEntry::EMAIL_VALIDATOR).nil?

        puts "Invalid email address #{recipient.inspect}"
        exit
      end
    end

    results = TogglEntry.report_without_issue(hours_ago)
    Mailer.toggl_report_without_issue(recipients, results, language).deliver
  end

  desc 'Sends email with a list of Toggl entries that are not assigned to a Toggl Project'
  task :report_without_project, [:hours_ago, :recipients, :language] => :environment do |t, args|
    hours_ago = args[:hours_ago].to_i > 0 ? args[:hours_ago].to_i.hours.ago : nil
    recipients = args[:recipients].to_s.split('|')
    language = args[:language]

    if recipients.blank?
      puts 'Please provide recipient email address, you can provide multiple address pipe "|" separated'
      exit
    else
      recipients.each do |recipient|
        next unless recipient.match(TogglEntry::EMAIL_VALIDATOR).nil?

        puts "Invalid email address #{recipient.inspect}"
        exit
      end
    end

    results = TogglEntry.report_without_project(hours_ago)
    Mailer.toggl_report_without_project(recipients, results, language).deliver
  end

  desc 'Sends email to all active Toggl users with a list of Toggl entries that are not assigned to an issue'
  task :report_without_issue_to_users, [:hours_ago] => :environment do |t, args|
    hours_ago = args[:hours_ago].to_i > 0 ? args[:hours_ago].to_i.hours.ago : nil

    User.active.with_toggl_api_key.each do |user|
      recipients = user.mail
      language = user.language

      results = TogglEntry.report_without_issue_for_user(user, hours_ago)
      next if results.blank?
      Mailer.toggl_report_without_issue(recipients, results, language).deliver
    end
  end

  desc 'Sends email to all active Toggl users with a list of Toggl entries that are not assigned to a Toggl Project'
  task :report_without_project_to_users, [:hours_ago] => :environment do |t, args|
    hours_ago = args[:hours_ago].to_i > 0 ? args[:hours_ago].to_i.hours.ago : nil

    User.active.with_toggl_api_key.each do |user|
      next if user.toggl_workspace

      recipients = user.mail
      language = user.language

      results = TogglEntry.report_without_project_for_user(user, hours_ago)
      next if results.blank?
      Mailer.toggl_report_without_project(recipients, results, language).deliver
    end
  end
end

