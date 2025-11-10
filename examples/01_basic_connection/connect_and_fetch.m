% connect_and_fetch.m
%
% Description:
%   Demonstrates a basic connection to an Orthanc PACS server from MATLAB.
%   It fetches a list of all studies and then retrieves the detailed
%   metadata for the first study in the list.
%
% Project: DWiM (DICOM Workflow in MATLAB)
% Author: Suryansh Maurya
% Date: 06-Nov-2025

clear; clc;

%% --- Configuration ---
% All user-configurable settings are here.
orthancBaseURL = 'http://localhost:8042';
orthancUser = 'orthanc';
orthancPass = 'orthanc';

fprintf('--- DWiM Connection Test Start ---\n');

%% --- Set Up Web Options ---
% Using weboptions for clean, reusable request settings.
% 'ContentType' is 'json' because we are talking to a REST API.
try
    options = weboptions(...
        'Username', orthancUser, ...
        'Password', orthancPass, ...
        'MediaType', 'application/json', ...
        'Timeout', 30 ...
    );
catch ME
    % This can fail if a required toolbox is missing
    if strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
        fprintf('Error: Failed to create weboptions. Do you have the required toolboxes?\n');
        fprintf('This script requires MATLAB''s HTTP Interface.\n');
    end
    rethrow(ME);
end

%% --- 1. Test Connection & Get Study List ---
allStudiesURL = [orthancBaseURL, '/studies'];
fprintf('Attempting to connect to %s ...\n', orthancBaseURL);

try
    studyList = webread(allStudiesURL, options);
    
    if isempty(studyList)
        fprintf('Success! Connected to Orthanc, but no studies were found.\n');
        fprintf('Please (re)upload sample data to your Orthanc server.\n');
        fprintf('--- DWiM Connection Test End ---\n');
        return; % Stop the script
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
    fprintf('--- DWiM Connection Test End ---\n');
    return; % Stop the script
end

%% --- 2. Fetch Metadata for the First Study ---
% This proves we can retrieve specific data (Your Phase 1 goal)
try
    firstStudyID = studyList{1};
    fprintf('Fetching metadata for first study (ID: %s)...\n', firstStudyID);
    
    studyMetadataURL = [orthancBaseURL, '/studies/', firstStudyID];
    studyMetadata = webread(studyMetadataURL, options);
    
    % --- 3. Display Key Information ---
    fprintf('--- Successfully Retrieved Metadata ---\n');
    
    % Display some key fields to prove it worked
    if isfield(studyMetadata, 'PatientMainDicomTags')
        fprintf('Patient Name: %s\n', studyMetadata.PatientMainDicomTags.PatientName);
        %fprintf('Study Date:   %s\n', studyMetadata.PatientMainDicomTags.StudyDate);
        %fprintf('Study Desc:   %s\n', studyMetadata.PatientMainDicomTags.StudyDescription);
    else
        fprintf('Could not find expected "PatientMainDicomTags" field.\n');
        disp(studyMetadata); % Display the whole struct for debugging
    end
    
catch ME
    fprintf('Error: Succeeded in fetching study list, but failed to get metadata for Study ID %s.\n', firstStudyID);
    fprintf('Reason: %s\n', ME.message);
end

fprintf('--- DWiM Connection Test End ---\n');