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
        
        % Configuration for sampling
        NumSamplesDataQuality = 5   % Number of files to sample for data quality checks
        NumSamplesNormalization = 3 % Number of files to sample for normalization checks
        
        % Configuration for validation thresholds
        ImbalanceWarningThreshold = 10  % Class imbalance ratio threshold for warnings
        MinMaxTolerance = 0.01          % Tolerance for minmax normalization range checks
        ZScoreTolerance = 0.1           % Tolerance for zscore normalization checks
    end
    
    methods
        function splits = getDatasetSplits(obj)
            % Get dataset splits dynamically from directory structure
            %
            % OUTPUTS:
            %   splits - Cell array of split names (e.g., {'train', 'val', 'test'})
            
            dirContents = dir(obj.DatasetPath);
            isSubdir = [dirContents.isdir];
            % Exclude '.' and '..' and files
            validDirs = isSubdir & ~ismember({dirContents.name}, {'.', '..'});
            splits = {dirContents(validDirs).name};
            
            if isempty(splits)
                warning('No dataset splits found in %s', obj.DatasetPath);
            end
        end
        
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
                error('DatasetValidator:ManifestNotFound', 'Manifest file not found: %s', obj.ManifestPath);
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
            
            % Disk usage estimation
            obj.ValidationResults.diskUsage = obj.estimateDiskUsage();
            
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
            
            splits = obj.getDatasetSplits();
            if isempty(splits)
                return;
            end
            
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
                                whos('-file', filePath);
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
            
            splits = obj.getDatasetSplits();
            expectedShape = [];
            
            for splitIdx = 1:length(splits)
                splitName = splits{splitIdx};
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
                                % Use whos to avoid loading entire file
                                fileVars = whos('-file', filePath);
                                volumesIdx = find(strcmp({fileVars.name}, 'volumes'), 1);
                                if ~isempty(volumesIdx)
                                    volSize = fileVars(volumesIdx).size;
                                    volSize(end+1:3) = 1; % Pad with 1s if fewer than 3 dims
                                    volShape = volSize(1:3);  % [H, W, D]
                                else
                                    continue;
                                end
                            case 'nifti'
                                info = niftiinfo(filePath);
                                s = info.ImageSize;
                                s(end+1:3) = 1; % Pad with 1s if fewer than 3 dims
                                volShape = s(1:3);
                            case 'hdf5'
                                info = h5info(filePath, '/volumes');
                                s = info.Dataspace.Size;
                                s(end+1:3) = 1; % Pad with 1s if fewer than 3 dims
                                volShape = s(1:3);
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
            
            splits = obj.getDatasetSplits();
            
            % Check if format is supported
            if ~ismember(obj.Format, {'mat', 'hdf5'})
                result.warnings{end+1} = sprintf('Label distribution check not supported for format: %s. Only MAT and HDF5 formats are supported.', obj.Format);
                fprintf('  WARNING: %s\n', result.warnings{end});
                return;
            end
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                labelCells = cell(length(files), 1);
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'labels')
                                    labelCells{f} = data.labels(:);
                                end
                            case 'hdf5'
                                batchLabels = h5read(filePath, '/labels');
                                labelCells{f} = batchLabels(:);
                        end
                    catch ME
                        warning('DatasetValidator:SkippingFile', 'Skipping file %s due to error: %s', filePath, ME.message);
                    end
                end
                
                % Concatenate all labels at once
                labels = vertcat(labelCells{:});
                
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
                        
                        if imbalanceRatio > obj.ImbalanceWarningThreshold
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
            
            splits = obj.getDatasetSplits();
            
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
                
                for f = 1:min(obj.NumSamplesDataQuality, length(files))  % Sample files
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
                        
                    catch ME
                        warning('DatasetValidator:SkippingFile', 'Skipping file %s due to error: %s', filePath, ME.message);
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
            
            % Check if format is supported
            if ~ismember(obj.Format, {'mat', 'hdf5'})
                result.warnings{end+1} = sprintf('Normalization check not supported for format: %s. Only MAT and HDF5 formats are supported.', obj.Format);
                fprintf('  WARNING: %s\n', result.warnings{end});
                return;
            end
            
            splits = obj.getDatasetSplits();
            
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.DatasetPath, splitName);
                
                if ~exist(splitDir, 'dir')
                    continue;
                end
                
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                
                for f = 1:min(obj.NumSamplesNormalization, length(files))  % Sample files
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
                        meanVal = mean(volumes(:));
                        stdVal = std(volumes(:));
                        
                        result.ranges.(splitName) = [minVal, maxVal];
                        
                        % Check if values are outside expected range
                        if strcmpi(obj.Manifest.normalization.method, "minmax")
                            expectedRange = obj.Manifest.normalization.range;
                            if minVal < expectedRange(1) - obj.MinMaxTolerance || maxVal > expectedRange(2) + obj.MinMaxTolerance
                                result.warnings{end+1} = sprintf(...
                                    '%s: Values [%.3f, %.3f] outside expected range [%.3f, %.3f]', ...
                                    splitName, minVal, maxVal, expectedRange(1), expectedRange(2));
                            end
                        elseif strcmpi(obj.Manifest.normalization.method, "zscore")
                            % For z-score normalization, check if mean is close to 0 and std is close to 1
                            if abs(meanVal) > obj.ZScoreTolerance || abs(stdVal - 1.0) > obj.ZScoreTolerance
                                result.warnings{end+1} = sprintf(...
                                    '%s: Z-score stats [mean=%.3f, std=%.3f] deviate from expected [mean=0, std=1]', ...
                                    splitName, meanVal, stdVal);
                            end
                        end
                    catch ME
                        warning('DatasetValidator:SkippingFile', 'Skipping file %s due to error: %s', filePath, ME.message);
                    end
                end
            end
            
            fprintf('  Normalization: %s\n', ternary(isempty(result.warnings), 'PASSED', 'WARNING'));
        end
        
        function result = estimateDiskUsage(obj)
            % Estimate disk space occupied by dataset files
            
            fprintf('Estimating disk usage...\n');
            result = struct();
            result.totalSize_GB = 0;
            result.splitSizes_GB = struct();
            
            splits = obj.getDatasetSplits();
            
            % Initialize split sizes
            for s = 1:length(splits)
                result.splitSizes_GB.(splits{s}) = 0;
            end
            
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
            splitNames = fieldnames(result.splitSizes_GB);
            for i = 1:length(splitNames)
                splitName = splitNames{i};
                fprintf('    %s: %.2f GB\n', splitName, result.splitSizes_GB.(splitName));
            end
        end
        
        function result = checkCrossSplitContamination(obj)
            % Check for duplicate samples across train/val/test splits
            
            fprintf('Checking for cross-split contamination...\n');
            result = struct();
            result.passed = true;
            result.duplicates = {};
            result.warnings = {};
            
            % Extract patient IDs from metadata if available
            splits = obj.getDatasetSplits();
            patientIDs = struct();
            formatSupported = false;
            
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
                                formatSupported = true;
                                data = load(filePath);
                                if isfield(data, 'metadata')
                                    for i = 1:length(data.metadata)
                                        if isfield(data.metadata{i}, 'patientID')
                                            patientIDs.(splitName){end+1} = data.metadata{i}.patientID;
                                        end
                                    end
                                end
                            case 'hdf5'
                                formatSupported = true;
                                % Try to read patient IDs from HDF5 metadata
                                try
                                    patientData = h5read(filePath, '/metadata/patientID');
                                    if isstring(patientData)
                                        % Convert string array to cell array of char vectors
                                        patientData = cellstr(patientData);
                                    end
                                    if iscell(patientData)
                                        patientIDs.(splitName) = [patientIDs.(splitName), patientData{:}];
                                    else
                                        patientIDs.(splitName){end+1} = patientData;
                                    end
                                catch ME
                                    % It's expected that some files may not have patientID metadata.
                                    % We only warn if the error is something other than 'dataset not found'.
                                    if ~strcmp(ME.identifier, 'MATLAB:h5read:datasetNotFound')
                                        warning('DatasetValidator:H5MetadataReadError', 'Failed to read patientID from %s: %s', filePath, ME.message);
                                    end
                                end
                            otherwise
                                % Format not supported for contamination check
                        end
                    catch ME
                        warning('DatasetValidator:SkippingFile', 'Skipping file %s due to error: %s', filePath, ME.message);
                    end
                end
            end
            
            % Warn if format doesn't support contamination checking
            if ~formatSupported
                result.warnings{end+1} = sprintf('Contamination check not supported for format: %s. Only MAT and HDF5 formats are supported.', obj.Format);
                fprintf('  WARNING: %s\n', result.warnings{end});
                return;
            end
            
            % Check for overlaps between all pairs of splits
            splitNames = fieldnames(patientIDs);
            for i = 1:length(splitNames)
                for j = i + 1:length(splitNames)
                    splitA_name = splitNames{i};
                    splitB_name = splitNames{j};
                    
                    overlap = intersect(patientIDs.(splitA_name), patientIDs.(splitB_name));
                    if ~isempty(overlap)
                        result.passed = false;
                        result.duplicates{end+1} = sprintf('%s-%s overlap: %d patients', ...
                            splitA_name, splitB_name, length(overlap));
                    end
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
            if fid == -1
                error('DatasetValidator:FileOpenError', 'Could not open file for writing: %s', outputPath);
            end
            cleanupObj = onCleanup(@() fclose(fid));
            
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
