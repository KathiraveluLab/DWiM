% QUICK_START_GUIDE Quick reference for DWiM pipeline usage
%
% This file contains quick-reference code snippets for common DWiM workflows.
% Copy and modify these examples for your own DICOM processing needs.

%% ========================================================================
%% BASIC SETUP
%% ========================================================================

% Add DWiM to MATLAB path
addpath(genpath('/path/to/DWiM'));

% Clear workspace
clear; clc; close all;

%% ========================================================================
%% EXAMPLE 1: Simple Volume Assembly
%% ========================================================================

% Path to DICOM series
dicomPath = '/path/to/dicom/series/';

% Simple assembly (fastest, minimal processing)
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries(dicomPath);

% Results:
% - volume: 3D array [rows, cols, slices]
% - spacing: voxel spacing [x, y, z] in mm
% - metadata: processing information

%% ========================================================================
%% EXAMPLE 2: Volume with Standard Preprocessing
%% ========================================================================

% Assemble, orient to RAS, resample to 1mm isotropic
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries(dicomPath, ...
    'TargetOrientation', 'RAS', ...
    'TargetSpacing', 1.0, ...
    'Validate', true);

fprintf('Volume shape: [%d, %d, %d]\n', size(volume));
fprintf('Voxel spacing: [%.2f, %.2f, %.2f] mm\n', spacing(1), spacing(2), spacing(3));

%% ========================================================================
%% EXAMPLE 3: Custom Preprocessing Pipeline
%% ========================================================================

% Build configuration for custom workflow
config = struct();

% Input/output specification
config.inputType = 'dicomdir';
config.outputType = 'volume';

% Processing steps to apply
config.steps = {'assemble', 'orient', 'resample', 'validate_volume'};

% Step parameters
config.parameters = struct();
config.parameters.orient.targetOrientation = 'RAS';
config.parameters.resample.targetSpacing = 1.0;

% Validation settings
config.validation.enabled = true;
config.verbose = true;

% Execute unified pipeline
[volume, metadata] = dwim.preprocessPipeline(dicomPath, config);

%% ========================================================================
%% EXAMPLE 4: 2D Image Processing
%% ========================================================================

% Load single DICOM file
dicomFile = '/path/to/single/file.dcm';
image = dicomread(dicomFile);

% Option A: Apply windowing preset (lung window)
windowedImage = dwim.preprocess.applyWindowPreset(image, 'lung');

% Option B: Normalize HU values manually
normalizedImage = dwim.preprocess.normalizeHU(image, -600, 1500);

% Validate image quality
[isValid, results] = dwim.preprocess.validateImageForML(image);

if isValid
    fprintf('Image quality: PASSED\n');
else
    fprintf('Image quality: FAILED\n');
    disp(results);
end

%% ========================================================================
%% EXAMPLE 5: Volume Validation
%% ========================================================================

% After assembly and processing
[isValid, results] = dwim.preprocess3d.validateVolumeForML(volume);

fprintf('Volume dimensions: [%d, %d, %d]\n', results.dimensions(1), ...
    results.dimensions(2), results.dimensions(3));
fprintf('Data type: %s\n', results.dataType);
fprintf('Value range: [%d, %d]\n', results.valueMin, results.valueMax);
fprintf('Validation status: %s\n', results.status);

%% ========================================================================
%% EXAMPLE 6: Batch Processing Multiple Patients
%% ========================================================================

% Directory containing patient folders
patientBaseDir = '/path/to/patients/';
patientDirs = dir(patientBaseDir);

volumes = {};
metadatas = {};
patientIDs = {};

for i = 3:length(patientDirs)  % Skip . and ..
    if patientDirs(i).isdir
        patientID = patientDirs(i).name;
        dicomDir = fullfile(patientBaseDir, patientID, 'dicom');
        
        try
            [volume, metadata] = dwim.preprocessPipeline(dicomDir, config);
            volumes{end+1} = volume;
            metadatas{end+1} = metadata;
            patientIDs{end+1} = patientID;
            fprintf('Processed: %s\n', patientID);
        catch ME
            fprintf('Failed: %s - %s\n', patientID, ME.message);
        end
    end
end

fprintf('\nProcessed %d patients\n', length(volumes));

%% ========================================================================
%% EXAMPLE 7: High-Resolution Processing (Research)
%% ========================================================================

% Process at 0.5mm resolution for detailed analysis
config_highres = struct();
config_highres.inputType = 'dicomdir';
config_highres.steps = {'assemble', 'orient', 'resample', 'validate_volume'};
config_highres.parameters.orient.targetOrientation = 'RAS';
config_highres.parameters.resample.targetSpacing = 0.5;  % High resolution
config_highres.validation.enabled = true;
config_highres.verbose = true;

[volumeHiRes, metadataHiRes] = dwim.preprocessPipeline(dicomPath, config_highres);

fprintf('High-resolution volume shape: [%d, %d, %d]\n', size(volumeHiRes));
fprintf('Note: High resolution requires more memory and computation\n');

%% ========================================================================
%% EXAMPLE 8: Lung-Specific Preprocessing
%% ========================================================================

% Configure for lung CT analysis
config_lung = struct();
config_lung.inputType = 'dicomdir';
config_lung.steps = {'assemble', 'orient', 'resample', 'normalize', 'validate_volume'};
config_lung.parameters.orient.targetOrientation = 'RAS';
config_lung.parameters.resample.targetSpacing = 1.0;
config_lung.parameters.normalize.windowCenter = -600;  % Lung window
config_lung.parameters.normalize.windowWidth = 1500;
config_lung.validation.enabled = true;
config_lung.verbose = true;

[lungVolume, lungMetadata] = dwim.preprocessPipeline(dicomPath, config_lung);

