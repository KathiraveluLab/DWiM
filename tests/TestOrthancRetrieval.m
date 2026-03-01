classdef TestOrthancRetrieval < matlab.unittest.TestCase
    %TESTORTHANCRETRIEVAL Test suite for Orthanc retrieval module
    %
    % Note: These tests require a running Orthanc server with test data.
    % Set SKIP_ORTHANC_TESTS=1 environment variable to skip these tests.
    
    properties (TestParameter)
        testModality = {'CT', 'MR'}
    end
    
    properties
        Client
        SkipTests
    end
    
    methods (TestClassSetup)
        function checkOrthancAvailability(tc)
            % Check if tests should be skipped
            skipEnv = getenv('SKIP_ORTHANC_TESTS');
            tc.SkipTests = ~isempty(skipEnv) && str2double(skipEnv) == 1;
            
            if tc.SkipTests
                fprintf('Skipping Orthanc tests (SKIP_ORTHANC_TESTS=1)\n');
                return;
            end
            
            % Try to create client
            try
                tc.Client = dwim.retrieval.OrthancClient('Verbose', false);
                info = tc.Client.getSystemInfo();
                fprintf('Connected to Orthanc v%s\n', info.Version);
            catch ME
                tc.SkipTests = true;
                warning('Orthanc not available, skipping tests: %s', ME.message);
            end
        end
    end
    
    methods
        function skipIfNoOrthanc(tc)
            if tc.SkipTests
                tc.assumeFalse(tc.SkipTests, 'Orthanc not available - test skipped');
            end
        end
    end
    
    methods (Test)
        function testClientCreation(tc)
            tc.skipIfNoOrthanc();
            
            % Test client can be created
            client = dwim.retrieval.OrthancClient('Verbose', false);
            tc.verifyClass(client, 'dwim.retrieval.OrthancClient');
        end
        
        function testGetSystemInfo(tc)
            tc.skipIfNoOrthanc();
            
            % Test system info retrieval
            info = tc.Client.getSystemInfo();
            tc.verifyTrue(isfield(info, 'Version'));
            tc.verifyTrue(isfield(info, 'Name'));
        end
        
        function testListStudies(tc)
            tc.skipIfNoOrthanc();
            
            % Test study list retrieval
            studies = tc.Client.listStudies();
            tc.verifyClass(studies, 'cell');
        end
        
        function testListPatients(tc)
            tc.skipIfNoOrthanc();
            
            % Test patient list retrieval
            patients = tc.Client.listPatients();
            tc.verifyClass(patients, 'cell');
        end
        
        function testListSeries(tc)
            tc.skipIfNoOrthanc();
            
            % Test series list retrieval
            series = tc.Client.listSeries();
            tc.verifyClass(series, 'cell');
        end
        
        function testGetStudyMetadata(tc)
            tc.skipIfNoOrthanc();
            
            % Get first study
            studies = tc.Client.listStudies();
            if isempty(studies)
                tc.verifyFail('No studies available for testing');
            end
            
            % Test metadata retrieval
            metadata = tc.Client.getStudy(studies{1});
            tc.verifyTrue(isstruct(metadata));
            tc.verifyTrue(isfield(metadata, 'ID'));
        end
        
        function testQueryOrthancBasic(tc)
            tc.skipIfNoOrthanc();
            
            % Test basic query
            query = struct();
            results = dwim.retrieval.queryOrthanc(query, 'Verbose', false);
            
            tc.verifyClass(results, 'table');
        end
        
        function testQueryOrthancWithModality(tc, testModality)
            tc.skipIfNoOrthanc();
            
            % Test modality filter
            query = struct();
            query.Modality = testModality;
            results = dwim.retrieval.queryOrthanc(query, 'Verbose', false);
            
            tc.verifyClass(results, 'table');
            
            % Verify modality filter worked (if results exist)
            if height(results) > 0
                % Check first result has correct modality
                tc.verifyEqual(results.Modality{1}, testModality);
            end
        end
        
        function testQueryOrthancWithLimit(tc)
            tc.skipIfNoOrthanc();
            
            % Test limit parameter
            query = struct();
            query.Limit = 5;
            results = dwim.retrieval.queryOrthanc(query, 'Verbose', false);
            
            tc.verifyLessThanOrEqual(height(results), 5);
        end
        
        function testDownloadSeries(tc)
            tc.skipIfNoOrthanc();
            
            % Get first series
            seriesList = tc.Client.listSeries();
            if isempty(seriesList)
                tc.verifyFail('No series available for testing');
            end
            
            % Create a temporary folder fixture for automatic cleanup
            tempFolderFixture = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            
            % Test download
            seriesPath = tc.Client.downloadSeries(seriesList{1}, tempFolderFixture.Folder, ...
                'CreateSubdir', false);
            
            tc.verifyTrue(exist(seriesPath, 'dir') == 7);
            
            % Verify files were downloaded
            files = dir(fullfile(seriesPath, '*.dcm'));
            tc.verifyGreaterThan(numel(files), 0);
        end
        
        function testRetrieveBatchSmall(tc)
            tc.skipIfNoOrthanc();
            
            % Create a temporary folder fixture for automatic cleanup
            tempFolderFixture = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            
            % Test batch retrieval with limit
            query = struct();
            
            summary = dwim.retrieval.retrieveBatch(query, tempFolderFixture.Folder, ...
                'MaxStudies', 2, ...
                'Parallel', false, ...
                'Verbose', false);
            
            % Verify summary structure
            tc.verifyTrue(isstruct(summary));
            tc.verifyTrue(isfield(summary, 'studiesDownloaded'));
            
            % Function should handle zero studies gracefully
            tc.verifyGreaterThanOrEqual(summary.studiesDownloaded, 0);
            tc.verifyLessThanOrEqual(summary.studiesDownloaded, 2);
            
            % If studies were downloaded, verify paths exist
            if summary.studiesDownloaded > 0
                tc.verifyTrue(isfield(summary, 'studyPaths'));
                tc.verifyGreaterThan(numel(summary.studyPaths), 0);
            end
        end
        
        function testErrorHandlingInvalidStudyID(tc)
            tc.skipIfNoOrthanc();
            
            % Test error handling for invalid study ID
            tc.verifyError(@() tc.Client.getStudy("invalid_id_xyz"), 'MATLAB:webservices:HTTP404StatusCodeError');
        end
        
        function testErrorHandlingInvalidSeriesID(tc)
            tc.skipIfNoOrthanc();
            
            % Test error handling for invalid series ID
            tc.verifyError(@() tc.Client.getSeries("invalid_series_xyz"), 'MATLAB:webservices:HTTP404StatusCodeError');
        end
    end
end
