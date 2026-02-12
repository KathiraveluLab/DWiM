classdef TestProfiles < matlab.unittest.TestCase
    methods(Test)
        function testResearchProfilePreservation(testCase)
            % 1. Setup
            tempDir = tempname; mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            
            tempInput = fullfile(tempDir, 'research_test.dcm');
            
            % Create dummy file with sensitive AND research data
            dummyImg = uint8(zeros(10, 10));
            dicomwrite(dummyImg, tempInput, ...
                'PatientName', 'Doe^John', ...
                'PatientAge', '025Y', ...   % Research needs this
                'PatientSex', 'M');         % Research needs this
            
            % 2. Run 'research' profile
            anonFile = dwim.anonymize.scrub(tempInput, tempDir, 'research');
            
            % 3. Verify
            meta = dicominfo(anonFile);
            
            % Name should be scrubbed (replaced with profile default)
            testCase.verifyEqual(meta.PatientName.FamilyName, 'RESEARCH_SUB', ...
                'Research profile failed to hide PatientName');
                
            % Age/Sex should be PRESERVED
            testCase.verifyEqual(meta.PatientAge, '025Y', ...
                'Research profile incorrectly removed PatientAge');
            testCase.verifyEqual(meta.PatientSex, 'M', ...
                'Research profile incorrectly removed PatientSex');
        end

        function testStrictProfileDestruction(testCase)
            % 1. Setup
            tempDir = tempname; mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            tempInput = fullfile(tempDir, 'strict_test.dcm');
            
            dicomwrite(uint8(zeros(10,10)), tempInput, ...
                'PatientAge', '025Y', 'PatientName', 'Doe');
            
            % 2. Run 'strict' profile
            anonFile = dwim.anonymize.scrub(tempInput, tempDir, 'strict');
            
            % 3. Verify
            meta = dicominfo(anonFile);
            
            % Age should be GONE (Empty)
            testCase.verifyTrue(isempty(meta.PatientAge), ...
                'Strict profile failed to remove PatientAge');
        end
    end
end