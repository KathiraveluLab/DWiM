function [studyList, studyMetadata] = connectToOrthanc(options)
%CONNECTTOORTHANC Connects to Orthanc and fetches study data.
%   [studyList, studyMetadata] = dwim.utils.connectToOrthanc()
%   Connects to the default Orthanc server, gets a list of all studies,
%   and fetches the metadata for the *first* study in the list.
%
%   [studyList, studyMetadata] = dwim.utils.connectToOrthanc('StudyID', 'xxxx')
%   Connects to the default Orthanc server and fetches metadata for the
%   specified StudyID.
%
%   [...] = dwim.utils.connectToOrthanc('Verbose', false)
%   Connects silently without printing status messages to the console.
%
%   [...] = dwim.utils.connectToOrthanc('BaseURL', 'http://my.server:8080', ...)
%   Specifies a custom server URL, user, and password.
%
%   Outputs:
%   studyList - Cell array of study IDs available on the server.
%   studyMetadata - Struct containing the metadata for the requested study.

%   Input Arguments:
arguments
    % FIX #1: Hard-coded values moved here.
    options.BaseURL (1,1) string = "http://localhost:8042"
    options.User (1,1) string = "orthanc"
    options.Password (1,1) string = "orthanc"
    
    % FIX #4: 'Verbose' flag added to control printing.
    options.Verbose (1,1) logical = true
    
    % FIX #5: Optional 'StudyID' parameter added.
    options.StudyID (1,1) string = ""  % If empty, fetches the first study
end

%% --- Configuration ---
orthancBaseURL = options.BaseURL;
orthancUser = options.User;
orthancPass = options.Password;

if options.Verbose
    fprintf('--- DWiM: Connecting to Orthanc ---\n');
end

% Default outputs
studyList = [];
studyMetadata = [];

%% --- Set Up Web Options ---
try
    webOpts = weboptions(...
        'Username', orthancUser, ...
        'Password', orthancPass, ...
        'MediaType', 'application/json', ...
        'Timeout', 30 ...
    );
catch ME
    % FIX #3: Restore specific error check for missing toolboxes.
    if strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
        fprintf('Error: Failed to create weboptions. Do you have the required toolboxes?\n');
        fprintf('This script requires MATLAB''s HTTP Interface.\n');
    else
         fprintf('Error: Failed to create weboptions. Reason: %s\n', ME.message);
    end
    rethrow(ME);
end

%% --- 1. Test Connection & Get Study List ---
allStudiesURL = [orthancBaseURL, '/studies'];
if options.Verbose
    fprintf('Attempting to connect to %s ...\n', orthancBaseURL);
end

try
    studyList = webread(allStudiesURL, webOpts);
    
    if isempty(studyList)
        if options.Verbose
            fprintf('Success! Connected to Orthanc, but no studies were found.\n');
        end
        return; % Stop the function
    end
    
    if options.Verbose
        fprintf('Success! Connected to Orthanc. Found %d studies.\n\n', numel(studyList));
    end

catch ME
    if options.Verbose
        fprintf('Error: Failed to connect or read from Orthanc.\n');
        if contains(ME.message, '401')
            fprintf('Reason: HTTP 401 Unauthorized. Check your username and password.\n');
        elseif contains(ME.message, 'Connection refused')
            fprintf('Reason: Connection refused. Is the Orthanc Docker container running?\n');
        else
            fprintf('Reason: %s\n', ME.message);
        end
    end
    return; % Stop the function
end

%% --- 2. Fetch Metadata for the Requested Study ---
targetStudyID = ''; % FIX #2: Initialize variable before the try block.
try
    % FIX #5: Logic to decide which study to fetch.
    if options.StudyID == ""
        % Default behavior: get the first study
        targetStudyID = studyList{1};
        if options.Verbose
            fprintf('Fetching metadata for first study (ID: %s)...\n', targetStudyID);
        end
    else
        % User-specified behavior: get the requested study
        targetStudyID = options.StudyID;
        if options.Verbose
            fprintf('Fetching metadata for specified study (ID: %s)...\n', targetStudyID);
        end
    end
    
    studyMetadataURL = [orthancBaseURL, '/studies/', targetStudyID];
    studyMetadata = webread(studyMetadataURL, webOpts);
    
    % --- 3. Display Key Information ---
    if options.Verbose
        fprintf('--- Successfully Retrieved Metadata ---\n');
        
        if isfield(studyMetadata, 'PatientMainDicomTags') && isfield(studyMetadata.PatientMainDicomTags, 'PatientName')
            fprintf('Patient Name: %s\n', studyMetadata.PatientMainDicomTags.PatientName);
        else
            fprintf('Could not find expected "PatientMainDicomTags.PatientName" field.\n');
        end
    end
    
catch ME
    if options.Verbose
        fprintf('Error: Succeeded in fetching study list, but failed to get metadata for Study ID %s.\n', targetStudyID);
        fprintf('Reason: %s\n', ME.message);
    end
end

if options.Verbose
    fprintf('--- DWiM Connection Test End ---\n');
end

end