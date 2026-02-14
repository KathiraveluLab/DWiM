function test_validationGuards()
%TEST_VALIDATIONGUARDS Test validation and failure handling
    
    fprintf('Testing Validation Guards\n');
    fprintf('========================\n');
    
    % Test 1: Empty folder guard
    fprintf('Test 1: Empty folder detection... ');
    try
        tempDir = fullfile(tempdir, 'dwim_test_empty');
        if ~exist(tempDir, 'dir')
            mkdir(tempDir);
        end
        cleanup1 = onCleanup(@() rmdir(tempDir, 's'));
        
        result = dwim.ml.validatePreprocessingInput(tempDir, 'Verbose', false);
        
        assert(~result.valid, 'Should fail for empty folder');
        assert(strcmp(result.errors{1}.identifier, 'DWiM:Validation:EmptyFolder'), ...
               'Should have EmptyFolder error');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 2: Invalid path guard
    fprintf('Test 2: Invalid path detection... ');
    try
        result = dwim.ml.validatePreprocessingInput('nonexistent_path', 'Verbose', false);
        
        assert(~result.valid, 'Should fail for invalid path');
        assert(strcmp(result.errors{1}.identifier, 'DWiM:Validation:InvalidPath'), ...
               'Should have InvalidPath error');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 3: Structured error identifiers
    fprintf('Test 3: Structured error identifiers... ');
    try
        result = dwim.ml.validatePreprocessingInput('invalid', 'Verbose', false);
        
        assert(isfield(result.errors{1}, 'identifier'), 'Error should have identifier');
        assert(isfield(result.errors{1}, 'message'), 'Error should have message');
        assert(startsWith(result.errors{1}.identifier, 'DWiM:Validation:'), ...
               'Identifier should follow DWiM:Validation: pattern');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 4: Metadata validation with mock DICOM
    fprintf('Test 4: Metadata validation... ');
    try
        tempDir = fullfile(tempdir, 'dwim_test_metadata');
        if ~exist(tempDir, 'dir')
            mkdir(tempDir);
        end
        cleanup2 = onCleanup(@() rmdir(tempDir, 's'));
        
        % Create a minimal mock DICOM file
        mockFile = fullfile(tempDir, 'test.dcm');
        fid = fopen(mockFile, 'w');
        fwrite(fid, zeros(1, 132), 'uint8');
        fwrite(fid, 'DICM', 'char');
        fclose(fid);
        
        result = dwim.ml.validatePreprocessingInput(tempDir, 'Verbose', false);
        
        % Should fail validation due to missing metadata or read errors
        assert(~result.valid, ...
               'Should fail validation for files with missing/unreadable metadata');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 5: Spacing validation with insufficient slices
    fprintf('Test 5: Spacing validation with insufficient slices... ');
    try
        tempDir = fullfile(tempdir, 'dwim_test_spacing');
        if ~exist(tempDir, 'dir')
            mkdir(tempDir);
        end
        cleanup3 = onCleanup(@() rmdir(tempDir, 's'));
        
        % Create a single mock DICOM file
        mockFile = fullfile(tempDir, 'slice1.dcm');
        fid = fopen(mockFile, 'w');
        fwrite(fid, zeros(1, 132), 'uint8');
        fwrite(fid, 'DICM', 'char');
        fclose(fid);
        
        result = dwim.ml.validatePreprocessingInput(tempDir, 'Verbose', false, 'CheckMetadata', false);
        
        % Should warn about insufficient slices
        hasSpacingWarning = any(contains(result.warnings, 'Insufficient'));
        assert(hasSpacingWarning, 'Should warn about insufficient slices');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    fprintf('========================\n');
    fprintf('Validation guard testing completed\n');
end
