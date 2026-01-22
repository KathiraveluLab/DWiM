classdef TestPixelData < matlab.unittest.TestCase
    methods(Test)
        function testPixelExtraction(testCase)
            % Discover test data
            testFileDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(testFileDir);
            testFile = fullfile(projectRoot, 'test_data', 'image01.dcm');
            
            % Run extraction
            img = dwim.readPixels(testFile);
            
            % Verify it is a numeric matrix
            testCase.verifyTrue(isnumeric(img), 'Pixel data should be numeric.');
            testCase.verifyEqual(ndims(img), 2, 'Should be a 2D image.');
        end
    end
end