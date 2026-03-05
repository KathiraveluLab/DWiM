classdef OrthancClient < handle
    %ORTHANCLIENT Object-oriented REST API wrapper for Orthanc PACS
    %
    %   client = dwim.retrieval.OrthancClient() creates a client using
    %   default configuration from dwim.config()
    %
    %   client = dwim.retrieval.OrthancClient('BaseURL', url, ...) creates
    %   a client with custom configuration
    %
    %   Methods:
    %       listPatients()      - Get all patient IDs
    %       listStudies()       - Get all study IDs
    %       listSeries()        - Get all series IDs
    %       getPatient(id)      - Get patient metadata
    %       getStudy(id)        - Get study metadata
    %       getSeries(id)       - Get series metadata
    %       findStudies(query)  - Advanced study search
    %       downloadSeries(id)  - Download series as DICOM files
    %       getSystemInfo()     - Get Orthanc server information
    %
    %   Example:
    %       client = dwim.retrieval.OrthancClient();
    %       studies = client.listStudies();
    %       metadata = client.getStudy(studies{1});
    
    properties (Access = private)
        BaseURL     string
        WebOptions  weboptions
        Verbose     logical
    end
    
    methods
        function obj = OrthancClient(options)
            %ORTHANCLIENT Constructor
            arguments
                options.BaseURL (1,1) string = dwim.config().Orthanc.BaseURL
                options.User (1,1) string = dwim.config().Orthanc.User
                options.Password (1,1) string = dwim.config().Orthanc.Password
                options.Verbose (1,1) logical = false
                options.Timeout (1,1) double {mustBePositive} = 30
                options.TestConnection (1,1) logical = true
            end
            
            obj.BaseURL = options.BaseURL;
            obj.Verbose = options.Verbose;
            
            % Create web options for all requests
            % Credentials are stored only in weboptions to avoid retaining
            % sensitive information as separate object properties
            obj.WebOptions = weboptions(...
                'Username', options.User, ...
                'Password', options.Password, ...
                'MediaType', 'application/json', ...
                'Timeout', options.Timeout, ...
                'ContentType', 'json');
            
            % Test connection
            if options.TestConnection
                if obj.Verbose
                    fprintf('OrthancClient: Testing connection to %s...\n', obj.BaseURL);
                end
                obj.testConnection();
            end
        end
        
        function info = getSystemInfo(obj)
            %GETSYSTEMINFO Get Orthanc server system information
            url = obj.BaseURL + "/system";
            info = webread(url, obj.WebOptions);
            if obj.Verbose
                fprintf('Connected to Orthanc v%s\n', info.Version);
            end
        end
        
        function patientList = listPatients(obj)
            %LISTPATIENTS Get all patient IDs
            url = obj.BaseURL + "/patients";
            patientList = webread(url, obj.WebOptions);
            if obj.Verbose
                fprintf('Found %d patients\n', numel(patientList));
            end
        end
        
        function studyList = listStudies(obj)
            %LISTSTUDIES Get all study IDs
            url = obj.BaseURL + "/studies";
            studyList = webread(url, obj.WebOptions);
            if obj.Verbose
                fprintf('Found %d studies\n', numel(studyList));
            end
        end
        
        function seriesList = listSeries(obj)
            %LISTSERIES Get all series IDs
            url = obj.BaseURL + "/series";
            seriesList = webread(url, obj.WebOptions);
            if obj.Verbose
                fprintf('Found %d series\n', numel(seriesList));
            end
        end
        
        function patient = getPatient(obj, patientID)
            %GETPATIENT Get patient metadata
            arguments
                obj
                patientID (1,1) string
            end
            url = obj.BaseURL + "/patients/" + patientID;
            patient = webread(url, obj.WebOptions);
        end
        
        function study = getStudy(obj, studyID)
            %GETSTUDY Get study metadata
            arguments
                obj
                studyID (1,1) string
            end
            url = obj.BaseURL + "/studies/" + studyID;
            study = webread(url, obj.WebOptions);
        end
        
        function series = getSeries(obj, seriesID)
            %GETSERIES Get series metadata
            arguments
                obj
                seriesID (1,1) string
            end
            url = obj.BaseURL + "/series/" + seriesID;
            series = webread(url, obj.WebOptions);
        end
        
        function instance = getInstance(obj, instanceID)
            %GETINSTANCE Get instance metadata
            arguments
                obj
                instanceID (1,1) string
            end
            url = obj.BaseURL + "/instances/" + instanceID;
            instance = webread(url, obj.WebOptions);
        end
        
        function results = findStudies(obj, query, options)
            %FINDSTUDIES Advanced study search with filtering
            %
            %   results = client.findStudies(query) searches for studies
            %   matching the provided query structure
            %
            %   Query fields:
            %       PatientID       - Patient identifier
            %       PatientName     - Patient name (wildcards supported)
            %       StudyDate       - Study date (YYYYMMDD or range)
            %       Modality        - Imaging modality (CT, MR, etc.)
            %       StudyDescription - Study description
            %
            %   Name-Value Arguments:
            %       Limit - Maximum number of results (server-side)
            %
            %   Example:
            %       query.Modality = 'CT';
            %       query.StudyDate = '20250101-20251231';
            %       results = client.findStudies(query, 'Limit', 100);
            
            arguments
                obj
                query (1,1) struct
                options.Limit (1,1) double = inf
            end
            
            % Orthanc tools/find REST endpoint
            url = obj.BaseURL + "/tools/find";
            
            % Build query structure for Orthanc
            orthancQuery = struct();
            orthancQuery.Level = 'Study';
            orthancQuery.Query = query;
            orthancQuery.Expand = true;
            
            % Apply server-side limit if specified
            if ~isinf(options.Limit)
                orthancQuery.Limit = options.Limit;
            end
            
            % POST query to Orthanc
            results = webwrite(url, orthancQuery, obj.WebOptions);
            
            if obj.Verbose
                fprintf('Find query returned %d studies\n', numel(results));
            end
        end
        
        function [filepath, failedInstances, downloadCount] = downloadSeries(obj, seriesID, outputDir, options)
            %DOWNLOADSERIES Download series as DICOM files
            %
            %   [filepath, failedInstances] = client.downloadSeries(seriesID, outputDir)
            %   downloads all instances from the series to outputDir
            %
            %   Name-Value Arguments:
            %       CreateSubdir - Create subdirectory for series (default: true)
            %       Filename     - Custom filename pattern (default: auto)
            %
            %   Returns:
            %       filepath - Path to download directory
            %       failedInstances - Cell array of instance IDs that failed to download
            %       downloadCount - Number of successfully downloaded files
            
            arguments
                obj
                seriesID (1,1) string
                outputDir (1,1) string = "."
                options.CreateSubdir (1,1) logical = true
                options.Filename (1,1) string = ""
            end
            
            % Get series metadata to find instances
            try
                seriesInfo = obj.getSeries(seriesID);
                if ~isfield(seriesInfo, 'Instances')
                    error('OrthancClient:InvalidResponse', ...
                        'Series metadata for %s does not contain an "Instances" field.', seriesID);
                end
                instances = seriesInfo.Instances;
            catch ME
                warning('Failed to retrieve series metadata for %s: %s', seriesID, ME.message);
                filepath = "";
                failedInstances = {};
                downloadCount = 0;
                return;
            end
            
            % Create output directory
            if options.CreateSubdir
                % Sanitize seriesID to prevent path traversal
                safeSeriesID = regexprep(char(seriesID), '[/\\:.*?"<>|]', '_');
                seriesDir = fullfile(outputDir, safeSeriesID);
            else
                seriesDir = outputDir;
            end
            
            if ~exist(seriesDir, 'dir')
                mkdir(seriesDir);
            end
            
            if obj.Verbose
                fprintf('Downloading %d instances from series %s...\n', ...
                    numel(instances), seriesID);
            end
            
            % Track failed downloads
            failedInstances = cell(numel(instances), 1);
            failureCount = 0;
            downloadCount = 0;
            
            % Download each instance
            for i = 1:numel(instances)
                instanceID = instances{i};
                
                % Determine filename
                if options.Filename == ""
                    filename = sprintf('instance_%04d.dcm', i);
                else
                    filename = sprintf(options.Filename, i);
                end
                
                % Sanitize filename to prevent path traversal
                [~, fname, fext] = fileparts(filename);
                filename = [regexprep(char(fname), '[/\\:.*?"<>|]', '_'), char(fext)];
                
                outputFile = fullfile(seriesDir, filename);
                
                % Download DICOM file
                url = obj.BaseURL + "/instances/" + instanceID + "/file";
                
                try
                    % Use websave for binary file download
                    websave(outputFile, url, obj.WebOptions);
                    downloadCount = downloadCount + 1;
                    
                    if obj.Verbose && mod(i, 10) == 0
                        fprintf('  Downloaded %d/%d instances\n', i, numel(instances));
                    end
                catch ME
                    failureCount = failureCount + 1;
                    failedInstances{failureCount} = instanceID;
                    warning('Failed to download instance %s: %s', instanceID, ME.message);
                end
            end
            
            % Trim pre-allocated array to actual failure count
            failedInstances = failedInstances(1:failureCount);
            
            filepath = seriesDir;
            
            if obj.Verbose
                if isempty(failedInstances)
                    fprintf('Download complete: %s\n', filepath);
                else
                    fprintf('Download complete with %d failures: %s\n', ...
                        numel(failedInstances), filepath);
                end
            end
        end
        
        function archive = downloadSeriesAsZip(obj, seriesID, outputPath)
            %DOWNLOADSERIESASZIP Download series as single ZIP archive
            %
            %   archive = client.downloadSeriesAsZip(seriesID, outputPath)
            %   downloads the series as a ZIP file from Orthanc
            
            arguments
                obj
                seriesID (1,1) string
                outputPath (1,1) string = "series.zip"
            end
            
            url = obj.BaseURL + "/series/" + seriesID + "/archive";
            
            % Sanitize output path — ensure it stays under the intended directory
            [outDir, outName, outExt] = fileparts(outputPath);
            if outDir == ""
                outDir = ".";
            end
            safeOutputPath = fullfile(outDir, ...
                [regexprep(char(outName), '[/\\:.*?"<>|]', '_'), char(outExt)]);
            
            if obj.Verbose
                fprintf('Downloading series %s as ZIP archive...\n', seriesID);
            end
            
            try
                archive = websave(safeOutputPath, url, obj.WebOptions);
                
                if obj.Verbose
                    fprintf('Archive saved: %s\n', archive);
                end
            catch ME
                error('Failed to download series archive %s: %s', seriesID, ME.message);
            end
        end
    end
    
    methods (Access = private)
        function testConnection(obj)
            %TESTCONNECTION Verify connectivity to Orthanc server
            try
                % Reuse getSystemInfo which already prints version when Verbose
                obj.getSystemInfo();
            catch ME
                error('OrthancClient:ConnectionFailed', ...
                    'Failed to connect to Orthanc at %s: %s', ...
                    obj.BaseURL, ME.message);
            end
        end
    end
end
