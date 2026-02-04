% DICOM to ML Dataset Example
%
% This example demonstrates how to use the DWiM ML Dataset Builder
% to convert preprocessed DICOM volumes into structured ML datasets.
%
% WORKFLOW:
%   1. Connect to Orthanc and retrieve DICOM data
%   2. Preprocess volumes using DWiM pipeline
%   3. Build ML dataset with train/val/test splits
%   4. Validate dataset integrity
%   5. Export for PyTorch/TensorFlow
%
% REQUIREMENTS:
%   - Orthanc PACS server with DICOM data
%   - DWiM preprocessing pipeline
%   - Medical Imaging Toolbox
%
% Author: DWiM Team
% Date: 2026-01-17

clear; clc;
addpath(genpath('../../+dwim'));

%% STEP 1: Acquire DICOM Data from Orthanc

fprintf('\n========================================\n');
fprintf('STEP 1: DICOM ACQUISITION\n');
fprintf('========================================\n\n');

% Connect to Orthanc
orthancConfig = struct(...
    'url', 'http://localhost:8042', ...
    'username', 'orthanc', ...
    'password', 'orthanc');

try
    conn = dwim.connectToOrthanc(orthancConfig);
    fprintf('Connected to Orthanc at %s\n', orthancConfig.url);
catch ME
    error('Failed to connect to Orthanc: %s\nPlease ensure Orthanc is running.', ME.message);
end

% Query for CT studies
queryParams = struct(...
    'Modality', 'CT', ...
    'Level', 'Study');

studies = conn.query(queryParams);
fprintf('Found %d CT studies\n', length(studies));

if isempty(studies)
    error('No studies found. Please upload DICOM data to Orthanc.');
end

% Download first few series for demonstration
numSeriesToProcess = min(5, length(studies));
fprintf('Processing first %d series...\n\n', numSeriesToProcess);

%% STEP 2: Preprocess Volumes

fprintf('========================================\n');
fprintf('STEP 2: PREPROCESSING VOLUMES\n');
fprintf('========================================\n\n');

% Create temporary directory for preprocessing
tempDir = fullfile(tempdir, 'dwim_ml_example');
if ~exist(tempDir, 'dir')
    mkdir(tempDir);
end
preprocessDir = fullfile(tempDir, 'preprocessed');
if ~exist(preprocessDir, 'dir')
    mkdir(preprocessDir);
end

% Configure preprocessing pipeline
pipelineConfig = struct(...
    'preprocessing2D', struct(...
        'window', struct('preset', 'lung', 'center', -600, 'width', 1500), ...
        'normalization', struct('method', 'hu', 'outputRange', [0, 1])), ...
    'volumeConstruction', struct(...
        'targetSpacing', [1.5, 1.5, 2.0], ...
        'targetOrientation', 'RAS', ...
        'interpolation', 'linear'));

% Process each series
volumeFiles = {};
volumeLabels = {};
volumeMetadata = {};

for i = 1:numSeriesToProcess
    fprintf('Processing series %d/%d...\n', i, numSeriesToProcess);
    
    try
        % Get series
        studyID = studies(i).ID;
        series = conn.getSeries(studyID);
        
        if isempty(series)
            continue;
        end
        
        % Download DICOM files
        seriesID = series(1).ID;
        seriesDir = fullfile(tempDir, sprintf('series_%d', i));
        dicomFiles = conn.retrieveSeries(seriesID, seriesDir);
        
        % Build volume
        [volume, metadata] = dwim.buildVolumeFromSeries(dicomFiles, pipelineConfig.volumeConstruction);
        
        % Save preprocessed volume
        volumeFile = fullfile(preprocessDir, sprintf('volume_%03d.mat', i));
        save(volumeFile, 'volume', 'metadata');
        
        % Add to lists
        volumeFiles{end+1} = volumeFile;
        volumeLabels{end+1} = studies(i).StudyDescription; % Use study description as label
        volumeMetadata{end+1} = metadata;
        
        fprintf('  Saved: %s (Size: %dx%dx%d)\n', volumeFile, ...
            size(volume, 1), size(volume, 2), size(volume, 3));
        
    catch ME
        warning('Failed to process series %d: %s', i, ME.message);
    end
end

fprintf('\nPreprocessed %d volumes\n\n', length(volumeFiles));

%% STEP 3: Build ML Dataset

fprintf('========================================\n');
fprintf('STEP 3: BUILDING ML DATASET\n');
fprintf('========================================\n\n');

% Create dataset output directory
datasetDir = fullfile(tempDir, 'ml_dataset');

% Initialize dataset builder
builder = dwim.ml.DatasetBuilder(datasetDir, ...
    'DatasetName', 'CT_Lung_Dataset', ...
    'TargetSize', [256, 256, 128], ...
    'TargetSpacing', [1.0, 1.0, 1.0], ...
    'Normalization', 'minmax', ...
    'Range', [0, 1], ...
    'Format', 'mat', ...
    'BatchSize', 2, ...
    'Seed', 42);

fprintf('Dataset Builder Initialized:\n');
fprintf('  Output: %s\n', datasetDir);
fprintf('  Target size: [%d, %d, %d]\n', 256, 256, 128);
fprintf('  Target spacing: [%.1f, %.1f, %.1f] mm\n', 1.0, 1.0, 1.0);
fprintf('  Normalization: minmax -> [0, 1]\n\n');

% Add volumes to builder
fprintf('Adding %d volumes to dataset...\n', length(volumeFiles));
builder.addVolumes(volumeFiles, volumeLabels, volumeMetadata);

