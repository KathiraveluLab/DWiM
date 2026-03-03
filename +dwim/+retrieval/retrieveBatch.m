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
%                           Processes all series in each study
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
%           'ProcessVolumes', true);
%
%       % Custom callback for each study
%       callback = @(studyPath, metadata) fprintf('Downloaded: %s\n', studyPath);
%       summary = dwim.retrieval.retrieveBatch(query, './output', ...
%           'OnStudyComplete', callback);

arguments
    queryParams (1,1) struct
    outputDir (1,1) string = "./orthanc_downloads"
    options.ProcessVolumes (1,1) logical = false
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
summary.partialDownloads = {};  % Track series with incomplete downloads
summary.studyPaths = {};

% Step 1: Query Orthanc for matching studies
if options.Verbose
    fprintf('\nStep 1/3: Querying Orthanc...\n');
end

try
    % Determine effective limit (combine MaxStudies with query Limit)
    effectiveLimit = options.MaxStudies;
    if isfield(queryParams, 'Limit') && ~isinf(queryParams.Limit)
        effectiveLimit = min(effectiveLimit, queryParams.Limit);
    end
    
    % Convert struct to name-value pairs for queryOrthanc (efficient)
    queryArgs = {};
    if ~isempty(fieldnames(queryParams))
        fields = fieldnames(queryParams);
        values = struct2cell(queryParams);
        queryArgs = [fields'; values'];
        queryArgs = queryArgs(:)';
    end
    queryArgs = [queryArgs, {'Limit', effectiveLimit, 'Verbose', options.Verbose}];
    
    studies = dwim.retrieval.queryOrthanc(queryArgs{:});
    
    if isempty(studies) || height(studies) == 0
        if options.Verbose
            fprintf('No studies match query criteria.\n');
        end
        summary.endTime = datetime('now');
        summary.duration = summary.endTime - summary.startTime;
        return;
    end
    
    numStudies = height(studies);
    
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

% Download each study
if options.Parallel && numStudies > 1
    % Parallel download
    % Create client inside parfor for thread safety
    studyPaths = cell(numStudies, 1);
    seriesCounts = zeros(numStudies, 1);
    fileCounts = zeros(numStudies, 1);
    errors = cell(numStudies, 1);
    allPartials = cell(numStudies, 1);  % Collect partial downloads
    
    parfor i = 1:numStudies
        try
            % Each worker creates its own client instance
            workerClient = dwim.retrieval.OrthancClient('Verbose', false);
            [studyPaths{i}, seriesCounts(i), fileCounts(i), allPartials{i}] = ...
                downloadStudy(workerClient, studies(i,:), outputDir, options);
        catch ME
            errors{i} = ME.message;
        end
    end
    
    % Aggregate results
    summary.studyPaths = studyPaths(~cellfun('isempty', studyPaths));
    summary.seriesDownloaded = sum(seriesCounts);
    summary.filesDownloaded = sum(fileCounts);
    summary.errors = errors(~cellfun('isempty', errors));
    
    % Flatten partial downloads from all studies
    nonEmptyPartials = allPartials(~cellfun('isempty', allPartials));
    if ~isempty(nonEmptyPartials)
        summary.partialDownloads = [nonEmptyPartials{:}];
    else
        summary.partialDownloads = {};
    end
    
