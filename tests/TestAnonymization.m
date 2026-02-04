classdef TestAnonymization < matlab.unittest.TestCase
    methods(Test)
        function testBasicScrubbing(testCase)
            % 1. Setup paths
            root = fileparts(fileparts(mfilename('fullpath')));
            inputFile = fullfile(root, 'test_data', 'image01.dcm');
            
            % 2. Run Scrubbing
            % This will create a file like 'image01_anon.dcm'
            anonFile = dwim.anonymize.scrub(inputFile);
            
            % 3. Verify File Exists
            testCase.verifyTrue(exist(anonFile, 'file') == 2, 'Output file missing.');
            
            % 4. Verify Content (The crucial part)
            % Read metadata of the NEW file
            meta = dicominfo(anonFile);
            
            % PatientName should be modified or anonymized by default
            % Note: dicomanon might change it to 'Anonymized' or similar
            testCase.verifyFalse(strcmp(meta.PatientName.FamilyName, 'Doe'), ...
                'PatientName was not removed!');
                
            % Clean up
            delete(anonFile);
            rmdir(fileparts(anonFile));
        end
    end
end