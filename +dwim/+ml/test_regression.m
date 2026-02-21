classdef test_regression < matlab.unittest.TestCase
%TEST_REGRESSION Unit tests for RegressionValidator
%
%   Run with: results = runtests('test_regression'); table(results)

    properties
        Validator       % RegressionValidator instance
        BaselineDir     % Temporary baseline directory
    end

    methods (TestMethodSetup)
        function createValidator(testCase)
            testCase.BaselineDir = fullfile(tempdir, ...
                ['dwim_test_' num2str(randi(1e9))]);
            testCase.Validator = dwim.ml.RegressionValidator( ...
                testCase.BaselineDir, 1e-10);
        end
    end

    methods (TestMethodTeardown)
        function removeBaselineDir(testCase)
            if exist(testCase.BaselineDir, 'dir')
                rmdir(testCase.BaselineDir, 's');
            end
        end
    end

    methods (Test)
        function testBaselineCreationAndValidation(testCase)
            % Baseline creation and validation
            testData = rand(64, 64, 'single');
            testCase.Validator.saveBaseline('test_baseline', testData);
            [isValid, report] = testCase.Validator.validate('test_baseline', testData);
            testCase.verifyTrue(isValid, 'Validation should pass for identical data');
            testCase.verifyTrue(report.passed, 'Report should indicate pass');
            testCase.verifyEmpty(report.errors, 'Should have no errors');
        end

        function testDetectValueChanges(testCase)
            % Detect value changes beyond tolerance
            testData = rand(32, 32, 'single');
            testCase.Validator.saveBaseline('test_values', testData);
            modifiedData = testData + 1e-8;
            [isValid, report] = testCase.Validator.validate('test_values', modifiedData);
            testCase.verifyFalse(isValid, 'Validation should fail for modified data');
            testCase.verifyNotEmpty(report.errors, 'Should report errors');
        end

        function testPassWithinTolerance(testCase)
            % Pass with data modified within tolerance
            testData = rand(32, 32, 'single');
            testCase.Validator.saveBaseline('test_tolerance_pass', testData);
            modifiedData = testData + 1e-12;  % 1e-12 < 1e-10 tolerance
            [isValid, report] = testCase.Validator.validate('test_tolerance_pass', modifiedData);
            testCase.verifyTrue(isValid, ...
                'Validation should pass for data modified within tolerance');
            testCase.verifyEmpty(report.errors, ...
                'Should have no errors for changes within tolerance');
        end

        function testDetectSizeChanges(testCase)
            % Detect size changes
            testData = rand(50, 50, 'single');
            testCase.Validator.saveBaseline('test_size', testData);
            wrongSize = rand(60, 60, 'single');
            [isValid, report] = testCase.Validator.validate('test_size', wrongSize);
            testCase.verifyFalse(isValid, 'Validation should fail for size mismatch');
            hasError = any(contains(report.errors, 'Size mismatch'));
            testCase.verifyTrue(hasError, 'Should report size mismatch');
        end

        function testDetectTypeChanges(testCase)
            % Detect type changes
            testData = rand(40, 40, 'single');
            testCase.Validator.saveBaseline('test_type', testData);
            wrongType = double(testData);
            [isValid, report] = testCase.Validator.validate('test_type', wrongType);
            testCase.verifyFalse(isValid, 'Validation should fail for type mismatch');
            hasError = any(contains(report.errors, 'Type mismatch'));
            testCase.verifyTrue(hasError, 'Should report type mismatch');
        end

        function testHashConsistency(testCase)
            % Hash consistency
            testData = rand(30, 30, 'single');
            testCase.Validator.saveBaseline('test_hash', testData);
            [isValid, report] = testCase.Validator.validate('test_hash', testData);
            testCase.verifyTrue(isValid, 'Validation should pass');
            testCase.verifyEqual(report.baselineHash, report.currentHash, ...
                'Hashes should match');
        end

        function testMissingBaselineHandling(testCase)
            % Missing baseline handling
            testData = rand(20, 20, 'single');
            [isValid, report] = testCase.Validator.validate('nonexistent_baseline', testData);
            testCase.verifyFalse(isValid, 'Validation should fail for missing baseline');
            hasError = any(contains(report.errors, 'Baseline not found'));
            testCase.verifyTrue(hasError, 'Should report missing baseline');
        end

        function testListBaselines(testCase)
            % List baselines
            testCase.Validator.saveBaseline('baseline1', rand(10, 10));
            testCase.Validator.saveBaseline('baseline2', rand(20, 20));
            baselines = testCase.Validator.listBaselines();
            testCase.verifyClass(baselines, 'cell', 'Should return cell array');
            testCase.verifyGreaterThanOrEqual(numel(baselines), 2, ...
                'Should list saved baselines');
        end
    end
end
