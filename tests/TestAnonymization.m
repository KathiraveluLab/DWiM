classdef TestAnonymization < matlab.unittest.TestCase
    methods(Test)
        function testBasicScrubbing(testCase)
            % 1. Setup: Use a temporary directory to avoid polluting the source tree
            tempDir = tempname;
            mkdir(tempDir);
            
            % Ensure cleanup happens even if the test fails
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            
            tempInput = fullfile(tempDir, 'phi_test.dcm');
            
            % Write a file specifically with PatientName = 'Doe'
            dummyImg = uint8(zeros(10, 10));
            dicomwrite(dummyImg, tempInput, 'PatientName', 'Doe');
            
            % 2. Verify the ORIGINAL file has the PHI
            origMeta = dicominfo(tempInput);
            testCase.verifyEqual(origMeta.PatientName.FamilyName, 'Doe', ...
                'Test Setup Failed: Input file did not contain expected PHI.');
            
            % 3. Run Scrubbing
            % The function will create an 'anonymized' subdirectory inside tempDir
            anonFile = dwim.anonymize.scrub(tempInput);
            
            % 4. Verify File Exists
            testCase.verifyTrue(exist(anonFile, 'file') == 2, 'Output file was not created.');
            
            % 5. Verify PHI Removal
            newMeta = dicominfo(anonFile);
            if isfield(newMeta, 'PatientName')
                 testCase.verifyFalse(strcmp(newMeta.PatientName.FamilyName, 'Doe'), ...
                    'PatientName was not scrubbed!');
            end
        end
    end
end