% EXAMPLE_VOLUME_PIPELINE Complete 3D volume processing pipeline
%
% This example demonstrates how to use buildVolumeFromSeries to process
% a DICOM series with automatic orientation correction and resampling.
%
% Requirements:
% - DICOM series in a directory
% - MATLAB with Image Processing Toolbox
% - DWiM toolbox

%% Setup
clear; clc; close all;

fprintf('DWiM Volume Pipeline Example\n');
fprintf('============================\n');

%% Example 1: Basic usage with all preprocessing
fprintf('\nExample 1: Full pipeline processing\n');

% Assume DICOM files are in this directory
dicomPath = 'path/to/your/dicom/series/';

try
    % Build volume with all preprocessing steps
    [volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries(dicomPath, ...
        'Verbose', true);

    fprintf('Successfully processed volume!\n');
    fprintf('Final dimensions: [%d %d %d]\n', size(volume));
    fprintf('Voxel spacing: [%.2f %.2f %.2f] mm\n', spacing);
    fprintf('Processing time: %.2f seconds\n', metadata.totalTime);

    % Display some metadata
    if isfield(metadata, 'patientName')
        fprintf('Patient: %s\n', metadata.patientName);
    end
    if isfield(metadata, 'modality')
        fprintf('Modality: %s\n', metadata.modality);
    end

catch ME
    fprintf('Error in full pipeline: %s\n', ME.message);
end

%% Example 2: Custom settings
fprintf('\nExample 2: Custom preprocessing settings\n');

try
    % Build volume with custom settings
    [volume2, spacing2, metadata2] = dwim.preprocess3d.buildVolumeFromSeries(dicomPath, ...
        'TargetOrientation', 'LPS', ...      % Left-Posterior-Superior
        'TargetSpacing', 1.0, ...            % 1mm isotropic
        'Validate', true, ...                % Run validation
        'Verbose', true);

    fprintf('Custom processing completed!\n');
    fprintf('Orientation: %s\n', metadata2.orientationCorrection.targetOrientation);
    fprintf('Spacing: %.2f mm isotropic\n', spacing2(1));

catch ME
    fprintf('Error in custom pipeline: %s\n', ME.message);
end

%% Example 3: Minimal processing
fprintf('\nExample 3: Minimal processing (assembly only)\n');

try
    % Build volume with minimal processing
    [volume3, spacing3, metadata3] = dwim.preprocess3d.buildVolumeFromSeries(dicomPath, ...
        'CorrectOrientation', false, ...     % Skip orientation correction
        'Resample', false, ...               % Skip resampling
        'Validate', false, ...               % Skip validation
        'Verbose', true);

    fprintf('Minimal processing completed!\n');
    fprintf('Raw volume dimensions: [%d %d %d]\n', size(volume3));
    fprintf('Original spacing: [%.2f %.2f %.2f] mm\n', spacing3);

catch ME
    fprintf('Error in minimal pipeline: %s\n', ME.message);
end

%% Example 4: Validation and visualization
fprintf('\nExample 4: Validation and basic visualization\n');

try
    % Process with validation
    [volume4, spacing4, metadata4] = dwim.preprocess3d.buildVolumeFromSeries(dicomPath, ...
        'Validate', true, 'Verbose', false);

    % Check validation results
    if metadata4.validation.performed
        validation = metadata4.validation.results;
        fprintf('Validation: %s\n', validation.assessment);

        if ~isempty(validation.issues)
            fprintf('Issues found: %s\n', strjoin(validation.issues, '; '));
        end

        if ~isempty(validation.warnings)
            fprintf('Warnings: %s\n', strjoin(validation.warnings, '; '));
        end
    end

    % Basic visualization (middle slice)
    figure('Name', 'Processed Volume - Middle Slice');
    middleSlice = round(size(volume4, 3) / 2);
    imagesc(volume4(:, :, middleSlice));
    colormap gray;
    axis equal tight;
    title(sprintf('Middle slice (Z=%d)', middleSlice));
    colorbar;

catch ME
    fprintf('Error in validation example: %s\n', ME.message);
end

%% Summary
fprintf('\n============================\n');
fprintf('Pipeline examples completed!\n');
fprintf('The buildVolumeFromSeries function provides:\n');
fprintf('- Automatic DICOM series discovery and sorting\n');
fprintf('- Orientation correction to standard anatomical coordinates\n');
fprintf('- Isotropic resampling for consistent voxel spacing\n');
fprintf('- Comprehensive validation and metadata\n');
fprintf('- Flexible configuration options\n');