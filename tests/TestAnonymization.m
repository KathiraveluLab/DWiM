classdef TestAnonymization < matlab.unittest.TestCase
    methods(Test)
        function testBasicScrubbing(testCase)
            % 1. Setup: Create a dummy file WITH specific PHI
            root = fileparts(fileparts(mfilename('fullpath')));
            
            % Ensure 'test_data' folder exists before writing to it
            testDataDir = fullfile(root, 'test_data');
            if ~exist(testDataDir, 'dir')
                mkdir(testDataDir);
            end
            
            tempInput = fullfile(testDataDir, 'phi_test.dcm');
            
            % Write a file specifically with PatientName = 'Doe'
            dummyImg = uint8(zeros(10, 10));
            dicomwrite(dummyImg, tempInput, 'PatientName', 'Doe');
            
            % 2. Verify the ORIGINAL file has the PHI (False Positive Prevention)
            origMeta = dicominfo(tempInput);
            testCase.verifyEqual(origMeta.PatientName.FamilyName, 'Doe', ...
                'Test Setup Failed: Input file did not contain expected PHI.');
            
            % 3. Run Scrubbing
            anonFile = dwim.anonymize.scrub(tempInput);
            
            % 4. Verify File Exists
            testCase.verifyTrue(exist(anonFile, 'file') == 2, 'Output file missing.');
            
            % 5. Verify PHI Removal
            newMeta = dicominfo(anonFile);
            if isfield(newMeta, 'PatientName')
                 testCase.verifyFalse(strcmp(newMeta.PatientName.FamilyName, 'Doe'), ...
                    'PatientName was not removed!');
            end
                
            % Cleanup
            delete(tempInput);
            delete(anonFile);
            % only remove dir if it's empty to avoid messing up other tests
            if exist(fileparts(anonFile), 'dir')
                rmdir(fileparts(anonFile));
            end
        end
    end
end