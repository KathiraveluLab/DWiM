classdef DatasetBuilder < handle
    % DatasetBuilder - Build ML-ready datasets from preprocessed DICOM volumes
    %
    % This class provides a complete solution for converting preprocessed
    % DICOM volumes into structured datasets ready for machine learning
    % frameworks (PyTorch, TensorFlow, MATLAB Deep Learning).
    %
    % FEATURES:
    %   - Flexible dataset structure (train/val/test splits)
    %   - Volume resizing and resampling
    %   - Intensity normalization
    %   - Batch processing and saving
    %   - Metadata tracking and linkage
    %   - Integrity validation
    %
    % USAGE:
    %   builder = dwim.ml.DatasetBuilder('output_dir');
    %   builder.addVolumes(volumeFiles, labels);
    %   builder.setSplitRatios([0.7, 0.15, 0.15]);
    %   builder.build();
    %
    % Author: DWiM Team
    % Date: 2026-01-17
    
    properties
        OutputDir           % Root directory for dataset
        DatasetName         % Name of the dataset
        TargetSize          % Target volume dimensions [H, W, D]
        TargetSpacing       % Target voxel spacing [x, y, z] mm
        NormalizationMethod % 'minmax', 'zscore', 'hu', 'percentile'
        NormalizationRange  % Output range for normalization [min, max]
        SplitRatios         % [train, val, test] ratios (sum to 1.0)
        BatchSize           % Number of volumes per batch file
        Format              % Output format: 'mat', 'nifti', 'hdf5'
        Metadata            % Cell array of metadata structs
        Labels              % Cell array of labels/annotations
        VolumePaths         % Cell array of source volume paths
        RandomSeed          % Random seed for reproducible splits
    end
    
    properties (Access = private)
        NumVolumes          % Total number of volumes
        TrainIndices        % Indices for training set
        ValIndices          % Indices for validation set
        TestIndices         % Indices for test set
        ManifestData        % Dataset manifest structure
    end
    
    methods
        function obj = DatasetBuilder(outputDir, varargin)
            % Constructor - Initialize dataset builder
            %
            % INPUTS:
            %   outputDir - Root directory for dataset output
            %   varargin  - Optional name-value pairs:
            %               'DatasetName' - Name of dataset (default: auto-generated)
            %               'TargetSize' - Target dimensions (default: [256, 256, 128])
            %               'TargetSpacing' - Target spacing (default: [1, 1, 1])
            %               'Normalization' - Method (default: 'minmax')
            %               'Range' - Output range (default: [0, 1])
            %               'Format' - Output format (default: 'mat')
            %               'BatchSize' - Volumes per batch (default: 10)
            %               'Seed' - Random seed (default: 42)
            
            % Parse inputs
            p = inputParser;
            addRequired(p, 'outputDir', @ischar);
            addParameter(p, 'DatasetName', sprintf('dataset_%s', datestr(now, 'yyyymmdd')), @ischar);
            addParameter(p, 'TargetSize', [256, 256, 128], @(x) isnumeric(x) && length(x) == 3);
            addParameter(p, 'TargetSpacing', [1.0, 1.0, 1.0], @(x) isnumeric(x) && length(x) == 3);
            addParameter(p, 'Normalization', 'minmax', @ischar);
            addParameter(p, 'Range', [0, 1], @(x) isnumeric(x) && length(x) == 2);
            addParameter(p, 'Format', 'mat', @ischar);
            addParameter(p, 'BatchSize', 10, @(x) isnumeric(x) && x > 0);
            addParameter(p, 'Seed', 42, @isnumeric);
            parse(p, outputDir, varargin{:});
            
            % Set properties
            obj.OutputDir = p.Results.outputDir;
            obj.DatasetName = p.Results.DatasetName;
            obj.TargetSize = p.Results.TargetSize;
            obj.TargetSpacing = p.Results.TargetSpacing;
            obj.NormalizationMethod = p.Results.Normalization;
            obj.NormalizationRange = p.Results.Range;
            obj.Format = p.Results.Format;
            obj.BatchSize = p.Results.BatchSize;
            obj.RandomSeed = p.Results.Seed;
            
            % Initialize containers
            obj.VolumePaths = {};
            obj.Metadata = {};
            obj.Labels = {};
            obj.NumVolumes = 0;
            obj.SplitRatios = [0.7, 0.15, 0.15]; % Default split
            
            % Create output directory
            if ~exist(obj.OutputDir, 'dir')
                mkdir(obj.OutputDir);
            end
        end
        
        function addVolumes(obj, volumePaths, labels, metadata)
            % Add volumes to dataset
            %
            % INPUTS:
            %   volumePaths - Cell array of volume file paths or volume data
            %   labels      - Cell array of labels/annotations
            %   metadata    - (Optional) Cell array of metadata structs
            
            if ~iscell(volumePaths)
                volumePaths = {volumePaths};
            end
            if ~iscell(labels)
                labels = {labels};
            end
            if nargin < 4
                metadata = cell(size(volumePaths));
            elseif ~iscell(metadata)
                metadata = {metadata};
            end
            
            % Validate inputs
            if length(volumePaths) ~= length(labels)
                error('Number of volumes must match number of labels');
            end

            % Pad or truncate metadata to match volumePaths length
            if numel(metadata) ~= numel(volumePaths)
                warning('DatasetBuilder:MismatchedMetadataCount', ...
                    'Number of metadata entries (%d) does not match number of volumes (%d). Adjusting metadata count.', ...
                    numel(metadata), numel(volumePaths));
                new_metadata = cell(size(volumePaths));
                n_to_copy = min(numel(metadata), numel(volumePaths));
                if n_to_copy > 0
                    new_metadata(1:n_to_copy) = metadata(1:n_to_copy);
                end
                metadata = new_metadata;
            end

            % Validate and sanitize metadata entries: ensure each element
            % is a struct; replace missing/invalid entries with empty struct.
            for k = 1:numel(metadata)
                if isempty(metadata{k})
                    metadata{k} = struct();
                elseif ~isstruct(metadata{k})
                    warning('DatasetBuilder:InvalidMetadata', ...
                            'metadata{%d} is not a struct; replacing with empty struct.', k);
                    metadata{k} = struct();
                end
            end
            
            % Append to existing data
            obj.VolumePaths = [obj.VolumePaths; volumePaths(:)];
            obj.Labels = [obj.Labels; labels(:)];
            obj.Metadata = [obj.Metadata; metadata(:)];
            obj.NumVolumes = length(obj.VolumePaths);
            
            fprintf('Added %d volumes (total: %d)\n', length(volumePaths), obj.NumVolumes);
        end
        
        function setSplitRatios(obj, ratios)
            % Set train/val/test split ratios
            %
            % INPUTS:
            %   ratios - [train, val, test] ratios (must sum to 1.0)
            
            if length(ratios) ~= 3
                error('Split ratios must be [train, val, test]');
            end
            if abs(sum(ratios) - 1.0) > 1e-6
                error('Split ratios must sum to 1.0');
            end
            
            obj.SplitRatios = ratios;
        end
        
        function build(obj)
            % Build the complete dataset
            %
            % This method orchestrates the entire dataset building process:
            %   1. Create directory structure
            %   2. Split data into train/val/test
            %   3. Process and save volumes
            %   4. Generate manifest and metadata files
            %   5. Validate dataset integrity
            
            fprintf('\n========================================\n');
            fprintf('Building ML Dataset: %s\n', obj.DatasetName);
            fprintf('========================================\n\n');
            
            if obj.NumVolumes == 0
                error('No volumes added to dataset. Use addVolumes() first.');
            end
            
            % Step 1: Create directory structure
            fprintf('Step 1/5: Creating directory structure...\n');
            obj.createDirectoryStructure();
            
            % Step 2: Split data
            fprintf('Step 2/5: Splitting data (Train=%.0f%%, Val=%.0f%%, Test=%.0f%%)...\n', ...
                obj.SplitRatios(1)*100, obj.SplitRatios(2)*100, obj.SplitRatios(3)*100);
            obj.splitData();
            
            % Step 3: Process and save volumes
            fprintf('Step 3/5: Processing and saving volumes...\n');
            obj.processAndSaveVolumes();
            
            % Step 4: Generate manifest
            fprintf('Step 4/5: Generating dataset manifest...\n');
            obj.generateManifest();
            
            % Step 5: Validate integrity
            fprintf('Step 5/5: Validating dataset integrity...\n');
            [isValid, report] = obj.validateIntegrity();
            
            if isValid
                fprintf('\n[OK] Dataset built successfully!\n');
                fprintf('Output: %s\n', obj.OutputDir);
            else
                warning('Dataset validation found issues:\n%s', report);
            end
            
            fprintf('\n========================================\n');
            fprintf('Dataset Build Complete\n');
            fprintf('========================================\n\n');
        end
        
        function [isValid, report] = validateIntegrity(obj)
            % Validate dataset integrity
            %
            % CHECKS:
            %   - All expected files exist
            %   - Volume dimensions are consistent
            %   - No missing samples
            %   - Metadata alignment
            %
            % OUTPUTS:
            %   isValid - Boolean indicating if dataset is valid
            %   report  - String with validation details
            
            report = '';
            isValid = true;
            
            % Check if manifest exists
            manifestPath = fullfile(obj.OutputDir, 'manifest.json');
            if ~exist(manifestPath, 'file')
                report = [report, 'ERROR: Manifest file missing\n'];
                isValid = false;
                return;
            end
            
            % Load manifest
            manifest = jsondecode(fileread(manifestPath));
            
            % Check each split
            splits = {'train', 'val', 'test'};
            for s = 1:length(splits)
                splitName = splits{s};
                splitDir = fullfile(obj.OutputDir, splitName);
                
                if ~exist(splitDir, 'dir')
                    report = [report, sprintf('ERROR: %s directory missing\n', splitName)];
                    isValid = false;
                    continue;
                end
                
                % Get expected number of samples
                expectedSamples = manifest.splits.(splitName).samples;
                
                % Count actual files
                files = dir(fullfile(splitDir, ['*.' obj.Format]));
                actualSamples = 0;
                
                for f = 1:length(files)
                    filePath = fullfile(splitDir, files(f).name);
                    try
                        switch obj.Format
                            case 'mat'
                                data = load(filePath);
                                if isfield(data, 'volumes')
                                    actualSamples = actualSamples + size(data.volumes, 4);
                                else
                                    actualSamples = actualSamples + 1;
                                end
                            case 'nifti'
                                actualSamples = actualSamples + 1;
                            case 'hdf5'
                                info = h5info(filePath, '/volumes');
                                actualSamples = actualSamples + info.Dataspace.Size(4);
                        end
                    catch ME
                        report = [report, sprintf('ERROR: Failed to read %s: %s\n', ...
                            files(f).name, ME.message)];
                        isValid = false;
                    end
                end
                
                if actualSamples ~= expectedSamples
                    report = [report, sprintf('WARNING: %s split has %d samples (expected %d)\n', ...
                        splitName, actualSamples, expectedSamples)];
                    isValid = false;
                end
            end
            
            if isempty(report)
                report = 'All integrity checks passed';
            end
        end
    end
    
    methods (Access = private)
        function createDirectoryStructure(obj)
            % Create train/val/test directory structure
            
            splits = {'train', 'val', 'test'};
            for i = 1:length(splits)
                splitDir = fullfile(obj.OutputDir, splits{i});
                if ~exist(splitDir, 'dir')
                    mkdir(splitDir);
                end
            end
            
            fprintf('  Created: %s\n', fullfile(obj.OutputDir, 'train'));
            fprintf('  Created: %s\n', fullfile(obj.OutputDir, 'val'));
            fprintf('  Created: %s\n', fullfile(obj.OutputDir, 'test'));
        end
        
        function splitData(obj)
            % Split data into train/val/test sets
            
            % Set random seed for reproducibility
            rng(obj.RandomSeed);
            
            % Generate random permutation
            indices = randperm(obj.NumVolumes);
            
            % Calculate split sizes
            numTrain = floor(obj.NumVolumes * obj.SplitRatios(1));
            numVal = floor(obj.NumVolumes * obj.SplitRatios(2));
            
            % Assign indices
            obj.TrainIndices = indices(1:numTrain);
            obj.ValIndices = indices(numTrain+1:numTrain+numVal);
            obj.TestIndices = indices(numTrain+numVal+1:end);
            
            fprintf('  Train: %d samples\n', length(obj.TrainIndices));
            fprintf('  Val:   %d samples\n', length(obj.ValIndices));
            fprintf('  Test:  %d samples\n', length(obj.TestIndices));
        end
        
        function processAndSaveVolumes(obj)
            % Process all volumes and save to appropriate splits
            
            splits = struct(...
                'train', obj.TrainIndices, ...
                'val', obj.ValIndices, ...
                'test', obj.TestIndices);
            
            splitNames = fieldnames(splits);
            
            for s = 1:length(splitNames)
                splitName = splitNames{s};
                indices = splits.(splitName);
                
                if isempty(indices)
                    continue;
                end
                
                fprintf('  Processing %s set (%d samples)...\n', splitName, length(indices));
                
                % Process in batches
                numBatches = ceil(length(indices) / obj.BatchSize);
                
                for b = 1:numBatches
                    batchStart = (b-1) * obj.BatchSize + 1;
                    batchEnd = min(b * obj.BatchSize, length(indices));
                    batchIndices = indices(batchStart:batchEnd);
                    
                    % Process batch
                    [volumes, labels, metadata] = obj.processBatch(batchIndices);
                    
                    % Save batch
                    obj.saveBatch(splitName, b, volumes, labels, metadata);
                    
                    fprintf('    Batch %d/%d complete\n', b, numBatches);
                end
            end
        end
        
        function [volumes, labels, metadata] = processBatch(obj, indices)
            % Process a batch of volumes
            % PR #48: Pre-allocate efficiently to reduce memory fragmentation
            
            numSamples = length(indices);
            % Pre-allocate all arrays at once for memory efficiency
            volumes = zeros([obj.TargetSize, numSamples], 'single');
            labels = cell(numSamples, 1);
            metadata = cell(numSamples, 1);
            
            % PR #48: Cache target size to avoid repeated property access
            targetSize = obj.TargetSize;
            
            for i = 1:numSamples
                idx = indices(i);
                
                try
                    % Load volume
                    volumePath = obj.VolumePaths{idx};
                    if ischar(volumePath) || isstring(volumePath)
                        % Load from file
                        [volume, meta] = obj.loadVolume(volumePath);
                    else
                        % Volume data provided directly
                        volume = volumePath;
                        meta = obj.Metadata{idx};
                    end

                    % Guard: ensure loaded volume is numeric
                    if ~isnumeric(volume)
                        error('DatasetBuilder:NonNumericVolume', ...
                              'Volume at index %d is not numeric (%s).', idx, class(volume));
                    end
                    
                    % Resize to target size (using cached targetSize)
                    volume = obj.resizeVolume(volume, targetSize);
                    
                    % Normalize intensities (PR #48: hot path)
                    volume = obj.normalizeVolume(volume);
                    
                    % Store
                    volumes(:,:,:,i) = single(volume);
                    labels{i} = obj.Labels{idx};
                    metadata{i} = meta;

                catch ME
                    warning('DatasetBuilder:VolumeProcessingFailed', ...
                            'Skipping volume %d: %s', idx, ME.message);
                    % Leave zero-filled slot and empty label/metadata
                    labels{i} = [];
                    metadata{i} = struct('error', ME.message, 'skipped', true);
                end
            end
        end
        
        function [volume, metadata] = loadVolume(obj, volumePath)
            % Load volume from file
            
            [~, ~, ext] = fileparts(volumePath);
            
            switch lower(ext)
                case '.mat'
                    data = load(volumePath);
                    if isfield(data, 'volume')
                        volume = data.volume;
                        metadata = data.metadata;
                    else
                        fields = fieldnames(data);
                        volume = data.(fields{1});
                        metadata = struct();
                    end
                    
                case {'.nii', '.gz'}
                    nii = niftiread(volumePath);
                    info = niftiinfo(volumePath);
                    volume = nii;
                    metadata = struct(...
                        'PixelDimensions', info.PixelDimensions, ...
                        'ImageSize', info.ImageSize);
                    
                otherwise
                    error('Unsupported file format: %s', ext);
            end
        end
        
        function resizedVolume = resizeVolume(obj, volume, targetSize)
            % Resize volume to target dimensions
            
            currentSize = size(volume);
            
            if isequal(currentSize, targetSize)
                resizedVolume = volume;
                return;
            end
            
            % Use imresize3 for 3D volumes
            resizedVolume = imresize3(volume, targetSize, 'linear');
        end
        
        function normalizedVolume = normalizeVolume(obj, volume)
            % Normalize volume intensities
            % PR #48: Performance-critical section (hot path in batch processing)
            
            switch obj.NormalizationMethod
                case 'minmax'
                    % PR #48: Vectorized min/max — fast on modern MATLAB
                    vMin = min(volume(:), 'omitnan');
                    vMax = max(volume(:), 'omitnan');
                    if vMax > vMin
                        volume = (volume - vMin) / (vMax - vMin);
                    else
                        % Constant volume: map to midpoint [0,1] before scaling
                        volume = zeros(size(volume), 'like', volume) + 0.5;
                    end
                    volume = volume * (obj.NormalizationRange(2) - obj.NormalizationRange(1)) + ...
                        obj.NormalizationRange(1);
                    
                case 'zscore'
                    s = std(volume(:), 'omitnan');
                    if s > 0
                        volume = (volume - mean(volume(:), 'omitnan')) / s;
                    else
                        volume = zeros(size(volume), 'like', volume);
                    end
                    
                case 'percentile'
                    p1 = prctile(volume(:), 1);
                    p99 = prctile(volume(:), 99);
                    if p99 > p1
                        volume = (volume - p1) / (p99 - p1);
                    else
                        % For constant or near-constant volumes, map to the midpoint
                        volume = zeros(size(volume), 'like', volume) + 0.5;
                    end
                    volume = max(0, min(1, volume));
                    
                case 'hu'
                    % Assume HU values, clip and normalize
                    volume = max(-1000, min(3000, volume));
                    volume = (volume + 1000) / 4000;
            end
            
            normalizedVolume = volume;
        end
        
        function saveBatch(obj, splitName, batchNum, volumes, labels, metadata)
            % Save batch to file
            
            splitDir = fullfile(obj.OutputDir, splitName);
            filename = sprintf('batch_%03d.%s', batchNum, obj.Format);
            filepath = fullfile(splitDir, filename);
            
            switch obj.Format
                case 'mat'
                    save(filepath, 'volumes', 'labels', 'metadata', '-v7.3');
                    
                case 'nifti'
                    for i = 1:size(volumes, 4)
                        fname = sprintf('volume_%03d_%03d.nii', batchNum, i);
                        fpath = fullfile(splitDir, fname);
                        niftiwrite(volumes(:,:,:,i), fpath);
                    end
                    
                case 'hdf5'
                    h5create(filepath, '/volumes', size(volumes));
                    h5write(filepath, '/volumes', volumes);
            end
        end
        
        function generateManifest(obj)
            % Generate dataset manifest JSON file
            
            manifest = struct();
            manifest.dataset = struct(...
                'name', obj.DatasetName, ...
                'version', '1.0', ...
                'created', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
                'total_samples', obj.NumVolumes);
            
            manifest.splits = struct(...
                'train', struct('samples', length(obj.TrainIndices), 'path', 'train'), ...
                'val', struct('samples', length(obj.ValIndices), 'path', 'val'), ...
                'test', struct('samples', length(obj.TestIndices), 'path', 'test'));
            
            manifest.preprocessing = struct(...
                'target_size', obj.TargetSize, ...
                'target_spacing', obj.TargetSpacing, ...
                'normalization', obj.NormalizationMethod, ...
                'normalization_range', obj.NormalizationRange);
            
            manifest.format = struct(...
                'type', obj.Format, ...
                'batch_size', obj.BatchSize);
            
            % Save manifest
            manifestPath = fullfile(obj.OutputDir, 'manifest.json');
            manifestJSON = jsonencode(manifest, 'PrettyPrint', true);
            fid = fopen(manifestPath, 'w');
            fprintf(fid, '%s', manifestJSON);
            fclose(fid);
            
            fprintf('  Manifest saved: %s\n', manifestPath);
        end
    end
end