% Set split ratios (70% train, 15% val, 15% test)
builder.setSplitRatios([0.70, 0.15, 0.15]);
fprintf('Split ratios: Train=70%%, Val=15%%, Test=15%%\n\n');

% Build the dataset
builder.build();

%% STEP 4: Validate Dataset

fprintf('\n========================================\n');
fprintf('STEP 4: DATASET VALIDATION\n');
fprintf('========================================\n\n');

% Run integrity checks
[isValid, report] = builder.validateIntegrity();

fprintf('Validation Report:\n');
fprintf('%s\n', report);

if isValid
    fprintf('\n[OK] Dataset validation passed!\n');
else
    warning('Dataset validation found issues. Check report above.');
end

%% STEP 5: Dataset Information

fprintf('\n========================================\n');
fprintf('STEP 5: DATASET SUMMARY\n');
fprintf('========================================\n\n');

% Load and display manifest
manifestPath = fullfile(datasetDir, 'manifest.json');
manifest = jsondecode(fileread(manifestPath));

fprintf('Dataset: %s\n', manifest.dataset.name);
fprintf('Created: %s\n', manifest.dataset.created);
fprintf('Total samples: %d\n', manifest.dataset.total_samples);
fprintf('\n');

fprintf('Data splits:\n');
fprintf('  Train: %d samples (%s)\n', manifest.splits.train.samples, manifest.splits.train.path);
fprintf('  Val:   %d samples (%s)\n', manifest.splits.val.samples, manifest.splits.val.path);
fprintf('  Test:  %d samples (%s)\n', manifest.splits.test.samples, manifest.splits.test.path);
fprintf('\n');

fprintf('Preprocessing:\n');
fprintf('  Target size: [%d, %d, %d]\n', ...
    manifest.preprocessing.target_size(1), ...
    manifest.preprocessing.target_size(2), ...
    manifest.preprocessing.target_size(3));
fprintf('  Target spacing: [%.1f, %.1f, %.1f] mm\n', ...
    manifest.preprocessing.target_spacing(1), ...
    manifest.preprocessing.target_spacing(2), ...
    manifest.preprocessing.target_spacing(3));
fprintf('  Normalization: %s -> [%.1f, %.1f]\n', ...
    manifest.preprocessing.normalization, ...
    manifest.preprocessing.normalization_range(1), ...
    manifest.preprocessing.normalization_range(2));
fprintf('\n');

fprintf('Output format: %s (batch size: %d)\n', ...
    manifest.format.type, manifest.format.batch_size);

%% STEP 6: Load Sample Data

fprintf('\n========================================\n');
fprintf('STEP 6: LOADING SAMPLE DATA\n');
fprintf('========================================\n\n');

% Load first training batch
trainDir = fullfile(datasetDir, 'train');
batchFiles = dir(fullfile(trainDir, 'batch_*.mat'));

if ~isempty(batchFiles)
    batchPath = fullfile(trainDir, batchFiles(1).name);
    fprintf('Loading: %s\n', batchPath);
    
    batch = load(batchPath);
    
    fprintf('Batch contents:\n');
    fprintf('  Volumes: %d x %d x %d x %d\n', size(batch.volumes));
    fprintf('  Labels: %d samples\n', length(batch.labels));
    fprintf('  Metadata: %d entries\n', length(batch.metadata));
    fprintf('\n');
    
    fprintf('Sample volume statistics:\n');
    sampleVol = batch.volumes(:,:,:,1);
    fprintf('  Min: %.4f\n', min(sampleVol(:)));
    fprintf('  Max: %.4f\n', max(sampleVol(:)));
    fprintf('  Mean: %.4f\n', mean(sampleVol(:)));
    fprintf('  Std: %.4f\n', std(sampleVol(:)));
end

%% STEP 7: Export Instructions

fprintf('\n========================================\n');
fprintf('STEP 7: USING THE DATASET\n');
fprintf('========================================\n\n');

fprintf('Your ML dataset is ready at:\n');
fprintf('  %s\n\n', datasetDir);

fprintf('PyTorch Example:\n');
fprintf('  import scipy.io\n');
fprintf('  data = scipy.io.loadmat(''%s'')\n', strrep(batchPath, '\', '/'));
fprintf('  volumes = data[''volumes'']\n');
fprintf('  labels = data[''labels'']\n\n');

fprintf('TensorFlow Example:\n');
fprintf('  import scipy.io\n');
fprintf('  data = scipy.io.loadmat(''%s'')\n', strrep(batchPath, '\', '/'));
fprintf('  volumes = tf.convert_to_tensor(data[''volumes''])\n\n');

fprintf('MATLAB Deep Learning:\n');
fprintf('  batch = load(''%s'');\n', batchPath);
fprintf('  volumes = batch.volumes;\n');
fprintf('  labels = categorical(batch.labels);\n\n');

fprintf('Dataset Structure:\n');
fprintf('  dataset/\n');
fprintf('    train/         - Training samples (70%%)\n');
fprintf('    val/           - Validation samples (15%%)\n');
fprintf('    test/          - Test samples (15%%)\n');
fprintf('    manifest.json  - Dataset metadata and configuration\n\n');

fprintf('Next Steps:\n');
fprintf('  1. Review manifest.json for dataset details\n');
fprintf('  2. Load batches in your ML framework\n');
fprintf('  3. Build and train your model\n');
fprintf('  4. Add more volumes with builder.addVolumes()\n\n');

%% CLEANUP (Optional)

% Uncomment to remove temporary files
% fprintf('Cleaning up temporary files...\n');
% rmdir(tempDir, 's');
% fprintf('Cleanup complete.\n');

fprintf('========================================\n');
fprintf('EXAMPLE COMPLETE\n');
fprintf('========================================\n\n');
