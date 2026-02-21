classdef TestPixelData < matlab.unittest.TestCase
    methods(Test)
        function testPixelExtraction(testCase)
            % 1. Setup: Create a temporary dummy DICOM file
            tempDir = tempname;
            mkdir(tempDir);
            
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            
            tempDicomPath = fullfile(tempDir, 'dummy_test_image.dcm');
            
            % Create a fake 10x10 image
            dummyImg = uint8(zeros(10, 10));
            dicomwrite(dummyImg, tempDicomPath);
            
            % 2. Run pixel extraction
            img = dwim.readPixels(tempDicomPath);
            
            % 3. Standard structural assertions
            testCase.verifyTrue(isnumeric(img), 'Pixel data should be numeric.');
            testCase.verifyEqual(ndims(img), 2, 'Should be a 2D image.');
            
            % 4. Robust value verification
            % Since our image is a dummy 10x10 uint8(zeros), 
            % we verify the intensity range after scaling.
            testCase.verifyGreaterThanOrEqual(min(img(:)), -2000, 'Intensity below expected medical range.');
            testCase.verifyLessThanOrEqual(max(img(:)), 4000, 'Intensity above expected medical range.');
        end
    end
end