else
    % Serial download
    client = dwim.retrieval.OrthancClient('Verbose', false);
    
    % Pre-allocate arrays for efficiency
    summary.studyPaths = cell(numStudies, 1);
    summary.errors = cell(numStudies, 1);
    allPartials = cell(numStudies, 1);
    successCount = 0;
    errorCount = 0;
    
    for i = 1:numStudies
        try
            [studyPath, seriesCount, fileCount, studyPartials] = ...
                downloadStudy(client, studies(i,:), outputDir, options);
            
            successCount = successCount + 1;
            summary.studyPaths{successCount} = studyPath;
            summary.seriesDownloaded = summary.seriesDownloaded + seriesCount;
            summary.filesDownloaded = summary.filesDownloaded + fileCount;
            
            % Aggregate partial downloads from this study
            allPartials{i} = studyPartials;
            
            % Call user callback if provided
            if ~isempty(options.OnStudyComplete)
                try
                    options.OnStudyComplete(studyPath, studies(i,:));
                catch callbackErr
                    warning('User callback failed for study %s: %s', studyPath, callbackErr.message);
                end
            end
            
            if options.Verbose
                fprintf('  Study %d/%d complete: %d series, %d files\n', ...
                    i, numStudies, seriesCount, fileCount);
            end
            
        catch ME
            errorCount = errorCount + 1;
            summary.errors{errorCount} = ME.message;
            if options.Verbose
                fprintf('  Study %d/%d failed: %s\n', i, numStudies, ME.message);
            end
        end
    end
    
    % Trim unused portions of pre-allocated arrays
    summary.studyPaths = summary.studyPaths(1:successCount);
    summary.errors = summary.errors(1:errorCount);
    
    % Aggregate partial downloads
    nonEmptyPartials = allPartials(1:successCount);
    nonEmptyPartials = nonEmptyPartials(~cellfun('isempty', nonEmptyPartials));
    if ~isempty(nonEmptyPartials)
        summary.partialDownloads = [nonEmptyPartials{:}];
    else
        summary.partialDownloads = {};
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
                % Process all series in the study
                seriesVolumes = cell(numel(seriesDirs), 1);
                
                for s = 1:numel(seriesDirs)
                    seriesPath = fullfile(studyPath, seriesDirs(s).name);
                    
                    try
                        [volume, spacing, metadata] = ...
                            dwim.preprocess3d.buildVolumeFromSeries(seriesPath, ...
                            'Verbose', false);
                        
                        seriesVolumes{s} = struct(...
                            'volume', volume, ...
                            'spacing', spacing, ...
                            'metadata', metadata, ...
                            'path', seriesPath);
                        
                        if options.Verbose
                            fprintf('  Processed volume %d series %d/%d: %dx%dx%d\n', ...
                                i, s, numel(seriesDirs), ...
                                size(volume,1), size(volume,2), size(volume,3));
                        end
                    catch seriesErr
                        if options.Verbose
                            fprintf('  Volume processing failed for study %d series %d: %s\n', ...
                                i, s, seriesErr.message);
                        end
                    end
                end
                
                % Store all successfully built volumes for this study
                built = ~cellfun('isempty', seriesVolumes);
                summary.volumes{i} = seriesVolumes(built);
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
function [studyPath, seriesCount, fileCount, partials] = downloadStudy(client, study, baseDir, options)
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
    
    % Get series list from study table (avoids N+1 API call)
    if ~isempty(study.Series{1})
        % Use series data from queryOrthanc result
        seriesList = study.Series{1};
    else
        % Fallback: fetch from API if not in table
        studyInfo = client.getStudy(studyID);
        seriesList = studyInfo.Series;
    end
    seriesCount = numel(seriesList);
    fileCount = 0;
    partials = {};  % Collect partial download info locally
    
    % Download each series
    for j = 1:seriesCount
        % Extract series ID (handle both struct and string formats)
        if isstruct(seriesList)
            seriesID = seriesList(j).ID;  % Expanded struct from query
        elseif iscell(seriesList)
            if isstruct(seriesList{j})
                seriesID = seriesList{j}.ID;  % Struct in cell
            else
                seriesID = seriesList{j};  % String ID in cell
            end
        else
            seriesID = seriesList(j);  % Direct string
        end
        
        seriesDir = fullfile(studyPath, sprintf('series_%02d', j));
        
        % Download series and track partial failures
        [~, failedInst, dlCount] = client.downloadSeries(seriesID, seriesDir, 'CreateSubdir', false);
        
        % Record partial download failures locally
        if ~isempty(failedInst)
            partials{end+1} = struct(...
                'studyID', studyID, ...
                'seriesID', seriesID, ...
                'failedInstances', {failedInst}); %#ok<AGROW>
        end
        
        % Use download count returned by client instead of filesystem I/O
        fileCount = fileCount + dlCount;
    end
end
