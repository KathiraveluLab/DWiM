classdef TestAnonymization < matlab.unittest.TestCase
    methods(Test)
        function testBasicScrubbing(testCase)
            % 1. Setup: Use a temporary directory for clean testing
            tempDir = tempname;
            mkdir(tempDir);
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
            anonFile = dwim.anonymize.scrub(tempInput);
            
            % 4. Verify File Exists
            testCase.verifyTrue(exist(anonFile, 'file') == 2, 'Output file was not created.');
            
            % 5. Verify PHI Removal (Robust Check)
            newMeta = dicominfo(anonFile);
            
            % If the tag exists, check that it is NOT the original name.
            % (dicomanon often sets it to empty string '', which is valid anonymization)
            if isfield(newMeta, 'PatientName') && isfield(newMeta.PatientName, 'FamilyName')
                 testCase.verifyFalse(strcmp(newMeta.PatientName.FamilyName, 'Doe'), ...
                    'PatientName was not scrubbed! Still matches original.');
            end
        end
    end
end