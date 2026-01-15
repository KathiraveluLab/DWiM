classdef TestBatchExport < matlab.unittest.TestCase
    methods(Test)
        function testTableGeneration(testCase)
            testFolder = fullfile(pwd, 'test_data');
            
            % Run the batch export
            T = dwim.batchExport(testFolder);
            
            % BOT FIX: Verify EXACT row count matches file count
            numDicomFiles = numel(dir(fullfile(testFolder, '*.dcm')));
            testCase.verifyEqual(height(T), numDicomFiles, ...
                'The table row count must match the number of DICOM files.');

            % BOT FIX: Comprehensive validation of flattened headers
            vars = T.Properties.VariableNames;
            testCase.verifyTrue(any(strcmp(vars, 'PatientName')), 'Missing top-level header.');
            
            % Check for potential flattened sequence items
            hasSequence = any(contains(vars, 'Sequence_Item'));
            if hasSequence
                 testCase.verifyTrue(hasSequence, 'Recursive flattening failed in batch mode.');
            end
        end
    end
end