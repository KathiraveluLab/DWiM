classdef TestBatchExport < matlab.unittest.TestCase
    % TESTBATCHEXPORT Final verification for Module A.

    methods(Test)
        function testTableGeneration(testCase)
            % 1. Discover test_data relative to this test file
            testFileDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(testFileDir);
            testFolder = fullfile(projectRoot, 'test_data');
            
            % 2. Run batch export
            T = dwim.batchExport(testFolder);
            
            % 3. Verify Table class and row count
            testCase.verifyClass(T, 'table');
            numFiles = numel(dir(fullfile(testFolder, '*.dcm')));
            testCase.verifyEqual(height(T), numFiles, 'Row count mismatch.');

            % 4. Verify flattened header structure
            vars = T.Properties.VariableNames;
            % PatientName is a standard tag that should be present
            testCase.verifyTrue(any(contains(vars, 'PatientName', 'IgnoreCase', true)), ...
                'Missing standard metadata header (PatientName).');
            
            % 5. Logic Verification: Ensure no columns are still structs
            % This proves the flattening logic actually ran.
            for i = 1:width(T)
                testCase.verifyFalse(isstruct(T{:, i}), ...
                    ['Column ', vars{i}, ' was not flattened!']);
            end
        end
    end
end