function [studyList, studyMetadata] = connectToOrthanc(options)
%CONNECTTOORTHANC Connects to Orthanc and fetches study data.
%   Uses default settings from dwim.config() unless overridden.

%   Note: We call dwim.config() directly in the arguments block to ensure
%   we always use the latest central defaults.

arguments
    options.BaseURL (1,1) string = dwim.config().Orthanc.BaseURL
    options.User (1,1) string = dwim.config().Orthanc.User
    options.Password (1,1) string = dwim.config().Orthanc.Password
    options.Verbose (1,1) logical = dwim.config().Defaults.Verbose
    options.StudyID (1,1) string = "" 
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
    % Specific check for missing toolboxes
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
        return; 
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
    return; 
end

%% --- 2. Fetch Metadata for the Requested Study ---
targetStudyID = ''; % Initialize variable 
try
    if options.StudyID == ""
        targetStudyID = studyList{1};
        if options.Verbose
            fprintf('Fetching metadata for first study (ID: %s)...\n', targetStudyID);
        end
    else
        targetStudyID = options.StudyID;
        if options.Verbose
            fprintf('Fetching metadata for specified study (ID: %s)...\n', targetStudyID);
        end
    end
    
    studyMetadataURL = [orthancBaseURL, '/studies/', targetStudyID];
    studyMetadata = webread(studyMetadataURL, webOpts);
    
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