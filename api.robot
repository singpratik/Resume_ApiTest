*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    OperatingSystem
Library    String
Library    DateTime
Library    BuiltIn
Library    json
Library    Process

*** Variables ***
${BASE_URL}            https://api-uat-us-candidate.vmock.dev
${EMAIL}               epitch-epitch_dev50844@vmock.com	
${PASSWORD}            57t3B^zDvI
${LOGIN_ENDPOINT}      /dashboard-api-accounts/api/v1/login/common
${USER_INFO_ENDPOINT}  /dashboard-api-accounts/api/v1/user/info
${UPLOAD_LIMIT_ENDPOINT}    /dashboard-api-resume-parser/v1/ep-script/upload-count
${PDF_DIRECTORY}       /Users/pratiksingh/Desktop/No-code-automation-demo-main/TopcoderAutomationDemo/Resources/pdf
${UPLOAD_RESUME_ENDPOINT}    /dashboard-api-resume-parser/v1/resume/upload
${TRACK_STATUS_ENDPOINT}    /dashboard-api-resume-parser/v1/resume/status
${UPLOAD_RESUME_BUILDER_API}    /dashboard-api-resume-builder/v1/builder/upload-resume
${MAX_RETRIES}         3
${RETRY_INTERVAL}      1s
${MAX_UPLOAD_LIMIT}    10
${UPLOAD_WAIT_TIME}    5s
# &{HEADERS}    Authorization=Bearer ${ACCESS_TOKEN}    Content-Type=multipart/form-data

*** Test Cases ***
Login API Test
    [Documentation]    Test the login API functionality
    [Tags]    login    api
    ${response}=    POST Login Request    ${EMAIL}    ${PASSWORD}
    Status Should Be    200    ${response}
    
    ${json_data}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json_data}    access_token
    
    ${access_token}=    Get From Dictionary    ${json_data}    access_token
    Should Not Be Empty    ${access_token}
    Set Suite Variable    ${ACCESS_TOKEN}    ${access_token}
    
    Log    Login successful with access token: ${access_token}

Get User ID Test
    [Documentation]    Fetch user_id from the /user/info API
    [Tags]    user_info    api
    ${user_id}=    Get User ID    ${ACCESS_TOKEN}
    Should Not Be Empty    ${user_id}    msg=User ID should not be empty
    Set Suite Variable    ${USER_ID}    ${user_id}
    Log    Retrieved User ID: ${user_id}

Get Upload Count Test
    [Documentation]    Get the upload count for the user
    [Tags]    upload_count    api
    Verify Access Token Exists
    ${timestamp}=    Generate Dynamic Timestamp
    ${response}=    Get Upload Count And Response    ${ACCESS_TOKEN}    ${timestamp}
    Log    Upload Count Response: ${response}

Upload PDF Files From Directory Test
    [Documentation]    Test the Upload PDF Files From Directory functionality
    [Tags]    upload
    
    # Ensure login and get access token first
    ${response}=    POST Login Request    ${EMAIL}    ${PASSWORD}
    Status Should Be    200    ${response}
    
    ${json_data}=    Set Variable    ${response.json()}
    ${access_token}=    Get From Dictionary    ${json_data}    access_token
    
    # Upload PDF files with the obtained access token
    ${upload_limit}=    Convert To Integer    ${MAX_UPLOAD_LIMIT}
    ${success_count}    ${uploaded_files}=    Upload PDF Files    ${access_token}    ${upload_limit}
    
    # Logging and assertions
    Log    Successfully uploaded ${success_count} files    level=INFO
    Log    Uploaded Files: ${uploaded_files}    level=INFO
    Should Be True    ${success_count} > 0    msg=No PDF files were uploaded successfully
    
*** Keywords ***
POST Login Request
    [Documentation]    Sends a POST request to the login endpoint
    [Arguments]    ${email}    ${password}
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    User-Agent=LocustTest/1.0
    
    ${payload}=    Create Dictionary
    ...    email=${email}
    ...    password=${password}
    ...    provider=email
    
    ${response}=    POST    ${BASE_URL}${LOGIN_ENDPOINT}    
    ...    json=${payload}    
    ...    headers=${headers}    
    ...    expected_status=any
    
    [Return]    ${response}