fprintf('Lung volume statistics:\n');
fprintf('  Min: %d HU\n', min(lungVolume(:)));
fprintf('  Max: %d HU\n', max(lungVolume(:)));
fprintf('  Mean: %.1f HU\n', mean(lungVolume(:)));
fprintf('  Std Dev: %.1f HU\n', std(lungVolume(:)));

%% ========================================================================
%% EXAMPLE 9: Saving and Loading Processed Data
%% ========================================================================

% Convert to single precision for storage efficiency
volumeSingle = single(volume);

% Save using MATLAB's built-in formats
outputFile = '/path/to/output/processed_volume.mat';
save(outputFile, 'volumeSingle', 'spacing', 'metadata');

% Load later
loaded = load(outputFile);
volumeLoaded = loaded.volumeSingle;
spacingLoaded = loaded.spacing;
metadataLoaded = loaded.metadata;

fprintf('Volume saved to: %s\n', outputFile);
fprintf('Disk space: %.2f MB\n', dir(outputFile).bytes / 1e6);

%% ========================================================================
%% EXAMPLE 10: Error Handling
%% ========================================================================

try
    % Your processing code
    [volume, metadata] = dwim.preprocessPipeline(dicomPath, config);
    
catch ME
    % Handle errors gracefully
    fprintf('\nPipeline Error:\n');
    fprintf('  Message: %s\n', ME.message);
    fprintf('  Identifier: %s\n', ME.identifier);
    
    % Common errors:
    if contains(ME.identifier, 'FileNotFound')
        fprintf('  Fix: Check DICOM directory path\n');
    elseif contains(ME.identifier, 'EmptyVolume')
        fprintf('  Fix: Verify DICOM files exist in directory\n');
    elseif contains(ME.identifier, 'NonCTModality')
        fprintf('  Fix: Input must be CT DICOM series\n');
    end
end

%% ========================================================================
%% CONFIGURATION TEMPLATES
%% ========================================================================

% Template 1: Minimal Processing (fastest)
config_minimal = struct(...
    'inputType', 'dicomdir', ...
    'outputType', 'volume', ...
    'steps', {{'assemble'}}, ...
    'parameters', struct(), ...
    'validation', struct('enabled', false), ...
    'verbose', false);

% Template 2: Standard Processing (recommended)
config_standard = struct(...
    'inputType', 'dicomdir', ...
    'outputType', 'volume', ...
    'steps', {{'assemble', 'orient', 'resample', 'validate_volume'}}, ...
    'parameters', struct( ...
        'orient', struct('targetOrientation', 'RAS'), ...
        'resample', struct('targetSpacing', 1.0)), ...
    'validation', struct('enabled', true), ...
    'verbose', true);

% Template 3: Full Processing (most thorough)
config_full = struct(...
    'inputType', 'dicomdir', ...
    'outputType', 'volume', ...
    'steps', {{'assemble', 'orient', 'resample', 'normalize', 'validate_volume'}}, ...
    'parameters', struct( ...
        'orient', struct('targetOrientation', 'RAS'), ...
        'resample', struct('targetSpacing', 1.0), ...
        'normalize', struct('windowCenter', -600, 'windowWidth', 1500)), ...
    'validation', struct('enabled', true), ...
    'verbose', true);

%% ========================================================================
%% USEFUL COMMANDS
%% ========================================================================

% View DICOM info from directory
% dicomInfo = dicominfo(dicomPath);
% disp(dicomInfo);

% Visualize volume slices
% figure; imshow(squeeze(volume(:,:,round(size(volume,3)/2))), []);
% title('Middle slice of processed volume');

% Check MATLAB toolboxes
ver;

% Get current DWIM path
dwimPath = which('dwim');
fprintf('DWiM path: %s\n', dwimPath);

%% ========================================================================
%% PERFORMANCE TIPS
%% ========================================================================

% 1. Use minimal config for quick prototyping
% 2. Pre-allocate arrays for batch processing
% 3. Use single precision for large volumes (saves 50% memory)
% 4. Enable verbose output during development
% 5. Disable validation in production if proven safe
% 6. Use 0.5-1.0mm spacing for ML (avoid extreme high resolution)
% 7. Parallelize batch processing with parfor if available

%% EXAMPLE 11: Create ML Dataset
% Use DatasetBuilder to prepare train/val/test splits for ML frameworks

% Initialize builder
builder = dwim.ml.DatasetBuilder('output/ml_dataset');
builder.setSplitRatios([0.7, 0.15, 0.15]);  % 70% train, 15% val, 15% test
builder.setTargetSize([128, 128, 64]);       % Resize to fixed dimensions
builder.setNormalization('minmax');          % Normalize to [0, 1]
builder.setFormat('mat');                    % Output format (mat/nifti/hdf5)
builder.setBatchSize(8);                     % Volumes per batch file

% Add volumes with metadata
volumes = {volume1, volume2, volume3};
metadata = {
    struct('patientID', 'P001', 'label', 0);
    struct('patientID', 'P002', 'label', 1);
    struct('patientID', 'P003', 'label', 0);
};
builder.addVolumes(volumes, metadata);

% Build and validate
builder.build();
[isValid, report] = builder.validateIntegrity();
if isValid
    fprintf('Dataset ready: %d train, %d val, %d test\n', ...
        length(builder.TrainIndices), length(builder.ValIndices), ...
        length(builder.TestIndices));
end

%% ========================================================================
%% HELPFUL LINKS
%% ========================================================================

% Project: https://github.com/KathiraveluLab/DWiM
% Documentation: See examples/ directory
% TCIA Data: https://www.cancerimagingarchive.net/
% MATLAB Docs: https://www.mathworks.com/products/image.html
