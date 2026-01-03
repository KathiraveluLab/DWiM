classdef TestFaultTolerance < matlab.unittest.TestCase
    % TESTFAULTTOLERANCE Tests for safe reading and metadata cleaning.

    methods(Test)
        function testCorruptFilePath(testCase)
            % Test reading a non-existent file
            [~, status] = dwim.internal.readDicomSafe("non_existent_file.dcm");
            testCase.verifyFalse(status.success);
            testCase.verifyTrue(contains(status.message, "not found", 'IgnoreCase', true));
        end

        function testPrivateTagSanitization(testCase)
            % Create a struct with a standard tag and a private tag
            raw = struct();
            raw.PatientName = '  Anonymous  '; % Added spaces to test trimming
            raw.Private_0019_1001 = 'Secret Data';
            
            clean = dwim.internal.sanitizeMetadata(raw);
            
            % Verify standard tag is kept and trimmed
            testCase.verifyTrue(isfield(clean, 'PatientName'));
            testCase.verifyEqual(clean.PatientName, 'Anonymous');
            
            % Verify private tag is removed
            testCase.verifyFalse(isfield(clean, 'Private_0019_1001'), ...
                'Private tag was not stripped!');
        end
    end
end