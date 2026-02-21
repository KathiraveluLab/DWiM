classdef RegressionValidator < handle
%REGRESSIONVALIDATOR Validate ML pipeline outputs against baselines
%
%   Provides utilities for storing and comparing baseline outputs to detect
%   regressions in preprocessing pipeline behavior.
%
%   Example:
%       validator = dwim.ml.RegressionValidator('baselines/');
%       validator.saveBaseline('test1', outputData);
%       isValid = validator.validate('test1', newOutputData);

    properties
        BaselineDir     % Directory for storing baseline files
        Tolerance       % Numerical tolerance for comparisons
    end
    
    methods
        function obj = RegressionValidator(baselineDir, tolerance)
            %REGRESSIONVALIDATOR Construct validator
            %   validator = RegressionValidator(baselineDir)
            %   validator = RegressionValidator(baselineDir, tolerance)
            arguments
                baselineDir (1,1) string = fullfile(pwd, 'baselines')
                tolerance (1,1) double {mustBeNonnegative} = 1e-10
            end
            
            obj.BaselineDir = baselineDir;
            obj.Tolerance = tolerance;
            
            if ~exist(obj.BaselineDir, 'dir')
                mkdir(obj.BaselineDir);
            end
        end
        
        function saveBaseline(obj, testName, data, metadata)
            %SAVEBASELINE Save baseline output for test
            %   saveBaseline(testName, data)
            %   saveBaseline(testName, data, metadata)
            
            if nargin < 4
                metadata = struct();
            end
            
            baseline = struct();
            baseline.data = data;
            baseline.metadata = metadata;
            baseline.timestamp = datetime('now');
            baseline.hash = obj.computeHash(data);
            
            filepath = obj.getBaselinePath(testName);
            save(filepath, 'baseline', '-v7.3');
        end
        
        function [isValid, report] = validate(obj, testName, data)
            %VALIDATE Compare data against baseline
            %   isValid = validate(testName, data)
            %   [isValid, report] = validate(testName, data)
            
            report = struct();
            report.testName = testName;
            report.passed = false;
            report.errors = {};
            
            filepath = obj.getBaselinePath(testName);
            if ~exist(filepath, 'file')
                report.errors{end+1} = sprintf('Baseline not found: %s', testName);
                isValid = false;
                return;
            end
            
            loaded = load(filepath, 'baseline');
            baseline = loaded.baseline;
            
            % Check data type
            if ~strcmp(class(data), class(baseline.data))
                report.errors{end+1} = sprintf('Type mismatch: expected %s, got %s', ...
                    class(baseline.data), class(data));
            end
            
            % Check size
            if ~isequal(size(data), size(baseline.data))
                report.errors{end+1} = sprintf('Size mismatch: expected %s, got %s', ...
                    mat2str(size(baseline.data)), mat2str(size(data)));
            end
            
            % Check values (only for numeric data)
            if isequal(size(data), size(baseline.data)) && isnumeric(data) && isnumeric(baseline.data)
                maxDiff = max(abs(data(:) - baseline.data(:)));
                report.maxDifference = maxDiff;
                
                if maxDiff > obj.Tolerance
                    report.errors{end+1} = sprintf('Value difference %.2e exceeds tolerance %.2e', ...
                        maxDiff, obj.Tolerance);
                end
            end
            
            % Check hash (only report mismatch if values are out of tolerance)
            currentHash = obj.computeHash(data);
            report.baselineHash = baseline.hash;
            report.currentHash = currentHash;
            
            if ~strcmp(currentHash, baseline.hash) && ~isnumeric(data) && isempty(report.errors)
                % For non-numeric data where value comparison is not performed,
                % a hash mismatch is a primary indicator of change.
                report.errors{end+1} = 'Hash mismatch detected for non-numeric data';
            end
            
            report.passed = isempty(report.errors);
            isValid = report.passed;
        end
        
        function deleteBaseline(obj, testName)
            %DELETEBASELINE Remove baseline file
            filepath = obj.getBaselinePath(testName);
            if exist(filepath, 'file')
                delete(filepath);
            end
        end
        
        function baselines = listBaselines(obj)
            %LISTBASELINES List all available baselines
            files = dir(fullfile(obj.BaselineDir, '*.mat'));
            if isempty(files)
                baselines = {};
                return;
            end
            [~, names, ~] = fileparts({files.name});
            baselines = names';
        end
    end
    
    methods (Access = private)
        function filepath = getBaselinePath(obj, testName)
            %GETBASELINEPATH Get full path for baseline file
            if contains(testName, '..') || contains(testName, '/') || contains(testName, '\')
                error('RegressionValidator:InvalidTestName', ...
                      'testName must not contain path separators or traversal characters.');
            end
            filename = sprintf('%s.mat', testName);
            filepath = fullfile(obj.BaselineDir, filename);
        end
        
        function hash = computeHash(~, data)
            %COMPUTEHASH Compute MD5 hash of data
            hash = dwim.ml.computeHash(data);
        end
    end
end
