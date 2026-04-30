classdef TestFlattening < matlab.unittest.TestCase
    % TESTFLATTENING Unit tests for dwim.internal.flattenStruct
    % Path: C:\Users\surya\DWiM\tests\TestFlattening.m

    methods(Test)
        function testNestedFlattening(testCase)
            % 1. Create a mock nested struct (simulating DICOM Sequence)
            raw = struct();
            raw.PatientName = 'John Doe';
            raw.RequestAttributesSequence{1}.RequestedProcedureID = 'PROC-123';
            
            % 2. Run the flattening logic
            flat = dwim.internal.flattenStruct(raw);
            
            % 3. Verify top-level fields
            testCase.verifyTrue(isfield(flat, 'PatientName'));
            testCase.verifyEqual(flat.PatientName, 'John Doe');
            
            % 4. Verify nested field flattening
            expectedKey = 'RequestAttributesSequence_Item1_RequestedProcedureID';
            testCase.verifyTrue(isfield(flat, expectedKey));
            testCase.verifyEqual(flat.(expectedKey), 'PROC-123');
        end
        
        function testEmptyStruct(testCase)
            % Ensure the function doesn't crash on empty input
            emptyS = struct();
            result = dwim.internal.flattenStruct(emptyS);
            testCase.verifyTrue(isempty(fieldnames(result)));
        end
    end
end