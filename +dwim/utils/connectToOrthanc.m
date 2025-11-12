function [studyList, studyMetadata] = connectToOrthanc()
%CONNECTTOORTHANC Connects to Orthanc and fetches metadata for the first study.
%   This is a utility function refactored from the Phase 1 example.

%% --- Configuration ---
% All user-configurable settings are here.
orthancBaseURL = 'http://localhost:8042';
orthancUser = 'orthanc';
orthancPass = 'orthanc';

fprintf('--- DWiM: Connecting to Orthanc ---\n');

% Default outputs
studyList = [];
studyMetadata = [];

%% --- Set Up Web Options ---
try
    options = weboptions(...
        'Username', orthancUser, ...
        'Password', orthancPass, ...
        'MediaType', 'application/json', ...
        'Timeout', 30 ...
    );
catch ME
    fprintf('Error: Failed to create weboptions. Do you have the required toolboxes?\n');
    rethrow(ME);
end

%% --- 1. Test Connection & Get Study List ---
allStudiesURL = [orthancBaseURL, '/studies'];
fprintf('Attempting to connect to %s ...\n', orthancBaseURL);

try
    studyList = webread(allStudiesURL, options);

    if isempty(studyList)
        fprintf('Success! Connected to Orthanc, but no studies were found.\n');
        return; % Stop the function
    end

    fprintf('Success! Connected to Orthanc. Found %d studies.\n\n', numel(studyList));

catch ME
    fprintf('Error: Failed to connect or read from Orthanc.\n');
    if contains(ME.message, '401')
        fprintf('Reason: HTTP 401 Unauthorized. Check your username and password.\n');
    elseif contains(ME.message, 'Connection refused')
        fprintf('Reason: Connection refused. Is the Orthanc Docker container running?\n');
    else
        fprintf('Reason: %s\n', ME.message);
    end
    return; % Stop the function
end

%% --- 2. Fetch Metadata for the First Study ---
try
    firstStudyID = studyList{1};
    fprintf('Fetching metadata for first study (ID: %s)...\n', firstStudyID);

    studyMetadataURL = [orthancBaseURL, '/studies/', firstStudyID];
    studyMetadata = webread(studyMetadataURL, options);

    % --- 3. Display Key Information ---
    fprintf('--- Successfully Retrieved Metadata ---\n');

    if isfield(studyMetadata, 'PatientMainDicomTags')
        fprintf('Patient Name: %s\n', studyMetadata.PatientMainDicomTags.PatientName);
    else
        fprintf('Could not find expected "PatientMainDicomTags" field.\n');
        disp(studyMetadata); % Display the whole struct for debugging
    end

catch ME
    fprintf('Error: Succeeded in fetching study list, but failed to get metadata for Study ID %s.\n', firstStudyID);
    fprintf('Reason: %s\n', ME.message);
end

fprintf('--- DWiM Connection Test End ---\n');

end