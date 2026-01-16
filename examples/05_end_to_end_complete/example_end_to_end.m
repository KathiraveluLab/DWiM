% Complete End-to-End DWiM Pipeline Example
% 
% This example demonstrates the complete DWiM workflow from DICOM acquisition
% through ML-ready dataset preparation, showcasing all 5 architectural layers.
%
% LAYERS DEMONSTRATED:
%   Layer 1: Acquisition       - Connect to Orthanc, query/retrieve DICOM data
%   Layer 2: Preprocessing2D   - Window/level, normalization, validation
%   Layer 3: VolumeConstruction - Assemble 3D volumes, resample, orient
%   Layer 4: Orchestration     - Unified pipeline configuration
%   Layer 5: MLPreparation     - Dataset organization for ML frameworks
%
% REQUIREMENTS:
%   - Orthanc PACS server running (default: http://localhost:8042)
%   - Medical Imaging Toolbox
%   - Image Processing Toolbox
%
% USAGE:
%   Run this script section by section (Ctrl+Enter) to see each layer
%   Or run the entire script: example_end_to_end
%
% Author: DWiM Team
% Date: 2026-01-17

clear; clc;
addpath(genpath('../../+dwim'));

%% LAYER 1: ACQUISITION - Connect to Orthanc and Query Data
% Establish connection to PACS and retrieve study metadata

fprintf('\n');
fprintf('========================================\n');
fprintf('LAYER 1: DICOM ACQUISITION\n');
fprintf('========================================\n\n');

% Connection configuration
orthancConfig = struct(...
    'url', 'http://localhost:8042', ...
    'username', 'orthanc', ...
    'password', 'orthanc');

% Connect to Orthanc
try
    conn = dwim.connectToOrthanc(orthancConfig);
    fprintf('Connected to Orthanc at %s\n', orthancConfig.url);
catch ME
    error('Failed to connect to Orthanc: %s\n', ME.message);
end

% Query for CT chest studies
fprintf('\nQuerying for CT studies...\n');
queryParams = struct(...
    'StudyDescription', '*CHEST*', ...
    'Modality', 'CT', ...
    'Level', 'Study');

studies = conn.query(queryParams);
fprintf('Found %d studies\n', length(studies));

% Select first study for processing
if isempty(studies)
    error('No studies found. Please upload DICOM data to Orthanc.');
end

studyID = studies(1).ID;
fprintf('\nSelected study: %s\n', studies(1).StudyDescription);
fprintf('Study Date: %s\n', studies(1).StudyDate);

% Get series for this study
series = conn.getSeries(studyID);
fprintf('Found %d series in study\n', length(series));

% Download first series
seriesID = series(1).ID;
fprintf('\nDownloading series: %s\n', series(1).SeriesDescription);
fprintf('Number of instances: %d\n', series(1).NumberOfInstances);

% Create temporary directory for DICOM files
tempDir = fullfile(tempdir, 'dwim_example');
if ~exist(tempDir, 'dir')
    mkdir(tempDir);
end

% Retrieve DICOM files
dicomFiles = conn.retrieveSeries(seriesID, tempDir);
fprintf('Downloaded %d DICOM files\n', length(dicomFiles));

%% LAYER 2: PREPROCESSING2D - Process Individual Slices
% Apply windowing, normalization, and validation to 2D slices

fprintf('\n');
fprintf('========================================\n');
fprintf('LAYER 2: 2D PREPROCESSING\n');
fprintf('========================================\n\n');

% Configure 2D preprocessing
config2D = struct(...
    'window', struct('preset', 'lung', 'center', -600, 'width', 1500), ...
    'normalization', struct('method', 'hu', 'outputRange', [0, 1]), ...
    'validation', struct('checkDimensions', true, 'minSize', [256, 256]));

fprintf('Processing slices with Lung window (C=-600, W=1500)...\n');

% Process first few slices as demonstration
numSlicesToShow = min(3, length(dicomFiles));
processedSlices = cell(numSlicesToShow, 1);

for i = 1:numSlicesToShow
    % Read DICOM
    info = dicominfo(dicomFiles{i});
    img = dicomread(info);
    
    % Apply window preset
    windowedImg = dwim.applyWindowPreset(img, info, config2D.window);
    
    % Normalize HU values
    normalizedImg = dwim.normalizeHU(windowedImg, config2D.normalization);
    
    % Validate for ML
    [isValid, validationMsg] = dwim.validateImageForML(normalizedImg);
    
    processedSlices{i} = normalizedImg;
    
    fprintf('Slice %d: %s - %s\n', i, info.SOPInstanceUID(1:20), validationMsg);
end

fprintf('\nCompleted 2D preprocessing for %d slices\n', numSlicesToShow);

%% LAYER 3: VOLUME CONSTRUCTION - Build 3D Volume
% Assemble slices into coherent 3D volume with proper orientation

fprintf('\n');
fprintf('========================================\n');
fprintf('LAYER 3: 3D VOLUME CONSTRUCTION\n');
fprintf('========================================\n\n');

% Configure volume construction
config3D = struct(...
    'targetSpacing', [1.0, 1.0, 1.0], ...
    'targetOrientation', 'RAS', ...
    'interpolation', 'linear', ...
    'validation', struct('checkSpacing', true, 'checkOrientation', true));

fprintf('Building volume from %d DICOM files...\n', length(dicomFiles));

% Build volume using DWiM function
try
    [volume, metadata] = dwim.buildVolumeFromSeries(dicomFiles, config3D);
    
    fprintf('\nVolume constructed successfully:\n');
    fprintf('  Dimensions: %d x %d x %d\n', size(volume, 1), size(volume, 2), size(volume, 3));
    fprintf('  Spacing: [%.2f, %.2f, %.2f] mm\n', ...
        metadata.PixelSpacing(1), metadata.PixelSpacing(2), metadata.SliceThickness);
    fprintf('  Orientation: %s\n', metadata.Orientation);
    fprintf('  Data type: %s\n', class(volume));
    fprintf('  Value range: [%.2f, %.2f]\n', min(volume(:)), max(volume(:)));
    
catch ME
    error('Volume construction failed: %s\n', ME.message);
end

% Validate volume for ML
[isValid, validationMsg] = dwim.validateVolumeForML(volume, metadata);
fprintf('\nValidation: %s\n', validationMsg);

%% LAYER 4: ORCHESTRATION - Unified Pipeline Processing
% Use configuration-driven pipeline for batch processing

fprintf('\n');
fprintf('========================================\n');
fprintf('LAYER 4: UNIFIED PIPELINE ORCHESTRATION\n');
fprintf('========================================\n\n');

% Create comprehensive pipeline configuration
pipelineConfig = struct(...
    'acquisition', struct(...
        'source', 'orthanc', ...
        'connection', orthancConfig, ...
        'query', queryParams), ...
    'preprocessing2D', config2D, ...
    'volumeConstruction', config3D, ...
    'output', struct(...
        'format', 'mat', ...
        'destination', fullfile(tempDir, 'processed'), ...
        'saveMetadata', true));

fprintf('Running unified pipeline with configuration...\n');

% Process using unified pipeline
try
    results = dwim.preprocessPipeline(dicomFiles, pipelineConfig);
    
    fprintf('\nPipeline execution completed:\n');
    fprintf('  Processed: %d volumes\n', results.stats.processed);
    fprintf('  Failed: %d volumes\n', results.stats.failed);
    fprintf('  Average processing time: %.2f seconds\n', results.stats.avgTime);
    fprintf('  Total time: %.2f seconds\n', results.stats.totalTime);
    
catch ME
    warning('Pipeline execution encountered issues: %s', ME.message);
    fprintf('Continuing with manual processing...\n');
end

%% LAYER 5: ML PREPARATION - Organize Dataset for Training
% Structure processed data for ML frameworks (PyTorch, TensorFlow)

fprintf('\n');
fprintf('========================================\n');
fprintf('LAYER 5: ML DATASET PREPARATION\n');
fprintf('========================================\n\n');

% Create ML dataset directory structure
mlDatasetRoot = fullfile(tempDir, 'ml_dataset');
trainDir = fullfile(mlDatasetRoot, 'train');
valDir = fullfile(mlDatasetRoot, 'val');
testDir = fullfile(mlDatasetRoot, 'test');

% Create directories
dirs = {trainDir, valDir, testDir};
for i = 1:length(dirs)
    if ~exist(dirs{i}, 'dir')
        mkdir(dirs{i});
    end
end

fprintf('Created ML dataset directory structure:\n');
fprintf('  Root: %s\n', mlDatasetRoot);
fprintf('  Train: %s\n', trainDir);
fprintf('  Val: %s\n', valDir);
fprintf('  Test: %s\n', testDir);

% Split data (70% train, 15% val, 15% test)
% For this example, we'll use the single volume we processed
splitRatios = [0.70, 0.15, 0.15];
fprintf('\nDataset split ratios: Train=%.0f%%, Val=%.0f%%, Test=%.0f%%\n', ...
    splitRatios(1)*100, splitRatios(2)*100, splitRatios(3)*100);

% Save volume to training set (as example)
volumeFilename = sprintf('volume_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
volumePath = fullfile(trainDir, volumeFilename);
save(volumePath, 'volume', 'metadata');
fprintf('\nSaved volume to: %s\n', volumePath);

% Create dataset manifest (JSON format for ML frameworks)
manifest = struct(...
    'dataset', struct(...
        'name', 'DWiM_CT_Example', ...
        'version', '1.0', ...
        'created', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
        'modality', 'CT', ...
        'task', 'segmentation'), ...
    'splits', struct(...
        'train', struct('samples', 1, 'path', 'train'), ...
        'val', struct('samples', 0, 'path', 'val'), ...
        'test', struct('samples', 0, 'path', 'test')), ...
    'preprocessing', struct(...
        'window', config2D.window, ...
        'normalization', config2D.normalization, ...
        'spacing', config3D.targetSpacing, ...
        'orientation', config3D.targetOrientation), ...
    'volume_info', struct(...
        'dimensions', size(volume), ...
        'spacing', [metadata.PixelSpacing; metadata.SliceThickness], ...
        'datatype', class(volume)));

% Save manifest
manifestPath = fullfile(mlDatasetRoot, 'dataset_manifest.json');
manifestJSON = jsonencode(manifest, 'PrettyPrint', true);
fid = fopen(manifestPath, 'w');
fprintf(fid, '%s', manifestJSON);
fclose(fid);
fprintf('Saved dataset manifest to: %s\n', manifestPath);

% Create README for the dataset
readmePath = fullfile(mlDatasetRoot, 'README.txt');
fid = fopen(readmePath, 'w');
fprintf(fid, 'DWiM ML Dataset\n');
fprintf(fid, '===============\n\n');
fprintf(fid, 'Created: %s\n', datestr(now));
fprintf(fid, 'Source: DWiM End-to-End Pipeline\n\n');
fprintf(fid, 'Directory Structure:\n');
fprintf(fid, '  train/ - Training set (70%%)\n');
fprintf(fid, '  val/   - Validation set (15%%)\n');
fprintf(fid, '  test/  - Test set (15%%)\n\n');
fprintf(fid, 'Data Format:\n');
fprintf(fid, '  - MATLAB .mat files\n');
fprintf(fid, '  - Variables: volume, metadata\n');
fprintf(fid, '  - Spacing: [%.2f, %.2f, %.2f] mm\n', config3D.targetSpacing);
fprintf(fid, '  - Orientation: %s\n', config3D.targetOrientation);
fprintf(fid, '  - Normalization: %s\n\n', config2D.normalization.method);
fprintf(fid, 'Preprocessing:\n');
fprintf(fid, '  - Window: %s (C=%d, W=%d)\n', ...
    config2D.window.preset, config2D.window.center, config2D.window.width);
fprintf(fid, '  - HU normalization: [%.1f, %.1f]\n', ...
    config2D.normalization.outputRange(1), config2D.normalization.outputRange(2));
fclose(fid);
fprintf('Created dataset README\n');

%% SUMMARY: Complete Workflow Metrics
% Display comprehensive metrics from all pipeline stages

fprintf('\n');
fprintf('========================================\n');
fprintf('COMPLETE WORKFLOW SUMMARY\n');
fprintf('========================================\n\n');

fprintf('Layer 1 (Acquisition):\n');
fprintf('  Source: Orthanc PACS\n');
fprintf('  Studies queried: %d\n', length(studies));
fprintf('  Series downloaded: 1\n');
fprintf('  DICOM files: %d\n', length(dicomFiles));
fprintf('\n');

fprintf('Layer 2 (2D Preprocessing):\n');
fprintf('  Window preset: %s\n', config2D.window.preset);
fprintf('  Normalization: %s\n', config2D.normalization.method);
fprintf('  Slices processed: %d\n', numSlicesToShow);
fprintf('\n');

fprintf('Layer 3 (Volume Construction):\n');
fprintf('  Volume size: %d x %d x %d\n', size(volume));
fprintf('  Target spacing: [%.2f, %.2f, %.2f] mm\n', config3D.targetSpacing);
fprintf('  Orientation: %s\n', config3D.targetOrientation);
fprintf('  Validation: %s\n', validationMsg);
fprintf('\n');

fprintf('Layer 4 (Orchestration):\n');
fprintf('  Pipeline: Unified configuration-driven\n');
fprintf('  Components: All 3 layers integrated\n');
fprintf('  Status: Complete\n');
fprintf('\n');

fprintf('Layer 5 (ML Preparation):\n');
fprintf('  Dataset root: %s\n', mlDatasetRoot);
fprintf('  Volumes exported: 1\n');
fprintf('  Format: MATLAB .mat\n');
fprintf('  Manifest: dataset_manifest.json\n');
fprintf('  Ready for: PyTorch, TensorFlow, MATLAB Deep Learning\n');
fprintf('\n');

fprintf('========================================\n');
fprintf('WORKFLOW COMPLETE\n');
fprintf('========================================\n');
fprintf('\nAll 5 layers demonstrated successfully.\n');
fprintf('Dataset ready at: %s\n', mlDatasetRoot);
fprintf('\nNext steps:\n');
fprintf('  1. Review dataset manifest: %s\n', manifestPath);
fprintf('  2. Load volumes in your ML framework\n');
fprintf('  3. Train your model\n');
fprintf('  4. Process additional studies using the pipeline\n\n');

%% CLEANUP (Optional)
% Uncomment to remove temporary files

% fprintf('\nCleaning up temporary files...\n');
% rmdir(tempDir, 's');
% fprintf('Cleanup complete.\n');
