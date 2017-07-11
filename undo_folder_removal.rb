require 'rally_api'
require 'pp'

$my_base_url       = "https://rally1.rallydev.com/slm"
$my_username       = "<your username>"
$my_password       = "<your password>"
$my_workspace      = "<your Rally workspace>"
$my_project        = "<your Rally project>"
$wsapi_version     = "v2.0"

$dump_folder = "<TestCase Folder ID ex: TF123>"

#==================== Make a connection to Rally ====================
config                  = {:base_url => $my_base_url}
config[:username]       = $my_username
config[:password]       = $my_password
config[:workspace]      = $my_workspace
config[:project]        = $my_project
config[:version]        = $wsapi_version

@rally = RallyAPI::RallyRestJson.new(config)

begin

  #Setup the Test Case query
  source_tests = RallyAPI::RallyQuery.new()
  source_tests.type = :testcase
  source_tests.fetch = true
  source_tests_result = @rally.find(source_tests)

  #Iterate over the tests, pulling their previous folder from the revision history, and reassigning to that project/folder
  source_tests_result.each do |test|
    if test.FormattedID =~ /TC(.*)/ && $1.to_i <= 369
      puts "Test already moved. Skipping."  
      next
    end

    #Save the revision history's ObjectID
    revision_history_url = test.RevisionHistory.ref

    if revision_history_url =~ /revisionhistory\/(\d*)/
      rev_hist_id = $1
    else
      puts "Did not find the RevisionHistoryID in the URL"
      exit
    end

    #Query for the Revision History object (it's not a sub-table of the Test Case object)
    revisions_result = @rally.read("revisionhistory", rev_hist_id)

    #Deal with various cases of the last revision on each test being different
    if revisions_result.Revisions[0].Description =~ /removed \[(TF.*):/
      folder_id = $1
    elsif revisions_result.Revisions[0].Description =~ /added/
      puts "Test Folder added in last revision. Skipping this test."
      next
    else
      puts "Test had no folder initially. Moving to Retired."
      folder_id = $dump_folder
    end

    #Query for target Test Folder
    target_test_folder_query = RallyAPI::RallyQuery.new()
    target_test_folder_query.type = :testfolder
    target_test_folder_query.fetch = true
    target_test_folder_query.query_string = "(FormattedID = \"" + folder_id + "\")"

    target_test_folder_result = @rally.find(target_test_folder_query)

    if target_test_folder_result.total_result_count == 0
      puts "Target Test Folder: " + $target_test_folder_formatted_id + "not found. Target must exist before moving."
      exit
    end

    target_test_folder = target_test_folder_result.first

    #Read full object for target Test Folders
    full_target_test_folder = target_test_folder.read

    #Read full Test Case object
    test_case_to_update = test.read
    source_test_case_formatted_id = test_case_to_update["FormattedID"]

    #Read full target Project object
    target_project = full_target_test_folder["Project"]
    target_project_full_object = target_project.read
    target_project_name = target_project_full_object["Name"]

    #Assign Test Case to target Project and Test Folder
    fields = {}
    fields["Project"] = target_project_full_object
    fields["TestFolder"] = target_test_folder 
    test_case_updated = @rally.update(:testcase, test_case_to_update.ObjectID, fields) #by ObjectID

    puts "Moved #{test.FormattedID} to #{folder_id}"
  end

end
