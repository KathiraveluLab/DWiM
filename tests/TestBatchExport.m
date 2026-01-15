classdef TestBatchExport < matlab.unittest.TestCase
    methods(Test)
        function testTableGeneration(testCase)
            % Skip if toolbox is missing to allow CI to stay green
            testCase.assumeTrue(~isempty(which('dicominfo')), 'Toolbox missing');
            
            testFileDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(testFileDir);
            testFolder = fullfile(projectRoot, 'test_data');
            
            T = dwim.batchExport(testFolder);
            
            testCase.verifyClass(T, 'table');
            % Strict file count check
            numFiles = numel(dir(fullfile(testFolder, '*.dcm')));
            testCase.verifyEqual(height(T), numFiles, 'Row count mismatch');
            
            % Check for nested headers
            vars = T.Properties.VariableNames;
            testCase.verifyTrue(any(contains(vars, 'Item')), 'Flattening failed');
        end
    end
end