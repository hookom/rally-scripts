require 'rally_api'

$my_base_url       = "https://rally1.rallydev.com/slm"
$my_username       = "<your username>"
$my_password       = "<your password>"
$my_workspace      = "<your Rally workspace>"
$my_project        = "<your Rally project>"
$wsapi_version     = "1.40"

# Test Folders
$source_test_folder_formatted_id = nil 
$target_test_folder_formatted_id = nil
$source_folders = Array["<source TestCase Folder ID ex: TF234>"]
$target_folders = Array["<target folder ID>"]

#==================== Make a connection to Rally ====================
config                  = {:base_url => $my_base_url}
config[:username]       = $my_username
config[:password]       = $my_password
config[:workspace]      = $my_workspace
config[:project]        = $my_project
config[:version]        = $wsapi_version

@rally = RallyAPI::RallyRestJson.new(config)

begin

$i = 0
while $i < $source_folders.count do

$source_test_folder_formatted_id = $source_folders[$i]
$target_test_folder_formatted_id = $target_folders[$i]
$i += 1

puts $source_test_folder_formatted_id

  # Lookup source Test Folder
  source_test_folder_query = RallyAPI::RallyQuery.new()
  source_test_folder_query.type = :testfolder
  source_test_folder_query.fetch = true
  source_test_folder_query.query_string = "(FormattedID = \"" + $source_test_folder_formatted_id + "\")"

  source_test_folder_result = @rally.find(source_test_folder_query)

  # Lookup Target Test Folder
  target_test_folder_query = RallyAPI::RallyQuery.new()
  target_test_folder_query.type = :testfolder
  target_test_folder_query.fetch = true
  target_test_folder_query.query_string = "(FormattedID = \"" + $target_test_folder_formatted_id + "\")"

  target_test_folder_result = @rally.find(target_test_folder_query)

  if source_test_folder_result.total_result_count == 0
    puts "Source Test Folder: " + $source_test_folder_formatted_id + "not found. Exiting."
    exit
  end

  if target_test_folder_result.total_result_count == 0
    puts "Target Test Folder: " + $target_test_folder_formatted_id + "not found. Target must exist before moving."
    exit
  end

  source_test_folder = source_test_folder_result.first()
  target_test_folder = target_test_folder_result.first()

  # Populate full object for both Source and Target Test Folders
  full_source_test_folder = source_test_folder.read
  full_target_test_folder = target_test_folder.read

  # Grab collection of Source Test Cases
  source_test_cases = source_test_folder["TestCases"]

  # Loop through Source Test Cases and Move to Target
  source_test_cases.each do |source_test_case|
    begin

      test_case_to_update = source_test_case.read
      source_test_case_formatted_id = test_case_to_update["FormattedID"]

      target_project = full_target_test_folder["Project"]
      target_project_full_object = target_project.read
      target_project_name = target_project_full_object["Name"]

      source_project = full_source_test_folder["Project"]
      source_project_full_object = source_project.read
      source_project_name = source_project_full_object["Name"]

      puts "Source Project Name: #{source_project_name}"
      puts "Target Project Name: #{target_project_name}"

      # Test if the source project and target project are the same
      source_target_proj_match = source_project_name.eql?(target_project_name)

      # If the target Test Folder is in a different Project, we have to do some homework first:
      # "un-Test Folder" the project
      # Assign the Test Case to the Target Project
      # Assign the Test Case to the Target Test Folder
      if !source_target_proj_match then
        fields = {}
        fields["TestFolder"] = ""
        test_case_updated = @rally.update(:testcase, test_case_to_update.ObjectID, fields) #by ObjectID
        puts "Test Case #{source_test_case_formatted_id} successfully dissociated from: #{$source_test_folder_formatted_id}"

        # Get full object on Target Project and assign Test Case to Target Project
        fields = {}
        fields["Project"] = target_project_full_object
        test_case_updated = @rally.update(:testcase, test_case_to_update.ObjectID, fields) #by ObjectID
        puts "Test Case #{source_test_case_formatted_id} successfully assigned to Project: #{target_project_name}"
      end

      # Change the Test Folder attribute on the Test Case
      fields = {}
      fields["TestFolder"] = target_test_folder
      test_case_updated = @rally.update(:testcase, test_case_to_update.ObjectID, fields) #by ObjectID
      puts "Test Case #{source_test_case_formatted_id} successfully moved to #{$target_test_folder_formatted_id}"
    rescue => ex
      puts "Test Case #{source_test_case_formatted_id} not updated due to error"
      puts ex
    end
  end

end
end
