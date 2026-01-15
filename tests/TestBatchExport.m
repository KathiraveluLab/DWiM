classdef TestBatchExport < matlab.unittest.TestCase
    methods(Test)
        function testTableGeneration(testCase)
            testFileDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(testFileDir);
            testFolder = fullfile(projectRoot, 'test_data');
            
            T = dwim.batchExport(testFolder);
            
            % Strict verification of row count
            numFiles = numel(dir(fullfile(testFolder, '*.dcm')));
            testCase.verifyEqual(height(T), numFiles, 'Row count mismatch.');

            % Comprehensive header validation
            vars = T.Properties.VariableNames;
            testCase.verifyTrue(any(strcmp(vars, 'PatientName')), 'Missing PatientName.');
            testCase.verifyTrue(any(contains(vars, 'Sequence_Item')), 'Missing nested tags.');
        end
    end
end