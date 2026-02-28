%% DWiM Orthanc Retrieval Examples
%
% This script demonstrates the DICOM retrieval capabilities of DWiM
% using the Orthanc PACS REST API.
%
% Prerequisites:
%   - Orthanc server running (default: http://localhost:8042)
%   - DICOM studies loaded in Orthanc
%   - Credentials configured in dwim.config()

%% Example 1: Basic Connection Test
fprintf('Example 1: Testing Orthanc connection...\n');

try
    % Create client
    client = dwim.retrieval.OrthancClient('Verbose', true);
    
    % Get system info
    info = client.getSystemInfo();
    fprintf('  Orthanc Version: %s\n', info.Version);
    
    % List available studies
    studies = client.listStudies();
    fprintf('  Available studies: %d\n', numel(studies));
    
catch ME
    fprintf('  Connection failed: %s\n', ME.message);
    fprintf('  Make sure Orthanc is running and credentials are correct.\n');
end

fprintf('\n');

%% Example 2: Query Studies with Filters
fprintf('Example 2: Querying studies...\n');

try
    % Query all CT studies
    query1 = struct();
    query1.Modality = 'CT';
    results1 = dwim.retrieval.queryOrthanc(query1, 'Verbose', false);
    
    fprintf('  CT studies found: %d\n', height(results1));
    if height(results1) > 0
        disp(results1(1:min(3, height(results1)), :));
    end
    
    % Query with date range
    query2 = struct();
    query2.StudyDate = '20250101-20251231';
    results2 = dwim.retrieval.queryOrthanc(query2, 'Verbose', false);
    
    fprintf('  Studies in 2025: %d\n', height(results2));
    
catch ME
    fprintf('  Query failed: %s\n', ME.message);
end

fprintf('\n');

%% Example 3: Download Single Series
fprintf('Example 3: Downloading single series...\n');

try
    % Get first series from first study
    studies = client.listStudies();
    if ~isempty(studies)
        studyInfo = client.getStudy(studies{1});
        if isfield(studyInfo, 'Series') && ~isempty(studyInfo.Series)
            seriesID = studyInfo.Series{1};
            
            % Download series
            outputDir = fullfile(pwd, 'temp_download');
            seriesPath = client.downloadSeries(seriesID, outputDir);
            
            fprintf('  Downloaded to: %s\n', seriesPath);
            
            % Count files
            files = dir(fullfile(seriesPath, '*.dcm'));
            fprintf('  Files downloaded: %d\n', numel(files));
            
            % Cleanup (optional)
            % rmdir(outputDir, 's');
        end
    end
    
catch ME
    fprintf('  Download failed: %s\n', ME.message);
end

fprintf('\n');

%% Example 4: Batch Retrieval
fprintf('Example 4: Batch retrieval...\n');

try
    % Define query for batch retrieval
    query = struct();
    query.Modality = 'CT';
    
    % Download first 5 matching studies
    outputDir = fullfile(pwd, 'batch_downloads');
    summary = dwim.retrieval.retrieveBatch(query, outputDir, ...
        'MaxStudies', 5, ...
        'Parallel', false, ...
        'Verbose', true);
    
    fprintf('\n  Batch Summary:\n');
    fprintf('    Studies downloaded: %d\n', summary.studiesDownloaded);
    fprintf('    Series downloaded: %d\n', summary.seriesDownloaded);
    fprintf('    Files downloaded: %d\n', summary.filesDownloaded);
    fprintf('    Duration: %s\n', string(summary.duration));
    
catch ME
    fprintf('  Batch retrieval failed: %s\n', ME.message);
end

fprintf('\n');

%% Example 5: Retrieve and Process to 3D Volumes
fprintf('Example 5: Retrieve with 3D volume processing...\n');

try
    query = struct();
    query.Modality = 'CT';
    
    % Download and process to volumes
    outputDir = fullfile(pwd, 'processed_volumes');
    summary = dwim.retrieval.retrieveBatch(query, outputDir, ...
        'MaxStudies', 2, ...
        'ProcessVolumes', true, ...
        'Parallel', false, ...
        'Verbose', true);
    
    fprintf('\n  Volume Processing Summary:\n');
    fprintf('    Volumes created: %d\n', numel(summary.volumes));
    
    % Display volume information
    for i = 1:numel(summary.volumes)
        if ~isempty(summary.volumes{i})
            vol = summary.volumes{i};
            sz = size(vol.volume);
            fprintf('    Volume %d: %dx%dx%d, spacing: [%.2f %.2f %.2f]mm\n', ...
                i, sz(1), sz(2), sz(3), ...
                vol.spacing(1), vol.spacing(2), vol.spacing(3));
        end
    end
    
catch ME
    fprintf('  Processing failed: %s\n', ME.message);
end

fprintf('\n');

%% Example 6: Custom Callback Function
fprintf('Example 6: Using custom callback...\n');

try
    % Define callback to execute after each study download
    callback = @(studyPath, metadata) fprintf('  Completed: %s (%s)\n', ...
        metadata.PatientID{1}, metadata.StudyDate{1});
    
    query = struct();
    query.Modality = 'CT';
    
    outputDir = fullfile(pwd, 'callback_example');
    summary = dwim.retrieval.retrieveBatch(query, outputDir, ...
        'MaxStudies', 3, ...
        'OnStudyComplete', callback, ...
        'Parallel', false, ...
        'Verbose', false);
    
    fprintf('  Downloaded %d studies with callbacks\n', summary.studiesDownloaded);
    
catch ME
    fprintf('  Callback example failed: %s\n', ME.message);
end

fprintf('\n');

%% Example 7: Advanced Query with Sorting
fprintf('Example 7: Advanced query with sorting...\n');

try
    query = struct();
    query.Modality = 'CT';
    query.SortBy = 'StudyDate';
    query.SortOrder = 'descend';
    query.Limit = 10;
    
    results = dwim.retrieval.queryOrthanc(query, 'Verbose', false);
    
    fprintf('  Most recent 10 CT studies:\n');
    if height(results) > 0
        disp(results(:, {'StudyDate', 'PatientID', 'StudyDescription'}));
    end
    
catch ME
    fprintf('  Advanced query failed: %s\n', ME.message);
end

fprintf('\n');
fprintf('All examples complete!\n');
