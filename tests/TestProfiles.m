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
            
            % Robust Name Check (handles struct vs string return)
            pName = meta.PatientName;
            if isstruct(pName)
                 if isfield(pName, 'FamilyName')
                     pName = pName.FamilyName;
                 else
                     vals = struct2cell(pName);
                     pName = vals{1};
                 end
            end
            
            testCase.verifyEqual(pName, 'RESEARCH_SUB', ...
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
            
            % Check 1: Age should be GONE (Empty)
            if isfield(meta, 'PatientAge')
                testCase.verifyTrue(isempty(meta.PatientAge), ...
                    'Strict profile failed to remove PatientAge');
            end
            
            % Check 2: Name should be explicitly 'ANONYMIZED'
            % Handling standard DICOM structure for Name
            pName = meta.PatientName;
            if isstruct(pName) && isfield(pName, 'FamilyName')
                pName = pName.FamilyName;
            elseif isstruct(pName)
                 vals = struct2cell(pName);
                 pName = vals{1};
            end
            
            testCase.verifyEqual(pName, 'ANONYMIZED', ...
                'Strict profile failed to anonymize PatientName to default value');
        end
    end
end