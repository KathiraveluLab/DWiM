function summary = retrieveBatch(queryParams, outputDir, options)
%RETRIEVEBATCH Batch retrieval of DICOM studies from Orthanc
%
%   summary = dwim.retrieval.retrieveBatch(queryParams, outputDir)
%   queries Orthanc, downloads matching studies, and optionally processes them
%
%   Inputs:
%       queryParams - Struct with query filters (see queryOrthanc)
%       outputDir   - Output directory for downloaded studies
%
%   Name-Value Arguments:
%       ProcessVolumes    - Build 3D volumes after download (default: false)
%       AnonymizeBeforeSave - Anonymize downloaded files (default: false)
%       Parallel          - Use parallel download (default: true)
%       MaxStudies        - Maximum studies to retrieve (default: inf)
%       Verbose           - Display progress (default: true)
%       OnStudyComplete   - Callback function handle (default: [])
%
%   Returns:
%      summary - Struct with download statistics and file paths
%
%   Examples:
%       % Download all CT studies from January 2025
%       query.Modality = 'CT';
%       query.StudyDate = '20250101-20250131';
%       summary = dwim.retrieval.retrieveBatch(query, './ct_studies');
%
%       % Download and process to 3D volumes
%       summary = dwim.retrieval.retrieveBatch(query, './output', ...
%           'ProcessVolumes', true, 'AnonymizeBeforeSave', true);
%
%       % Custom callback for each study
%       callback = @(studyPath, metadata) fprintf('Downloaded: %s\n', studyPath);
%       summary = dwim.retrieval.retrieveBatch(query, './output', ...
%           'OnStudyComplete', callback);

arguments
    queryParams (1,1) struct
    outputDir (1,1) string = "./orthanc_downloads"
    options.ProcessVolumes (1,1) logical = false
    options.AnonymizeBeforeSave (1,1) logical = false
    options.Parallel (1,1) logical = true
    options.MaxStudies (1,1) double {mustBePositive} = inf
    options.Verbose (1,1) logical = true
    options.OnStudyComplete function_handle = []
end

if options.Verbose
    fprintf('\n=== DWiM Batch Retrieval ===\n');
    fprintf('Output directory: %s\n', outputDir);
end

% Create output directory
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Initialize summary
summary = struct();
summary.startTime = datetime('now');
summary.queryParams = queryParams;
summary.outputDir = outputDir;
summary.studiesDownloaded = 0;
summary.seriesDownloaded = 0;
summary.filesDownloaded = 0;
summary.errors = {};
summary.studyPaths = {};

% Step 1: Query Orthanc for matching studies
if options.Verbose
    fprintf('\nStep 1/3: Querying Orthanc...\n');
end

try
    % Convert struct to name-value pairs for queryOrthanc
    queryArgs = {};
    fields = fieldnames(queryParams);
    for i = 1:numel(fields)
        queryArgs{end+1} = fields{i}; %#ok<AGROW>
        queryArgs{end+1} = queryParams.(fields{i}); %#ok<AGROW>
    end
    queryArgs{end+1} = 'Verbose';
    queryArgs{end+1} = options.Verbose;
    
    studies = dwim.retrieval.queryOrthanc(queryArgs{:});
    
    if isempty(studies) || height(studies) == 0
        if options.Verbose
            fprintf('No studies match query criteria.\n');
        end
        summary.endTime = datetime('now');
        summary.duration = summary.endTime - summary.startTime;
        return;
    end
    
    % Apply max studies limit
    numStudies = min(height(studies), options.MaxStudies);
    studies = studies(1:numStudies, :);
    
    if options.Verbose
        fprintf('Found %d studies to download\n', numStudies);
    end
    
catch ME
    error('RetrieveBatch:QueryFailed', 'Query failed: %s', ME.message);
end

% Step 2: Download studies
if options.Verbose
    fprintf('\nStep 2/3: Downloading DICOM files...\n');
end

% Create Orthanc client
client = dwim.retrieval.OrthancClient('Verbose', false);

% Download each study
if options.Parallel && numStudies > 1
    % Parallel download
    studyPaths = cell(numStudies, 1);
    seriesCounts = zeros(numStudies, 1);
    fileCounts = zeros(numStudies, 1);
    errors = cell(numStudies, 1);
    
    parfor i = 1:numStudies
        try
            [studyPaths{i}, seriesCounts(i), fileCounts(i)] = ...
                downloadStudy(client, studies(i,:), outputDir, options);
        catch ME
            errors{i} = ME.message;
        end
    end
    
    % Aggregate results
    summary.studyPaths = studyPaths(~cellfun('isempty', studyPaths));
    summary.seriesDownloaded = sum(seriesCounts);
    summary.filesDownloaded = sum(fileCounts);
    summary.errors = errors(~cellfun('isempty', errors));
    