Get User ID
    [Documentation]    Fetches the user ID from the user info endpoint
    [Arguments]    ${access_token}
    
    ${headers}=    Create Dictionary
    ...    Authorization=Bearer ${access_token}
    ...    Content-Type=application/json
    ...    User-Agent=LocustTest/1.0
    
    ${response}=    POST    ${BASE_URL}${USER_INFO_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=any
    
    Status Should Be    200    ${response}
    ${json_data}=    Set Variable    ${response.json()}
    ${user_id}=    Convert To String    ${json_data}
    Should Not Be Empty    ${user_id}    msg=User ID should not be empty
    
    [Return]    ${user_id}

Verify Access Token Exists
    [Documentation]    Ensures the access token exists and is valid before proceeding
    Variable Should Exist    ${ACCESS_TOKEN}    msg=Access token is not set. Please run the login test first.
    Should Not Be Empty    ${ACCESS_TOKEN}    msg=Access token is empty


Get Upload Count And Response
    [Documentation]    Get the upload count response with dynamic timestamp
    [Arguments]    ${access_token}    ${timestamp}
    ${headers}=    Create Dictionary    
    ...    Authorization=Bearer ${access_token}    
    ...    Content-Type=application/json    
    ...    User-Agent=LocustTest/1.0    
    ...    Accept=application/pdf
    
    ${url}=    Set Variable    ${BASE_URL}${UPLOAD_LIMIT_ENDPOINT}?_=${timestamp}
    ${response}=    GET    ${url}    
    ...    headers=${headers}
    ...    expected_status=any
    
    [Return]    ${response}

Generate Dynamic Timestamp
    [Documentation]    Generate a dynamic 13-digit timestamp
    ${current_time}=    Get Current Date    result_format=epoch    exclude_millis=False
    ${timestamp}=    Evaluate    int(float(${current_time}) * 1000)
    [Return]    ${timestamp}

Is PDF File
    [Arguments]    ${file_path}
    [Documentation]    Comprehensive PDF file validation
    
    # Basic checks
    ${file_exists}=    Run Keyword And Return Status    File Should Exist    ${file_path}
    Run Keyword If    not ${file_exists}    Fail    File does not exist: ${file_path}
    
    # Extension and path validation
    ${normalized_path}=    Normalize Path    ${file_path}
    ${is_pdf_extension}=    Set Variable    ${normalized_path.lower().endswith('.pdf')}
    Run Keyword If    not ${is_pdf_extension}    Fail    Not a PDF file: ${normalized_path}
     
    # File size check
    ${file_size}=    Get File Size    ${file_path}
    ${size_valid}=    Evaluate    0 < ${file_size} < 20000000  # Between 1 byte and 20MB
    Run Keyword If    not ${size_valid}    Fail    Invalid file size: ${file_size} bytes
    
    # Attempt to detect PDF magic number
    ${magic_check}=    Run Keyword And Return Status    
    ...    Run Process    file -b --mime-type    ${file_path}    
    ...    shell=True    stdout=${TEMPDIR}/mime.txt
    
    ${mime_type}=    Get File    ${TEMPDIR}/mime.txt
    ${is_pdf_mime}=    Evaluate    'pdf' in '''${mime_type}'''.lower()
    
    Log Many    
    ...    File Path: ${file_path}
    ...    File Size: ${file_size}
    ...    PDF Extension: ${is_pdf_extension}
    ...    MIME Type Check: ${mime_type}
    ...    MIME PDF Detected: ${is_pdf_mime}
    
    [Return]    ${is_pdf_extension}




Get PDF Page Count
    [Documentation]    Get the number of pages in a PDF file
    [Arguments]    ${pdf_file_path}
    
    # Simple page count using file size as a rough estimate
    ${file_size}=    Get File Size    ${pdf_file_path}
    ${estimated_pages}=    Evaluate    max(1, ${file_size} // 4096)
    
    [Return]    ${estimated_pages}



Upload PDF Files
    [Arguments]    ${access_token}    ${upload_limit}=10
    [Documentation]    Upload PDF files from a directory with comprehensive tracking
    
    # Validate directory
    Run Keyword If    not os.path.exists('${PDF_DIRECTORY}')    
    ...    Fail    PDF Directory does not exist: ${PDF_DIRECTORY}
    
    # Get PDF files
    ${files}=    List Files In Directory    ${PDF_DIRECTORY}    *.pdf
    
    # Ensure files exist
    ${file_count}=    Get Length    ${files}
    Run Keyword If    ${file_count} == 0    
    ...    Fail    No PDF files found in directory: ${PDF_DIRECTORY}
    
    Log    Total PDF files found: ${file_count}    level=INFO
    
    # Initialize counters and lists
    ${upload_count}=    Set Variable    0
    @{failed_uploads}=    Create List
    @{successful_uploads}=    Create List

    # File upload loop
    FOR    ${file}    IN    @{files}
        # Check upload limit
        Exit For Loop If    ${upload_count} >= ${upload_limit}
        
        # Construct FULL file path
        ${file_path}=    Set Variable    ${PDF_DIRECTORY}/${file}
        Log    Processing file: ${file_path}    level=INFO
        
        # Attempt upload
        ${upload_status}    ${uploaded_filename}=    Upload Single PDF    ${access_token}    ${file_path}
        
        # Process upload result
        Run Keyword If    ${upload_status}
        ...    Run Keywords
        ...    Append To List    ${successful_uploads}    ${uploaded_filename}
        ...    AND    Evaluate    ${upload_count} + 1
        ...    ELSE    Append To List    ${failed_uploads}    ${file}
        
        # Controlled wait between uploads
        Sleep    ${UPLOAD_WAIT_TIME}
    END

    # Logging and reporting
    Log    Total Files: ${file_count}    level=INFO
    Log    Successful Uploads: ${successful_uploads}    level=INFO
    Log    Failed Uploads: ${failed_uploads}    level=WARN
    
    # Calculate upload count
    ${upload_count}=    Get Length    ${successful_uploads}
    Log    Upload Summary: Successfully uploaded ${upload_count} files    level=INFO

    [Return]    ${upload_count}    ${successful_uploads}



Upload Single PDF
    [Arguments]    ${access_token}    ${pdf_file_path}
    [Documentation]    Upload a single PDF file to the specified endpoint with original filename

    # Extensive file validation
    Run Keyword If    not os.path.exists('${pdf_file_path}')    
    ...    Fail    File does not exist: ${pdf_file_path}

    # Ensure file is not empty (size > 0)
    ${file_size}=    Get File Size    ${pdf_file_path}
    Run Keyword If    ${file_size} == 0    
    ...    Fail    PDF file is empty: ${pdf_file_path}

    # Advanced PDF validation
    ${is_valid_pdf}=    Is PDF File    ${pdf_file_path}
    Run Keyword If    not ${is_valid_pdf}    
    ...    Fail    Invalid PDF file: ${pdf_file_path}

    # Prepare headers for the file upload
    ${headers}=    Create Dictionary    
    ...    Authorization=Bearer ${access_token}
    ...    Accept=application/json

    # Filename handling - use the original filename
    ${filename}=    Evaluate    os.path.basename('${pdf_file_path}')

    # Prepare file for upload
    ${file}=    Get Binary File    ${pdf_file_path}

    # Create multipart form data with original filename
    ${files}=    Create Dictionary    
    ...    resume=${file}

    # Form data
    ${form_data}=    Create Dictionary    
    ...    product_name=resume
    ...    parse_resume=true

    # Verbose logging
    Log    Attempting to upload file: ${filename}    level=INFO

    # Perform upload with retry mechanism
    ${max_retries}=    Set Variable    3
    ${is_success}=    Set Variable    ${FALSE}
    
    FOR    ${retry_count}    IN RANGE    ${max_retries}
        ${response}=    POST
        ...    ${BASE_URL}${UPLOAD_RESUME_ENDPOINT}
        ...    files=${files}
        ...    data=${form_data}
        ...    headers=${headers}
        ...    expected_status=any

        # Log response details
        Log    Upload Attempt ${retry_count + 1}: Response Status ${response.status_code}    level=INFO
        Log    Response Content: ${response.text}    level=DEBUG

        # Determine upload success
        ${is_success}=    Evaluate    200 <= ${response.status_code} < 300
        
        Exit For Loop If    ${is_success}
        
        # Wait between retries
        Sleep    2s
    END

    # Detailed error logging if upload fails
    Run Keyword If    not ${is_success}    
    ...    Log    Failed to upload ${filename} after ${max_retries} attempts    level=ERROR

    [Return]    ${is_success}    ${filename}