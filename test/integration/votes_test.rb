require "rubygems"
require "test/unit"
require "watir-webdriver"
require 'test_helper'

class VoteThroughBrowsers < ActionController::IntegrationTest
  def setup
    @max_browsers = 2
    @max_votes = 7
    @db_config = YAML::load(File.read(Rails.root.join("config","database.yml")))
    @neighborhood_ids = [1,2]
    #@neighborhood_ids = [1,2,3,4,5,6,7,8,9,10]
    if !!(RbConfig::CONFIG['host_os'] =~ /mingw|mswin32|cygwin/)
      @browser_types = [:firefox,:chrome,:ie]
    elsif true
      @browser_types = [:chrome]
    else
      @browser_types = [:firefox,:chrome]
    end

    @browsers = []
    @max_browsers.times do
      @browsers << Watir::Browser.new(@browser_types[rand(@browser_types.length)])
    end
    @votes = []
    @user_browser_votes = Hash.new
    @browsers.each do |browser|
      @user_browser_votes[browser] = []
    end

    @database_csv_filenames = []
    @test_csv_filenames = []

    FileUtils.rm_rf File.join(Rails.root.join("test","results"))
    Dir.mkdir(File.join(Rails.root.join("test","results")))

    setup_votes
  end

  def teardown
    @browsers.each do |browser|
      browser.close
    end
  end

  test "vote_through_firefox_and_chrome" do
    @votes.each do |vote|
      browser = @browsers[rand(@browsers.length)]
      neighborhood_id = @neighborhood_ids[rand(@neighborhood_ids.length)]
      browser.goto "http://localhost:3000/votes/ballot?neighborhood_id=#{neighborhood_id}"
      setup_checkboxes(browser,vote)
      @user_browser_votes[browser] << {:neighborhood_id=>neighborhood_id, :votes=>get_user_votes(browser)}
      browser.button.click
      browser.div(:id => "success_message").wait_until_present
    end
    assert all_vote_match?(all_votes), "All individual votes matched"
    assert unique_vote_match?, "All unique votes matched"
    assert identical_csv_files?, "Database and test csv files are identical"
  end

  def get_user_votes(browser)
    construction_votes = []
    browser.elements(:class, "construction_vote_class").each do |element|
      construction_votes << element.id.split("_")[1].to_i
    end
    maintenance_votes = []
    class_elements = browser.elements(:class, "maintenance_vote_class").each do |element|
      maintenance_votes << element.id.split("_")[1].to_i
    end
    [construction_votes,maintenance_votes]
  end

  def all_votes
    all_votes = []
    @user_browser_votes.each do |browsers,vote_values|
      vote_values.each do |vote_value|
        all_votes<<vote_value[:votes]
      end
    end
  all_votes
  end

  def get_unique_votes(neighborhood_id)
    unique_votes = []
    @user_browser_votes.each do |browsers,vote_values|
      unique_votes<<vote_values.last[:votes] if vote_values.last and vote_values.last[:neighborhood_id] == neighborhood_id
    end
    unique_votes
  end

  def unique_vote_match?
    votes.each do |vote| puts vote.inspect end # DEBUG
    all_passed = true
    Vote.split_and_generate_final_votes!
    @neighborhood_ids.each do |neighborhood_id|
      puts "NEIGHBORHOOD ID #{neighborhood_id}"
      database_count = ReykjavikBudgetVoteCounting.new(Rails.root.join('test','keys','privkey.pem'))
      @database_csv_filenames << database_count.count_unique_votes(neighborhood_id)
      database_count.write_counted_unencrypted_audit_report
      #puts database_count.inspect
      test_count = ReykjavikBudgetVoteCounting.new(Rails.root.join('test','keys','privkey.pem'))
      test_count.count_all_test_votes(get_unique_votes(neighborhood_id),neighborhood_id)
      @test_csv_filenames << test_count.write_voting_results_report("test_voting_results.csv")
      #puts test_count.inspect
      puts "Test: ct: #{test_count.construction_priority_ids_count} == #{database_count.construction_priority_ids_count}"
      puts "Test: mt: #{test_count.maintenance_priority_ids_count} == #{database_count.maintenance_priority_ids_count}"

      match = (test_count.construction_priority_ids_count == database_count.construction_priority_ids_count &&
               test_count.maintenance_priority_ids_count == database_count.maintenance_priority_ids_count) ? true : false
      unless match
        puts "FAILED"
        all_passed = false
        break
      end
    end
    all_passed
  end

  def identical_csv_files?
    all_passed = true
    @neighborhood_ids.each_with_index do |neighborhood_id,index|
       match = File.open(Rails.root.join("test","results",@database_csv_filenames[index])).read.to_s == File.open(Rails.root.join("test","results",@test_csv_filenames[index])).read.to_s
       unless match
        puts "FAILED"
        all_passed = false
        break
      end
    end
    all_passed
  end

  def all_vote_match?(votes)
    votes.each do |vote| puts vote.inspect end # DEBUG
    database_count = ReykjavikBudgetVoteCounting.new(Rails.root.join('test','keys','privkey.pem'))
    database_count.count_all_votes
    puts database_count.inspect
    test_count = ReykjavikBudgetVoteCounting.new(Rails.root.join('test','keys','privkey.pem'))
    test_count.count_all_test_votes(votes)
    puts test_count.inspect
    (test_count.construction_priority_ids_count == database_count.construction_priority_ids_count &&
     test_count.maintenance_priority_ids_count == database_count.maintenance_priority_ids_count) ? true : false
  end

  def setup_votes
    @max_votes.times do
      seen = {}
      construction_votes = (1..(rand(7)+2)).map { |n|
                              x = rand(12)+1
                              while (seen[x])
                                x = rand(12)+1
                              end
                              seen[x]=x
                              x
                            }
      seen = {}
      maintenance_votes = (1..(rand(7)+2)).map { |n|
                              x = rand(12)+14
                              while (seen[x])
                                x = rand(12)+14
                              end
                              seen[x]=x
                              x
                            }

      @votes << [construction_votes,maintenance_votes]
    end
  end

  def setup_checkboxes(browser,vote_types)
    vote_types.each do |vote|
      vote.each do |checkbox_to_set|
        browser.li(:id => "option_#{checkbox_to_set}").click
      end
    end
  end
end
