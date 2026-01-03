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
            raw = struct();
            raw.PatientName = '  Anonymous  ';
            % Test standard Private prefix
            raw.Private_0019_1001 = 'Secret';
            % Test odd group number format
            raw.Group0011_Element1001 = 'Hidden';
            
            clean = dwim.internal.sanitizeMetadata(raw);
            
            testCase.verifyEqual(clean.PatientName, 'Anonymous');
            testCase.verifyFalse(isfield(clean, 'Private_0019_1001'));
            testCase.verifyFalse(isfield(clean, 'Group0011_Element1001'));
        end
    end
end