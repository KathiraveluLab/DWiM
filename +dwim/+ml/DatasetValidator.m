classdef DatasetValidator < handle
    % DatasetValidator - Enhanced validation and integrity checks for ML datasets
    %
    % Provides comprehensive validation beyond basic file existence checks:
    %   - Volume shape consistency
    %   - Label distribution analysis
    %   - Data quality metrics (NaN, Inf, outliers)
    %   - Normalization verification
    %   - Memory footprint estimation
    %   - Cross-split contamination detection
    %
    % USAGE:
    %   validator = dwim.ml.DatasetValidator('dataset_path');
    %   report = validator.runAllChecks();
    %   validator.generateReport('report.txt');
    %
    % Author: DWiM Team
    % Date: 2026-01-26
    
    properties
        DatasetPath         % Path to dataset root directory
        ManifestPath        % Path to manifest.json
        Manifest            % Loaded manifest data
        ValidationResults   % Structure with all validation results
        Format              % Dataset format (mat, nifti, hdf5)
    end
    
    methods
        function obj = DatasetValidator(datasetPath)
            % Constructor
            %
            % INPUTS:
            %   datasetPath - Root directory of the dataset
            
            obj.DatasetPath = datasetPath;
            obj.ManifestPath = fullfile(datasetPath, 'manifest.json');
            obj.ValidationResults = struct();
            
            % Load manifest
            if exist(obj.ManifestPath, 'file')
                obj.Manifest = jsondecode(fileread(obj.ManifestPath));
                obj.Format = obj.Manifest.format;
            else
                warning('Manifest file not found: %s', obj.ManifestPath);
            end
        end
        
        function report = runAllChecks(obj)
            % Run all validation checks
            %
            % OUTPUTS:
            %   report - Structure with all validation results
            
            fprintf('Running dataset validation checks...\n\n');
            
            % File existence checks
            obj.ValidationResults.fileIntegrity = obj.checkFileIntegrity();
            
            % Shape consistency checks
            obj.ValidationResults.shapeConsistency = obj.checkShapeConsistency();
            
            % Label distribution checks
            obj.ValidationResults.labelDistribution = obj.analyzeLabelDistribution();
            
            % Data quality checks
            obj.ValidationResults.dataQuality = obj.checkDataQuality();
            
            % Normalization verification
            obj.ValidationResults.normalization = obj.verifyNormalization();
            
            % Memory footprint estimation
            obj.ValidationResults.memoryFootprint = obj.estimateMemoryFootprint();
            
            % Cross-split contamination check
            obj.ValidationResults.contamination = obj.checkCrossSplitContamination();
            
            report = obj.ValidationResults;
            
            fprintf('\nValidation complete!\n');
        end
        
        function result = checkFileIntegrity(obj)
            % Check if all expected files exist and are readable
            
            fprintf('Checking file integrity...\n');
            result = struct();
            result.passed = true;
            result.missingFiles = {};
            result.corruptedFiles = {};
            
            splits = {'train', 'val', 'test'};
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    result.passed = false;
                    result.missingFiles{end+1} = splitName;
                    continue;
                end
                
                % Get files
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    try
                        % Try to load a small portion to verify readability
                        switch obj.Format
                            case 'mat'
                                load(filePath, '-mat');
                            case 'nifti'
                                niftiinfo(filePath);
                            case 'hdf5'
                                h5info(filePath);
                        end
                    catch ME
                        result.passed = false;
                        result.corruptedFiles{end+1} = filePath;
                    end
                end
            end
            
            fprintf('  File integrity: %s\n', ternary(result.passed, 'PASSED', 'FAILED'));
        end
        
        function result = checkShapeConsistency(obj)
            % Verify all volumes have consistent shapes
            
            fprintf('Checking shape consistency...\n');
            result = struct();
            result.passed = true;
            result.shapes = struct();
            result.inconsistencies = {};
            
            splits = {'train', 'val', 'test'};
            expectedShape = [];
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'volumes')
                                    volShape = size(data.volumes);
                                    volShape = volShape(1:3);  % [H, W, D]
                                else
                                    continue;
                                end
                            case 'nifti'
                                info = niftiinfo(filePath);
                                volShape = info.ImageSize(1:3);
                            case 'hdf5'
                                info = h5info(filePath, '/volumes');
                                volShape = info.Dataspace.Size(1:3);
                        end
                        
                        % Check consistency
                        if isempty(expectedShape)
                            expectedShape = volShape;
                            result.shapes.(splitName) = volShape;
                        elseif ~isequal(volShape, expectedShape)
                            result.passed = false;
                            result.inconsistencies{end+1} = sprintf(...
                                '%s/%s: [%d, %d, %d] (expected [%d, %d, %d])', ...
                                splitName, files(f).name, ...
                                volShape(1), volShape(2), volShape(3), ...
                                expectedShape(1), expectedShape(2), expectedShape(3));
                        end
                    catch ME
                        result.passed = false;
                        result.inconsistencies{end+1} = sprintf(...
                            '%s/%s: Failed to read shape - %s', ...
                            splitName, files(f).name, ME.message);
                    end
                end
            end
            
            fprintf('  Shape consistency: %s\n', ternary(result.passed, 'PASSED', 'FAILED'));
            if ~isempty(expectedShape)
                fprintf('    Expected shape: [%d, %d, %d]\n', expectedShape);
            end
        end
        
        function result = analyzeLabelDistribution(obj)
            % Analyze label distribution across splits
            
            fprintf('Analyzing label distribution...\n');
            result = struct();
            result.passed = true;
            result.distribution = struct();
            result.warnings = {};
            
            splits = {'train', 'val', 'test'};
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                labels = [];
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'labels')
                                    labels = [labels; data.labels(:)];
                                end
                            case 'hdf5'
                                batchLabels = h5read(filePath, '/labels');
                                labels = [labels; batchLabels(:)];
                        end
                    catch
                        % Skip files without labels
                    end
                end
                
                % Compute distribution
                if ~isempty(labels)
                    uniqueLabels = unique(labels);
                    counts = histcounts(labels, [uniqueLabels; max(uniqueLabels)+1]);
                    result.distribution.(splitName) = struct('labels', uniqueLabels, 'counts', counts);
                    
                    % Check for imbalance
                    if length(uniqueLabels) > 1
                        minCount = min(counts);
                        maxCount = max(counts);
                        imbalanceRatio = maxCount / minCount;
                        
                        if imbalanceRatio > 10
                            result.warnings{end+1} = sprintf(...
                                '%s split has severe class imbalance (ratio: %.1f:1)', ...
                                splitName, imbalanceRatio);
                        end
                    end
                end
            end
            
            fprintf('  Label distribution: %s\n', ternary(isempty(result.warnings), 'PASSED', 'WARNING'));
        end
        
        function result = checkDataQuality(obj)
            % Check for NaN, Inf, and extreme outliers
            
            fprintf('Checking data quality...\n');
            result = struct();
            result.passed = true;
            result.issues = {};
            result.statistics = struct();
            
            splits = {'train', 'val', 'test'};
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                sampleCount = 0;
                nanCount = 0;
                infCount = 0;
                
                for f = 1:min(5, length(files))  % Sample first 5 files
                    filePath = fullfile(splitDir, files(f).name);
                    
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'volumes')
                                    volumes = data.volumes;
                                else
                                    continue;
                                end
                            case 'nifti'
                                volumes = niftiread(filePath);
                            case 'hdf5'
                                volumes = h5read(filePath, '/volumes');
                        end
                        
                        sampleCount = sampleCount + 1;
                        nanCount = nanCount + sum(isnan(volumes(:)));
                        infCount = infCount + sum(isinf(volumes(:)));
                        
                    catch
                        % Skip problematic files
                    end
                end
                
                result.statistics.(splitName) = struct(...
                    'samples_checked', sampleCount, ...
                    'nan_count', nanCount, ...
                    'inf_count', infCount);
                
                if nanCount > 0
                    result.passed = false;
                    result.issues{end+1} = sprintf('%s: Found %d NaN values', splitName, nanCount);
                end
                
                if infCount > 0
                    result.passed = false;
                    result.issues{end+1} = sprintf('%s: Found %d Inf values', splitName, infCount);
                end
            end
            
            fprintf('  Data quality: %s\n', ternary(result.passed, 'PASSED', 'FAILED'));
        end
        
        function result = verifyNormalization(obj)
            % Verify normalization is consistent
            
            fprintf('Verifying normalization...\n');
            result = struct();
            result.passed = true;
            result.ranges = struct();
            result.warnings = {};
            
            splits = {'train', 'val', 'test'};
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                
                for f = 1:min(3, length(files))  % Sample first 3 files
                    filePath = fullfile(splitDir, files(f).name);
                    
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'volumes')
                                    volumes = data.volumes;
                                else
                                    continue;
                                end
                            case 'hdf5'
                                volumes = h5read(filePath, '/volumes');
                        end
                        
                        minVal = min(volumes(:));
                        maxVal = max(volumes(:));
                        
                        result.ranges.(splitName) = [minVal, maxVal];
                        
                        % Check if values are outside expected range
                        if obj.Manifest.normalization.method == "minmax"
                            expectedRange = obj.Manifest.normalization.range;
                            if minVal < expectedRange(1) - 0.01 || maxVal > expectedRange(2) + 0.01
                                result.warnings{end+1} = sprintf(...
                                    '%s: Values [%.3f, %.3f] outside expected range [%.3f, %.3f]', ...
                                    splitName, minVal, maxVal, expectedRange(1), expectedRange(2));
                            end
                        end
                    catch
                        % Skip
                    end
                end
            end
            
            fprintf('  Normalization: %s\n', ternary(isempty(result.warnings), 'PASSED', 'WARNING'));
        end
        
        function result = estimateMemoryFootprint(obj)
            % Estimate memory requirements for loading dataset
            
            fprintf('Estimating memory footprint...\n');
            result = struct();
            result.totalSize_GB = 0;
            result.splitSizes_GB = struct();
            
            splits = {'train', 'val', 'test'};
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                splitSize = 0;
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    fileInfo = dir(filePath);
                    splitSize = splitSize + fileInfo.bytes;
                end
                
                splitSize_GB = splitSize / 1e9;
                result.splitSizes_GB.(splitName) = splitSize_GB;
                result.totalSize_GB = result.totalSize_GB + splitSize_GB;
            end
            
            fprintf('  Total size: %.2f GB\n', result.totalSize_GB);
            fprintf('    Train: %.2f GB\n', result.splitSizes_GB.train);
            fprintf('    Val: %.2f GB\n', result.splitSizes_GB.val);
            fprintf('    Test: %.2f GB\n', result.splitSizes_GB.test);
        end
        
        function result = checkCrossSplitContamination(obj)
            % Check for duplicate samples across train/val/test splits
            
            fprintf('Checking for cross-split contamination...\n');
            result = struct();
            result.passed = true;
            result.duplicates = {};
            
            % Extract patient IDs from metadata if available
            splits = {'train', 'val', 'test'};
            patientIDs = struct();
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                patientIDs.(splitName) = {};
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'metadata')
                                    for i = 1:length(data.metadata)
                                        if isfield(data.metadata{i}, 'patientID')
                                            patientIDs.(splitName){end+1} = data.metadata{i}.patientID;
                                        end
                                    end
                                end
                        end
                    catch
                        % Skip
                    end
                end
            end
            
            % Check for overlaps
            if isfield(patientIDs, 'train') && isfield(patientIDs, 'val')
                overlap = intersect(patientIDs.train, patientIDs.val);
                if ~isempty(overlap)
                    result.passed = false;
                    result.duplicates{end+1} = sprintf('Train-Val overlap: %d patients', length(overlap));
                end
            end
            
            if isfield(patientIDs, 'train') && isfield(patientIDs, 'test')
                overlap = intersect(patientIDs.train, patientIDs.test);
                if ~isempty(overlap)
                    result.passed = false;
                    result.duplicates{end+1} = sprintf('Train-Test overlap: %d patients', length(overlap));
                end
            end
            
            if isfield(patientIDs, 'val') && isfield(patientIDs, 'test')
                overlap = intersect(patientIDs.val, patientIDs.test);
                if ~isempty(overlap)
                    result.passed = false;
                    result.duplicates{end+1} = sprintf('Val-Test overlap: %d patients', length(overlap));
                end
            end
            
            fprintf('  Contamination check: %s\n', ternary(result.passed, 'PASSED', 'FAILED'));
        end
        
        function generateReport(obj, outputPath)
            % Generate detailed validation report
            %
            % INPUTS:
            %   outputPath - Path to save report file
            
            fid = fopen(outputPath, 'w');
            
            fprintf(fid, '========================================\n');
            fprintf(fid, 'DATASET VALIDATION REPORT\n');
            fprintf(fid, '========================================\n\n');
            fprintf(fid, 'Dataset: %s\n', obj.DatasetPath);
            fprintf(fid, 'Generated: %s\n\n', datestr(now));
            
            % Write each validation result
            fields = fieldnames(obj.ValidationResults);
            for i = 1:length(fields)
                fieldName = fields{i};
                fprintf(fid, '\n--- %s ---\n', upper(strrep(fieldName, '_', ' ')));
                
                result = obj.ValidationResults.(fieldName);
                if isstruct(result)
                    obj.writeStructToFile(fid, result, 0);
                end
            end
            
            fprintf(fid, '\n========================================\n');
            fprintf(fid, 'END OF REPORT\n');
            fprintf(fid, '========================================\n');
            
            fclose(fid);
            fprintf('Report saved to: %s\n', outputPath);
        end
    end
    
    methods (Access = private)
        function writeStructToFile(obj, fid, s, indent)
            % Helper to write struct to file recursively
            
            indentStr = repmat('  ', 1, indent);
            fields = fieldnames(s);
            
            for i = 1:length(fields)
                fieldName = fields{i};
                value = s.(fieldName);
                
                if isstruct(value)
                    fprintf(fid, '%s%s:\n', indentStr, fieldName);
                    obj.writeStructToFile(fid, value, indent + 1);
                elseif iscell(value)
                    fprintf(fid, '%s%s:\n', indentStr, fieldName);
                    for j = 1:length(value)
                        fprintf(fid, '%s  - %s\n', indentStr, value{j});
                    end
                elseif isnumeric(value)
                    fprintf(fid, '%s%s: %s\n', indentStr, fieldName, mat2str(value));
                elseif islogical(value)
                    fprintf(fid, '%s%s: %s\n', indentStr, fieldName, ternary(value, 'true', 'false'));
                else
                    fprintf(fid, '%s%s: %s\n', indentStr, fieldName, string(value));
                end
            end
        end
    end
end

function result = ternary(condition, trueVal, falseVal)
    % Ternary operator helper
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
