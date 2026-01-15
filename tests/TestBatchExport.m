classdef TestBatchExport < matlab.unittest.TestCase
    methods(Test)
        function testTableGeneration(testCase)
            % Use the test_data folder you've been using in CI
            testFolder = fullfile(pwd, 'test_data');
            
            % Run the batch export
            T = dwim.batchExport(testFolder);
            
            % Verify Table properties
            testCase.verifyClass(T, 'table');
            testCase.verifyGreaterThanOrEqual(height(T), 1);
            
            % Verify that flattening worked (Check for a common tag)
            testCase.verifyTrue(any(contains(T.Properties.VariableNames, 'PatientName')));
        end
    end
end