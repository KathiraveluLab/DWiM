function test_regression()
%TEST_REGRESSION Regression tests for ML preprocessing pipeline
%
%   Validates that preprocessing outputs match known baselines

    fprintf('Testing Regression Validation\n');
    fprintf('=============================\n');
    
    % Initialize validator
    baselineDir = fullfile(tempdir, 'dwim_regression_baselines');
    validator = dwim.ml.RegressionValidator(baselineDir, 1e-10);
    cleanup = onCleanup(@() rmdir(baselineDir, 's'));
    
    % Test 1: Baseline creation and validation
    fprintf('Test 1: Baseline creation and validation... ');
    try
        testData = rand(64, 64, 'single');
        
        % Save baseline
        validator.saveBaseline('test_baseline', testData);
        
        % Validate against same data
        [isValid, report] = validator.validate('test_baseline', testData);
        assert(isValid, 'Validation should pass for identical data');
        assert(report.passed, 'Report should indicate pass');
        assert(isempty(report.errors), 'Should have no errors');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 2: Detect value changes
    fprintf('Test 2: Detect value changes... ');
    try
        testData = rand(32, 32, 'single');
        validator.saveBaseline('test_values', testData);
        
        % Modify data slightly
        modifiedData = testData + 1e-8;
        [isValid, report] = validator.validate('test_values', modifiedData);
        
        assert(~isValid, 'Validation should fail for modified data');
        assert(~isempty(report.errors), 'Should report errors');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 3: Detect size changes
    fprintf('Test 3: Detect size changes... ');
    try
        testData = rand(50, 50, 'single');
        validator.saveBaseline('test_size', testData);
        
        % Different size
        wrongSize = rand(60, 60, 'single');
        [isValid, report] = validator.validate('test_size', wrongSize);
        
        assert(~isValid, 'Validation should fail for size mismatch');
        hasError = any(contains(report.errors, 'Size mismatch'));
        assert(hasError, 'Should report size mismatch');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 4: Detect type changes
    fprintf('Test 4: Detect type changes... ');
    try
        testData = rand(40, 40, 'single');
        validator.saveBaseline('test_type', testData);
        
        % Different type
        wrongType = double(testData);
        [isValid, report] = validator.validate('test_type', wrongType);
        
        assert(~isValid, 'Validation should fail for type mismatch');
        hasError = any(contains(report.errors, 'Type mismatch'));
        assert(hasError, 'Should report type mismatch');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 5: Hash consistency
    fprintf('Test 5: Hash consistency... ');
    try
        testData = rand(30, 30, 'single');
        validator.saveBaseline('test_hash', testData);
        
        [isValid, report] = validator.validate('test_hash', testData);
        
        assert(isValid, 'Validation should pass');
        assert(strcmp(report.baselineHash, report.currentHash), 'Hashes should match');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 6: Missing baseline handling
    fprintf('Test 6: Missing baseline handling... ');
    try
        testData = rand(20, 20, 'single');
        [isValid, report] = validator.validate('nonexistent_baseline', testData);
        
        assert(~isValid, 'Validation should fail for missing baseline');
        hasError = any(contains(report.errors, 'Baseline not found'));
        assert(hasError, 'Should report missing baseline');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 7: List baselines
    fprintf('Test 7: List baselines... ');
    try
        validator.saveBaseline('baseline1', rand(10, 10));
        validator.saveBaseline('baseline2', rand(20, 20));
        
        baselines = validator.listBaselines();
        
        assert(iscell(baselines), 'Should return cell array');
        assert(length(baselines) >= 2, 'Should list saved baselines');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    fprintf('=============================\n');
    fprintf('Regression testing completed\n');
end