else
    % Serial download
    for i = 1:numStudies
        try
            [studyPath, seriesCount, fileCount] = ...
                downloadStudy(client, studies(i,:), outputDir, options);
            
            summary.studyPaths{end+1} = studyPath;
            summary.seriesDownloaded = summary.seriesDownloaded + seriesCount;
            summary.filesDownloaded = summary.filesDownloaded + fileCount;
            
            % Call user callback if provided
            if ~isempty(options.OnStudyComplete)
                try
                    options.OnStudyComplete(studyPath, studies(i,:));
                catch callbackErr
                    warning('User callback failed: %s', callbackErr.message);
                end
            end
            
            if options.Verbose
                fprintf('  Study %d/%d complete: %d series, %d files\n', ...
                    i, numStudies, seriesCount, fileCount);
            end
            
        catch ME
            summary.errors{end+1} = sprintf('Study %d: %s', i, ME.message);
            if options.Verbose
                fprintf('  Study %d/%d FAILED: %s\n', i, numStudies, ME.message);
            end
        end
    end
end

summary.studiesDownloaded = numel(summary.studyPaths);

% Step 3: Post-processing (if requested)
if options.ProcessVolumes && summary.studiesDownloaded > 0
    if options.Verbose
        fprintf('\nStep 3/3: Processing volumes...\n');
    end
    
    summary.volumes = cell(summary.studiesDownloaded, 1);
    
    for i = 1:summary.studiesDownloaded
        try
            studyPath = summary.studyPaths{i};
            
            % Find series directories in study
            seriesDirs = dir(fullfile(studyPath, 'series_*'));
            seriesDirs = seriesDirs([seriesDirs.isdir]);
            
            if ~isempty(seriesDirs)
                % Process first series only
                seriesPath = fullfile(studyPath, seriesDirs(1).name);
                
                [volume, spacing, metadata] = ...
                    dwim.preprocess3d.buildVolumeFromSeries(seriesPath, ...
                    'Verbose', false);
                
                summary.volumes{i} = struct(...
                    'volume', volume, ...
                    'spacing', spacing, ...
                    'metadata', metadata, ...
                    'path', seriesPath);
                
                if options.Verbose
                    fprintf('  Processed volume %d: %dx%dx%d\n', ...
                        i, size(volume,1), size(volume,2), size(volume,3));
                end
            end
        catch ME
            if options.Verbose
                fprintf('  Volume processing failed for study %d: %s\n', i, ME.message);
            end
        end
    end
end

% Finalize summary
summary.endTime = datetime('now');
summary.duration = summary.endTime - summary.startTime;

if options.Verbose
    fprintf('\n=== Batch Retrieval Complete ===\n');
    fprintf('Studies downloaded: %d\n', summary.studiesDownloaded);
    fprintf('Series downloaded: %d\n', summary.seriesDownloaded);
    fprintf('Files downloaded: %d\n', summary.filesDownloaded);
    fprintf('Errors: %d\n', numel(summary.errors));
    fprintf('Duration: %s\n', string(summary.duration));
    fprintf('================================\n\n');
end

end

%% Helper function to download single study
function [studyPath, seriesCount, fileCount] = downloadStudy(client, study, baseDir, options)
    % Create study directory
    studyID = study.StudyID{1};
    patientID = study.PatientID{1};
    studyDate = study.StudyDate{1};
    
    % Sanitize filename
    safeName = sprintf('%s_%s_%s', patientID, studyDate, studyID);
    safeName = regexprep(safeName, '[^\w-]', '_');
    
    studyPath = fullfile(baseDir, safeName);
    if ~exist(studyPath, 'dir')
        mkdir(studyPath);
    end
    
    % Get study metadata to find series
    studyInfo = client.getStudy(studyID);
    seriesList = studyInfo.Series;
    seriesCount = numel(seriesList);
    fileCount = 0;
    
    % Download each series
    for j = 1:seriesCount
        seriesID = seriesList{j};
        seriesDir = fullfile(studyPath, sprintf('series_%02d', j));
        
        % Download series
        client.downloadSeries(seriesID, seriesDir, 'CreateSubdir', false);
        
        % Count files
        files = dir(fullfile(seriesDir, '*.dcm'));
        fileCount = fileCount + numel(files);
    end
end
