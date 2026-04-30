classdef TestUidRemapping < matlab.unittest.TestCase
    methods(Test)
        function testConsistentRemapping(testCase)
            % 1. Setup: Create temporary files
            tempDir = tempname; mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            
            file1 = fullfile(tempDir, 'patA_slice1.dcm');
            file2 = fullfile(tempDir, 'patA_slice2.dcm');
            file3 = fullfile(tempDir, 'patB_slice1.dcm');
            
            % Write Dummy Data: Two files for PAT_123, one for PAT_999
            img = uint8(zeros(10));
            dicomwrite(img, file1, 'PatientID', 'PAT_123');
            dicomwrite(img, file2, 'PatientID', 'PAT_123');
            dicomwrite(img, file3, 'PatientID', 'PAT_999');
            
            % 2. Create the Memory Bank (Mapper)
            mapper = dwim.anonymize.UidMapper();
            
            % 3. Scrub all three files using the SAME mapper
            out1 = dwim.anonymize.scrub(file1, tempDir, 'research', mapper);
            out2 = dwim.anonymize.scrub(file2, tempDir, 'research', mapper);
            out3 = dwim.anonymize.scrub(file3, tempDir, 'research', mapper);
            
            % 4. Read the new metadata
            m1 = dicominfo(out1);
            m2 = dicominfo(out2);
            m3 = dicominfo(out3);
            
            % 5. Verify: Slices from same patient MUST have same new ID
            testCase.verifyEqual(m1.PatientID, m2.PatientID, ...
                'Mapper failed! Slices from the same patient got different IDs.');
                
            % 6. Verify: Slices from different patients MUST NOT collide
            testCase.verifyNotEqual(m1.PatientID, m3.PatientID, ...
                'Mapper failed! Different patients were merged into the same ID.');
        end
    end
end