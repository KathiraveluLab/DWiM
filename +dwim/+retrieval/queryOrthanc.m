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
end

if options.Verbose
    fprintf('=== DWiM: Querying Orthanc ===\n');
end

% Create Orthanc client
client = dwim.retrieval.OrthancClient('Verbose', options.Verbose);

% Build query structure
query = struct();
if options.PatientID ~= ""
    query.PatientID = char(options.PatientID);
end
if options.PatientName ~= ""
    query.PatientName = char(options.PatientName);
end
if options.Modality ~= ""
    query.ModalitiesInStudy = char(options.Modality);
end
if options.StudyDate ~= ""
    query.StudyDate = char(options.StudyDate);
end
if options.StudyDescription ~= ""
    query.StudyDescription = char(options.StudyDescription);
end

% Execute query
if isempty(fieldnames(query))
    % No filters - get all studies
    if options.Verbose
        fprintf('No filters specified, retrieving all studies...\n');
    end
    studyIDs = client.listStudies();
    studyData = cell(numel(studyIDs), 1);
    for i = 1:numel(studyIDs)
        studyData{i} = client.getStudy(studyIDs{i});
        if options.Verbose && mod(i, 10) == 0
            fprintf('  Retrieved %d/%d studies\n', i, numel(studyIDs));
        end
    end
else
    % Use advanced find with filters
    if options.Verbose
        fprintf('Executing filtered query...\n');
    end
    studyData = client.findStudies(query);
end

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
    if isfield(study, 'Series')
        results.SeriesCount(i) = numel(study.Series);
        
        % Get modality from first series
        if numel(study.Series) > 0
            try
                firstSeries = client.getSeries(study.Series{1});
                if isfield(firstSeries, 'MainDicomTags') && ...
                   isfield(firstSeries.MainDicomTags, 'Modality')
                    results.Modality{i} = firstSeries.MainDicomTags.Modality;
                end
                
                % Count total instances
                totalInstances = 0;
                for j = 1:numel(study.Series)
                    seriesInfo = client.getSeries(study.Series{j});
                    if isfield(seriesInfo, 'Instances')
                        totalInstances = totalInstances + numel(seriesInfo.Instances);
                    end
                end
                results.InstanceCount(i) = totalInstances;
            catch
                % Skip if series metadata unavailable
            end
        end
    end
end

% Apply limit
if ~isinf(options.Limit) && height(results) > options.Limit
    results = results(1:options.Limit, :);
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
