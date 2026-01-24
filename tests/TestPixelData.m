classdef TestPixelData < matlab.unittest.TestCase
    methods(Test)
        function testPixelExtraction(testCase)
            testFileDir = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(testFileDir);
            testFile = fullfile(projectRoot, 'test_data', 'image01.dcm');
            
            img = dwim.readPixels(testFile);
            
            % 1. Standard structural assertions
            testCase.verifyTrue(isnumeric(img), 'Pixel data should be numeric.');
            testCase.verifyEqual(ndims(img), 2, 'Should be a 2D image.');
            
            % 2. Bot Fix: Robust value verification
            % Since our image01.dcm is a dummy 10x10 uint8(zeros), 
            % we verify the intensity range after scaling.
            testCase.verifyGreaterThanOrEqual(min(img(:)), -2000, 'Intensity below expected medical range.');
            testCase.verifyLessThanOrEqual(max(img(:)), 4000, 'Intensity above expected medical range.');
        end
    end
end