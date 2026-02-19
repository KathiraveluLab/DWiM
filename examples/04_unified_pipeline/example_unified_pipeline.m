% EXAMPLE_UNIFIED_PIPELINE Unified preprocessing pipeline for ML workflows
%
% This example demonstrates how to use the dwim.preprocessPipeline function
% to process DICOM folders into ML-ready volumes with a single function call.
%
% Requirements:
% - DICOM series in a directory
% - MATLAB with Image Processing Toolbox
% - DWiM toolbox

%% Setup
clear; clc; close all;

fprintf('DWiM Unified Pipeline Example\n');
fprintf('=============================\n');

%% Example 1: DICOM folder to ML-ready volume
fprintf('\nExample 1: DICOM folder → ML-ready volume\n');

% Path to DICOM series directory
dicomPath = 'path/to/your/dicom/series/';

if ~isfolder(dicomPath)
    error('dwim:Example:PathNotFound', 'Example path not found. Please update the `dicomPath` variable to point to your DICOM data.');
end

try
    % Configure the unified pipeline
    config = struct();
    config.inputType = 'dicomdir';           % Input is DICOM directory
    config.outputType = 'volume';            % Output is 3D volume
    config.steps = {'assemble', 'orient', 'resample', 'validate_volume'};
    config.parameters.orient.targetOrientation = 'RAS';
    config.parameters.resample.targetSpacing = 1.0;  % 1mm isotropic
    config.validation.enabled = true;
    config.verbose = true;

    % Process with single function call
    [volume, metadata] = dwim.preprocessPipeline(dicomPath, config);

    fprintf('✓ Successfully processed DICOM series!\n');
    fprintf('  Final dimensions: [%d %d %d]\n', size(volume));
    if isfield(metadata, 'resample') && isfield(metadata.resample, 'targetSpacing')
        fprintf('  Voxel spacing: %.2f mm (isotropic)\n', metadata.resample.targetSpacing);
    end
    if isfield(metadata, 'orient') && isfield(metadata.orient, 'targetOrientation')
        fprintf('  Orientation: %s\n', metadata.orient.targetOrientation);
    end
    fprintf('  Total processing time: %.2f seconds\n', metadata.totalTime);

    % Display validation results
    if isfield(metadata, 'validation') && metadata.validation.performed && metadata.validation.isValid
        fprintf('  Validation: PASSED\n');
    elseif isfield(metadata, 'validation') && metadata.validation.performed
        fprintf('  Validation: FAILED - check metadata.validation.results\n');
    end

catch ME
    fprintf('✗ Error in unified pipeline: %s\n', ME.message);
end

%% Example 2: Custom ML preprocessing pipeline
fprintf('\nExample 2: Custom ML preprocessing\n');

try
    % Configure for lung CT preprocessing
    config = struct();
    config.inputType = 'dicomdir';
    config.outputType = 'volume';
    config.steps = {'assemble', 'orient', 'resample', 'normalize', 'validate_volume'};
    config.parameters.orient.targetOrientation = 'RAS';
    config.parameters.resample.targetSpacing = 1.0;
    config.parameters.normalize.windowCenter = -600;  % Lung window center
    config.parameters.normalize.windowWidth = 1500;   % Lung window width
    config.validation.enabled = true;
    config.verbose = true;

    [lungVolume, lungMetadata] = dwim.preprocessPipeline(dicomPath, config);

    fprintf('✓ Lung CT preprocessing completed!\n');
    fprintf('  Volume range: [%d, %d] HU\n', min(lungVolume(:)), max(lungVolume(:)));
    fprintf('  Mean intensity: %.1f\n', mean(lungVolume(:)));

catch ME
    fprintf('✗ Error in lung preprocessing: %s\n', ME.message);
end

%% Example 3: Minimal processing for quick inspection
fprintf('\nExample 3: Minimal processing for inspection\n');

try
    % Minimal configuration for fast processing
    config = struct();
    config.inputType = 'dicomdir';
    config.outputType = 'volume';
    config.steps = {'assemble'};  % Only assemble, no other processing
    config.verbose = true;

    [rawVolume, rawMetadata] = dwim.preprocessPipeline(dicomPath, config);

    fprintf('✓ Raw volume assembled!\n');
    fprintf('  Dimensions: [%d %d %d]\n', size(rawVolume));
    fprintf('  Original spacing: [%.2f %.2f %.2f] mm\n', rawMetadata.input.spacing);

catch ME
    fprintf('✗ Error in minimal processing: %s\n', ME.message);
end

%% Example 4: Single slice processing
fprintf('\nExample 4: Single DICOM slice processing\n');

% Path to single DICOM file
singleDicomPath = 'path/to/single/slice.dcm';

try
    % Configure for 2D slice processing
    config = struct();
    config.inputType = 'filepath';            % Single file input
    config.outputType = 'image';             % 2D output
    config.steps = {'validate', 'window', 'normalize'};
    config.parameters.window.preset = 'lung';
    config.parameters.normalize.windowCenter = -600;
    config.parameters.normalize.windowWidth = 1500;
    config.verbose = true;

    [processedSlice, sliceMetadata] = dwim.preprocessPipeline(singleDicomPath, config);

    fprintf('✓ Single slice processed!\n');
    fprintf('  Dimensions: [%d %d]\n', size(processedSlice));
    fprintf('  Value range: [%.1f, %.1f]\n', min(processedSlice(:)), max(processedSlice(:)));

catch ME
    fprintf('✗ Error in slice processing: %s\n', ME.message);
end

%% Summary
fprintf('\n=============================\n');
fprintf('Unified Pipeline Examples Completed!\n');
fprintf('\nThe dwim.preprocessPipeline function provides:\n');
fprintf('- Single function call for complete preprocessing\n');
fprintf('- Flexible configuration for different use cases\n');
fprintf('- Support for DICOM directories and individual files\n');
fprintf('- Comprehensive metadata and validation\n');
fprintf('- Optimized for ML workflows\n');