% test_moduleB_basics.m
% Simple script to verify Week 9 Pixel Extraction

% 1. Find the test data relative to this script
root = fileparts(mfilename('fullpath'));
testFile = fullfile(root, 'test_data', 'image01.dcm');

% 2. Extract Pixels using your new function
try
    fprintf('Reading pixels from: %s\n', testFile);
    pixels = dwim.readPixels(testFile);
    
    % 3. Display stats for verification
    fprintf('Image Dimensions: %d x %d\n', size(pixels, 1), size(pixels, 2));
    fprintf('Intensity Range: [%.2f, %.2f]\n', min(pixels(:)), max(pixels(:)));
    
    % 4. Launch the Viewer
    dwim.viewImage(pixels, "Week 9: " + testFile);
    
catch ME
    fprintf('Error during testing: %s\n', ME.message);
end