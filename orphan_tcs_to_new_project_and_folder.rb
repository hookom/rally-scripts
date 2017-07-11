require 'rally_api'
require 'pp'

$my_base_url       = "https://rally1.rallydev.com/slm"
$my_username       = "<your username>"
$my_password       = "<your password>"
$my_workspace      = "<your Rally workspace>"
$my_project        = "<your Rally project>"
$wsapi_version     = "v2.0"

#==================== Make a connection to Rally ====================
config                  = {:base_url => $my_base_url}
config[:username]       = $my_username
config[:password]       = $my_password
config[:workspace]      = $my_workspace
config[:project]        = $my_project
config[:version]        = $wsapi_version

@rally = RallyAPI::RallyRestJson.new(config)

begin

  target_test_folder_formatted_id = "<target TestCase Folder ID ex: TF444>"

  # Lookup Target Test Folder
  target_test_folder_query = RallyAPI::RallyQuery.new()
  target_test_folder_query.type = :testfolder
  target_test_folder_query.fetch = true
  target_test_folder_query.query_string = "(FormattedID = \"" + target_test_folder_formatted_id + "\")"

  target_test_folder_result = @rally.find(target_test_folder_query)

  if target_test_folder_result.total_result_count == 0
    puts "Target Test Folder: " + target_test_folder_formatted_id + "not found. Target must exist before moving."
    exit
  end

  target_test_folder = target_test_folder_result.first()
  target_test_folder_full_object = target_test_folder.read

  target_project = target_test_folder_full_object["Project"]
  target_project_full_object = target_project.read

  #Setup the Test Case query
  source_tests = RallyAPI::RallyQuery.new()
  source_tests.type = :testcase
  source_tests.fetch = true
  source_tests_result = @rally.find(source_tests)

  source_tests_result.each do |test|
    if test.Project.to_s != $my_project
      puts "Test was not in the #{$my_project} project. Was in #{test.Project}"
      next
    end

    #Read full Test Case object
    test_case_to_update = test.read

    #Assign Test Case to target Project and Test Folder
    fields = {}

    fields["Project"] = target_project_full_object

    puts "Moving #{test_case_to_update.FormattedID} to target folder"
    @rally.update(:testcase, test_case_to_update.ObjectID, fields)

    puts "Moved #{test.FormattedID} to target folder"

    fields = {}

    fields["TestFolder"] = target_test_folder

    puts "Moving #{test_case_to_update.FormattedID} to #{target_test_folder_formatted_id}"
    @rally.update(:testcase, test_case_to_update.ObjectID, fields)

    puts "Moved #{test.FormattedID} to #{target_test_folder_formatted_id}"
  end

end
