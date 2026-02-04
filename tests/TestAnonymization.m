classdef TestAnonymization < matlab.unittest.TestCase
    methods(Test)
        function testBasicScrubbing(testCase)
            % 1. Setup: Create a dummy file WITH specific PHI to ensure test validity
            root = fileparts(fileparts(mfilename('fullpath')));
            tempInput = fullfile(root, 'test_data', 'phi_test.dcm');
            
            % Write a file specifically with PatientName = 'Doe'
            dummyImg = uint8(zeros(10, 10));
            dicomwrite(dummyImg, tempInput, 'PatientName', 'Doe');
            
            % 2. Bot Fix: Verify the ORIGINAL file has the PHI
            % This ensures we aren't passing by accident (False Positive prevention)
            origMeta = dicominfo(tempInput);
            testCase.verifyEqual(origMeta.PatientName.FamilyName, 'Doe', ...
                'Test Setup Failed: Input file did not contain expected PHI.');
            
            % 3. Run Scrubbing
            anonFile = dwim.anonymize.scrub(tempInput);
            
            % 4. Verify File Exists
            testCase.verifyTrue(exist(anonFile, 'file') == 2, 'Output file missing.');
            
            % 5. Verify PHI Removal
            newMeta = dicominfo(anonFile);
            
            % Check that the name is NO LONGER 'Doe'
            % (dicomanon usually changes it to 'ANONYMIZED' or removes it)
            if isfield(newMeta, 'PatientName')
                 testCase.verifyFalse(strcmp(newMeta.PatientName.FamilyName, 'Doe'), ...
                    'PatientName was not removed!');
            end
                
            % Cleanup
            delete(tempInput);
            delete(anonFile);
            if exist(fileparts(anonFile), 'dir')
                rmdir(fileparts(anonFile));
            end
        end
    end
end
% Fixed: Added newline at end of file