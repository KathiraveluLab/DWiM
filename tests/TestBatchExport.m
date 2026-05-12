classdef TestBatchExport < matlab.unittest.TestCase
    % TESTBATCHEXPORT Final verification for Module A.
    methods(Test)
        function testTableGeneration(testCase)
            % 1. Setup: Create a temporary directory with dummy DICOMs
            tempDir = tempname;
            mkdir(tempDir);
           
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            
            % Create 2 dummy files to test the batch logic
            img = uint8(zeros(10, 10));
            dicomwrite(img, fullfile(tempDir, 'dummy1.dcm'), 'PatientName', 'Test^One');
            dicomwrite(img, fullfile(tempDir, 'dummy2.dcm'), 'PatientName', 'Test^Two');
            
            % 2. Run batch export on the temporary folder
            T = dwim.batchExport(tempDir);
            
            % 3. Verify Table class and row count
            testCase.verifyClass(T, 'table');
            testCase.verifyEqual(height(T), 2, 'Row count mismatch. Expected 2 dummy files.');
            
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