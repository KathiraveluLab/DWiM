function results = queryOrthanc(options)
%QUERYORTHANC Advanced DICOM query with filtering and sorting
%
%   results = dwim.retrieval.queryOrthanc() returns all studies
%
%   results = dwim.retrieval.queryOrthanc('Modality', 'CT') returns
%   CT studies only
%
%   Name-Value Arguments:
%       PatientID        - Filter by patient ID
%       PatientName      - Filter by patient name (wildcards: *)
%       Modality         - Filter by modality (CT, MR, PT, etc.)
%       StudyDate        - Filter by date (YYYYMMDD or YYYYMMDD-YYYYMMDD)
%       StudyDescription - Filter by study description
%       Limit            - Maximum number of results (default: inf)
%       SortBy           - Sort field ('StudyDate', 'PatientName')
%       SortOrder        - 'ascend' or 'descend' (default: 'descend')
%       Verbose          - Display progress (default: false)
%
%   Returns:
%       results - Table with study information
%
%   Examples:
%       % Get all CT studies from 2025
%       results = dwim.retrieval.queryOrthanc( ...
%           'Modality', 'CT', 'StudyDate', '20250101-20251231');
%
%       % Get recent 10 MR studies
%       results = dwim.retrieval.queryOrthanc( ...
%           'Modality', 'MR', 'Limit', 10, 'SortBy', 'StudyDate');
%
%       % Search by patient name (wildcard)
%       results = dwim.retrieval.queryOrthanc('PatientName', 'Smith*');

arguments
    options.PatientID (1,1) string = ""
    options.PatientName (1,1) string = ""
    options.Modality (1,1) string = ""
    options.StudyDate (1,1) string = ""
    options.StudyDescription (1,1) string = ""
    options.Limit (1,1) double {mustBePositive} = inf
    options.SortBy (1,1) string {mustBeMember(options.SortBy, ...
        ["", "StudyDate", "PatientName", "Modality"])} = ""
    options.SortOrder (1,1) string {mustBeMember(options.SortOrder, ...
        ["ascend", "descend"])} = "descend"
    options.Verbose (1,1) logical = false
    options.Client = []  % Optional existing OrthancClient instance
end

if options.Verbose
    fprintf('=== DWiM: Querying Orthanc ===\n');
end

% Create or use existing Orthanc client
if isempty(options.Client)
    client = dwim.retrieval.OrthancClient('Verbose', options.Verbose);
else
    client = options.Client;
end

% Build query structure
query = struct();
if options.PatientID ~= ""
    query.PatientID = options.PatientID;
end
if options.PatientName ~= ""
    query.PatientName = options.PatientName;
end
if options.Modality ~= ""
    % Maps public 'Modality' option to Orthanc API field 'ModalitiesInStudy'
    query.ModalitiesInStudy = options.Modality;
end
if options.StudyDate ~= ""
    query.StudyDate = options.StudyDate;
end
if options.StudyDescription ~= ""
    query.StudyDescription = options.StudyDescription;
end

% Execute query
if isempty(fieldnames(query))
    % No filters - use wildcard to retrieve all studies efficiently
    % This avoids N+1 API calls (listStudies + getStudy for each)
    if options.Verbose
        fprintf('No filters specified, retrieving all studies...\n');
    end
    query.PatientID = '*';  % Wildcard matches all patients
end

% Use advanced find with filters (or wildcard)
% Pass limit to server for efficient filtering
if options.Verbose
    fprintf('Executing query...\n');
end
studyData = client.findStudies(query, 'Limit', options.Limit);

if isempty(studyData)
    if options.Verbose
        fprintf('No studies match the query criteria.\n');
    end
    results = table();
    return;
end

% Convert to table format
numStudies = numel(studyData);
results = table();
results.StudyID = cell(numStudies, 1);
results.PatientID = cell(numStudies, 1);
results.PatientName = cell(numStudies, 1);
results.StudyDate = cell(numStudies, 1);
results.StudyDescription = cell(numStudies, 1);
results.Modality = cell(numStudies, 1);
results.SeriesCount = zeros(numStudies, 1);
results.InstanceCount = zeros(numStudies, 1);
results.Series = cell(numStudies, 1);

for i = 1:numStudies
    study = studyData{i};
    
    % Extract study ID (handle both expanded and non-expanded results)
    if isfield(study, 'ID')
        results.StudyID{i} = study.ID;
    end
    
    % Extract main DICOM tags
    if isfield(study, 'MainDicomTags')
        tags = study.MainDicomTags;
        if isfield(tags, 'StudyDate')
            results.StudyDate{i} = tags.StudyDate;
        end
        if isfield(tags, 'StudyDescription')
            results.StudyDescription{i} = tags.StudyDescription;
        end
    end
    
    % Extract patient DICOM tags
    if isfield(study, 'PatientMainDicomTags')
        patTags = study.PatientMainDicomTags;
        if isfield(patTags, 'PatientID')
            results.PatientID{i} = patTags.PatientID;
        end
        if isfield(patTags, 'PatientName')
            results.PatientName{i} = patTags.PatientName;
        end
    end
    
    % Extract series information
    % Note: findStudies with Expand=true returns nested series data
    if isfield(study, 'Series') && ~isempty(study.Series)
        results.Series{i} = study.Series;  % Store for batch operations
        results.SeriesCount(i) = numel(study.Series);
        
        try
            % Extract series data consistently whether it's an array of structs, 
            % a cell array of structs, or just IDs (as a fallback)
            numSeries = numel(study.Series);
            modalityList = cell(numSeries, 1);
            modalityCount = 0;
            totalInstances = 0;
            
            for j = 1:numSeries
                % Extract single series depending on format
                if iscell(study.Series)
                    seriesObj = study.Series{j};
                else
                    seriesObj = study.Series(j);
                end
                
                % If it's just an ID string, fetch the expanded struct
                if ischar(seriesObj) || isstring(seriesObj)
                    seriesObj = client.getSeries(seriesObj);
                end
                
                % Extract modality
                if isfield(seriesObj, 'MainDicomTags') && ...
                   isfield(seriesObj.MainDicomTags, 'Modality')
                    modalityCount = modalityCount + 1;
                    modalityList{modalityCount} = seriesObj.MainDicomTags.Modality;
                end
                
                % Extract instance count
                if isfield(seriesObj, 'Instances')
                    totalInstances = totalInstances + numel(seriesObj.Instances);
                end
            end
            
            % Handle modalities
            if modalityCount > 0
                modalityList = modalityList(1:modalityCount);
                uniqueModalities = unique(modalityList);
                results.Modality{i} = strjoin(uniqueModalities, ', ');
            end
            
            results.InstanceCount(i) = totalInstances;
        catch ME
            % Log warning if series metadata unavailable
            warning('queryOrthanc:SeriesMetadata', ...
                'Could not retrieve metadata for series in study %s: %s', ...
                study.ID, ME.message);
        end
    end
end

% Apply sorting
if options.SortBy ~= ""
    try
        results = sortrows(results, options.SortBy, options.SortOrder);
    catch
        warning('Failed to sort by %s, returning unsorted results', options.SortBy);
    end
end

if options.Verbose
    fprintf('Query complete: %d studies found\n', height(results));
    fprintf('=============================\n');
end

end
