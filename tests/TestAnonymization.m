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
            
            % 5. Verify PHI Removal (Strict Check)
            newMeta = dicominfo(anonFile);
            if isfield(newMeta, 'PatientName')
                 testCase.verifyEqual(newMeta.PatientName.FamilyName, 'Anonymized', ...
                    'PatientName was not set to the expected default "Anonymized".');
            end
        end
    end
end