classdef TestBatchExport < matlab.unittest.TestCase
    % TESTBATCHEXPORT Final verification for Module A.

    methods(Test)
        function testTableGeneration(testCase)
            % Discover test_data relative to this test file
            testFileDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(testFileDir);
            testFolder = fullfile(projectRoot, 'test_data');
            
            % Ensure folder exists before proceeding
            testCase.assumeTrue(exist(testFolder, 'dir') == 7, ...
                ['Folder missing at: ', char(testFolder)]);

            % Run batch export
            T = dwim.batchExport(testFolder);
            
            % BOT FIX: Strict row count validation
            expectedCount = numel(dir(fullfile(testFolder, '*.dcm')));
            testCase.verifyEqual(height(T), expectedCount, ...
                'Table height must match number of DICOM files.');

            % BOT FIX: Validate flattened header structure
            vars = T.Properties.VariableNames;
            testCase.verifyTrue(any(strcmp(vars, 'PatientName')), 'Missing PatientName.');
            
            % Verify recursive flattening occurred
            testCase.verifyTrue(any(contains(vars, 'Item')), ...
                'Recursive flattening failed to produce Item-level columns.');
        end
    end
end