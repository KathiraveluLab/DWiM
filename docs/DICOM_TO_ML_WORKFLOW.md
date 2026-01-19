# Complete DICOM to ML Workflow Guide

This guide demonstrates the complete workflow from DICOM acquisition through ML-ready dataset preparation using DWiM.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: DICOM Acquisition](#step-1-dicom-acquisition)
4. [Step 2: 2D Preprocessing](#step-2-2d-preprocessing)
5. [Step 3: 3D Volume Construction](#step-3-3d-volume-construction)
6. [Step 4: ML Dataset Preparation](#step-4-ml-dataset-preparation)
7. [Step 5: ML Framework Integration](#step-5-ml-framework-integration)
8. [Complete Example](#complete-example)
9. [Best Practices](#best-practices)

## Overview

DWiM provides a complete pipeline for converting DICOM medical images into ML-ready datasets:

```
DICOM Files → 2D Preprocessing → 3D Volume → Dataset Builder → ML Framework
```

**Pipeline Layers:**
- **Layer 1**: Acquisition (Orthanc PACS integration)
- **Layer 2**: 2D Preprocessing (windowing, normalization)
- **Layer 3**: 3D Volume Construction (assembly, resampling, orientation)
- **Layer 4**: Orchestration (unified configuration-driven pipeline)
- **Layer 5**: ML Preparation (train/val/test splits, batch export)

## Prerequisites

**MATLAB Requirements:**
- MATLAB R2020a or later
- Image Processing Toolbox
- Medical Imaging Toolbox (recommended)

**Optional Components:**
- Orthanc PACS server (for DICOM acquisition)
- Python with PyTorch or TensorFlow (for ML framework integration)

**Installation:**
```matlab
addpath('path/to/DWiM');
```

## Step 1: DICOM Acquisition

### Option A: From Orthanc PACS

Connect to your Orthanc server and query for studies:

```matlab
% Connect to Orthanc
orthanc = dwim.utils.connectToOrthanc('http://localhost:8042', 'username', 'password');

% Query for patient studies
studies = orthanc.getStudies('PatientID', 'P001');

% Download specific series
seriesUID = studies(1).Series(1).SeriesInstanceUID;
dicomFiles = orthanc.downloadSeries(seriesUID, 'output/dicom_data/');
```

### Option B: From Local Directory

```matlab
% Specify directory containing DICOM files
dicomDir = 'data/patient_scans/ct_series/';

% DWiM automatically discovers and validates DICOM files
```

## Step 2: 2D Preprocessing

Apply windowing and normalization to individual DICOM slices:

```matlab
% Configure 2D preprocessing
config2D = struct();
config2D.window = struct('preset', 'lung', 'center', -600, 'width', 1500);
config2D.normalization = struct('method', 'HU', 'outputRange', [0, 1]);

% Process individual slice
dicomInfo = dicominfo(dicomFiles{1});
slice = dicomread(dicomFiles{1});

% Apply window preset
windowedSlice = dwim.preprocess.applyWindowPreset(slice, dicomInfo, ...
    'preset', config2D.window.preset);

% Normalize Hounsfield Units
normalizedSlice = dwim.preprocess.normalizeHU(windowedSlice, dicomInfo, ...
    'outputRange', config2D.normalization.outputRange);
```

**Common Window Presets:**
- Lung: C=-600, W=1500
- Mediastinum: C=50, W=350
- Bone: C=400, W=1800
- Brain: C=40, W=80
- Abdomen: C=40, W=400

## Step 3: 3D Volume Construction

Assemble 2D slices into 3D volumes with proper orientation and spacing:

```matlab
% Build volume from DICOM series
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries(dicomDir, ...
    'TargetOrientation', 'RAS', ...     % Right-Anterior-Superior
    'TargetSpacing', 1.0, ...           % Isotropic 1mm spacing
    'Validate', true);                   % Run validation checks

fprintf('Volume size: %d x %d x %d\n', size(volume));
fprintf('Spacing: [%.2f, %.2f, %.2f] mm\n', spacing);
fprintf('Orientation: %s\n', metadata.Orientation);

% Validate volume for ML
[isValid, issues] = dwim.preprocess3d.validateVolumeForML(volume, metadata);
if ~isValid
    warning('Volume validation issues: %s', strjoin(issues, ', '));
end
```

### Volume Processing Options

**Orientation Standards:**
- `RAS`: Right-Anterior-Superior (neuroimaging standard)
- `LPS`: Left-Posterior-Superior (DICOM standard)
- `LAS`: Left-Anterior-Superior (alternative)

**Spacing Options:**
- Isotropic: `TargetSpacing = 1.0` (single value)
- Anisotropic: `TargetSpacing = [1.0, 1.0, 2.0]` (preserve slice thickness)

## Step 4: ML Dataset Preparation

Use DatasetBuilder to create train/validation/test splits:

```matlab
% Initialize dataset builder
builder = dwim.ml.DatasetBuilder('output/ml_dataset');

% Configure dataset parameters
builder.setSplitRatios([0.7, 0.15, 0.15]);  % 70% train, 15% val, 15% test
builder.setTargetSize([128, 128, 64]);       % Resize to fixed dimensions
builder.setNormalization('minmax');          % Normalize to [0, 1]
builder.setFormat('mat');                    % Output format: mat, nifti, hdf5
builder.setBatchSize(8);                     % Volumes per batch file

% Add volumes with labels
volumes = {volume1, volume2, volume3, volume4, volume5};
metadata = {
    struct('patientID', 'P001', 'label', 0, 'diagnosis', 'healthy');
    struct('patientID', 'P002', 'label', 1, 'diagnosis', 'diseased');
    struct('patientID', 'P003', 'label', 0, 'diagnosis', 'healthy');
    struct('patientID', 'P004', 'label', 1, 'diagnosis', 'diseased');
    struct('patientID', 'P005', 'label', 0, 'diagnosis', 'healthy');
};
builder.addVolumes(volumes, metadata);

% Build dataset with automatic splitting
builder.build();

fprintf('Dataset created:\n');
fprintf('  Train: %d volumes\n', length(builder.TrainIndices));
fprintf('  Val: %d volumes\n', length(builder.ValIndices));
fprintf('  Test: %d volumes\n', length(builder.TestIndices));

% Validate dataset integrity
[isValid, report] = builder.validateIntegrity();
if isValid
    fprintf('Dataset validation: PASSED\n');
else
    fprintf('Dataset validation: FAILED\n%s\n', report);
end
```

### Normalization Methods

**Available Methods:**
1. **minmax**: Scale to [0, 1] range
   ```matlab
   builder.setNormalization('minmax');
   ```

2. **zscore**: Zero mean, unit variance
   ```matlab
   builder.setNormalization('zscore');
   ```

3. **HU**: Hounsfield Unit windowing
   ```matlab
   builder.setNormalization('HU', 'WindowCenter', 40, 'WindowWidth', 400);
   ```

4. **percentile**: Clip outliers using percentiles
   ```matlab
   builder.setNormalization('percentile', 'LowerPercentile', 1, 'UpperPercentile', 99);
   ```

### Export Formats

**MAT Format** (default):
```matlab
builder.setFormat('mat');
% Output: batch_001.mat with variables: volumes, labels, metadata
```

**NIfTI Format**:
```matlab
builder.setFormat('nifti');
% Output: volume_001.nii, volume_002.nii, ...
```

**HDF5 Format**:
```matlab
builder.setFormat('hdf5');
% Output: batch_001.h5 with datasets: /volumes, /labels, /metadata
```

## Step 5: ML Framework Integration

### PyTorch Integration

```python
import torch
import numpy as np
from torch.utils.data import Dataset, DataLoader, TensorDataset
import scipy.io

# Load training batch
batch = scipy.io.loadmat('ml_dataset/train/batch_001.mat')
# batch['volumes'] from MATLAB is typically shaped [H, W, D, N].
volumes_np = np.transpose(batch['volumes'], (3, 0, 1, 2))  # Shape: [N, H, W, D]
# Convert to PyTorch's expected [N, C, H, W, D].
volumes = torch.from_numpy(volumes_np).float().unsqueeze(1)  # Shape: [N, 1, H, W, D]
labels = torch.LongTensor(batch['labels'].flatten())

# Create dataset and dataloader
dataset = TensorDataset(volumes, labels)
train_loader = DataLoader(dataset, batch_size=4, shuffle=True, num_workers=2)

# Training loop
for batch_idx, (data, target) in enumerate(train_loader):
    # data shape: [batch_size, channels, height, width, depth]
    # target shape: [batch_size]
    pass
```

### TensorFlow Integration

```python
import tensorflow as tf
import scipy.io
import numpy as np

# Load training batch
batch = scipy.io.loadmat('ml_dataset/train/batch_001.mat')
# batch['volumes'] from MATLAB is typically shaped [H, W, D, N]. Transpose to [N, H, W, D].
volumes = np.transpose(batch['volumes'], (3, 0, 1, 2))
labels = batch['labels'].flatten()

# Create tf.data.Dataset, add channel dim, shuffle, batch, and prefetch.
dataset = tf.data.Dataset.from_tensor_slices((volumes, labels))
dataset = dataset.map(lambda vol, label: (tf.expand_dims(vol, axis=-1), label)).shuffle(buffer_size=100).batch(4).prefetch(tf.data.AUTOTUNE)

# Training loop
for batch_volumes, batch_labels in dataset:
    # batch_volumes shape: [batch_size, height, width, depth]
    # batch_labels shape: [batch_size]
    pass
```

### MATLAB Deep Learning

```matlab
% Load training batch
batch = load('ml_dataset/train/batch_001.mat');
volumes = batch.volumes;  % Shape is [H, W, D, N]
labels = categorical(batch.labels);

% Reshape to include channel dimension: [H, W, D, C, N]
volumes = reshape(volumes, [size(volumes,1), size(volumes,2), size(volumes,3), 1, size(volumes,4)]);

% Create datastores, iterating over the 5th dimension (samples)
volDS = arrayDatastore(volumes, 'IterationDimension', 5);
lblDS = arrayDatastore(labels);
ds = combine(volDS, lblDS);

% Create 3D CNN layers
layers = [
    image3dInputLayer([128 128 64 1])
    convolution3dLayer(3, 32, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    maxPooling3dLayer(2, 'Stride', 2)
    % ... additional layers
    fullyConnectedLayer(2)
    softmaxLayer
    classificationLayer
];

% Training options
options = trainingOptions('adam', ...
    'MaxEpochs', 20, ...
    'MiniBatchSize', 4, ...
    'Plots', 'training-progress');

% Train network
net = trainNetwork(ds, layers, options);
```

## Complete Example

Here's a complete end-to-end example processing DICOM to ML-ready dataset:

```matlab
%% COMPLETE DICOM TO ML WORKFLOW
% From raw DICOM files to ML framework integration

%% Step 1: Setup
addpath('path/to/DWiM');
dicomDir = 'data/ct_scans/series_001/';
outputDir = 'output/ml_ready/';

%% Step 2: Configure Unified Pipeline
config = dwim.preprocessPipeline_config();
config.inputType = 'dicomdir';
config.steps = {'assemble', 'orient', 'resample'};
config.targetOrientation = 'RAS';
config.targetSpacing = 1.0;
config.window.preset = 'lung';
config.normalization.method = 'HU';
config.normalization.outputRange = [0, 1];

%% Step 3: Process Multiple Series
seriesDirs = {'series_001/', 'series_002/', 'series_003/', 'series_004/', 'series_005/'};
volumes = cell(1, length(seriesDirs));
metadataList = cell(1, length(seriesDirs));

for i = 1:length(seriesDirs)
    fullPath = fullfile('data/ct_scans', seriesDirs{i});
    [volumes{i}, metadataList{i}] = dwim.preprocessPipeline(fullPath, config);
    fprintf('Processed %s: Volume size [%d %d %d]\n', ...
        seriesDirs{i}, size(volumes{i}));
end

%% Step 4: Create ML Dataset
builder = dwim.ml.DatasetBuilder(outputDir);
builder.setSplitRatios([0.7, 0.15, 0.15]);
builder.setTargetSize([128, 128, 64]);
builder.setNormalization('minmax');
builder.setFormat('mat');
builder.setBatchSize(2);

% Add volumes with labels
labels = {
    struct('patientID', 'P001', 'label', 0);
    struct('patientID', 'P002', 'label', 1);
    struct('patientID', 'P003', 'label', 0);
    struct('patientID', 'P004', 'label', 1);
    struct('patientID', 'P005', 'label', 0);
};
builder.addVolumes(volumes, labels);

% Build and validate
builder.build();
[isValid, report] = builder.validateIntegrity();

fprintf('\nDataset Summary:\n');
fprintf('  Output: %s\n', outputDir);
fprintf('  Train: %d volumes\n', length(builder.TrainIndices));
fprintf('  Val: %d volumes\n', length(builder.ValIndices));
fprintf('  Test: %d volumes\n', length(builder.TestIndices));
if isValid
    fprintf('  Validation: PASSED\n');
else
    fprintf('  Validation: FAILED\n');
end

%% Step 5: Ready for ML Training
fprintf('\nDataset ready for ML frameworks:\n');
fprintf('  PyTorch: See examples/04_ml_dataset_builder/README.md\n');
fprintf('  TensorFlow: See examples/04_ml_dataset_builder/README.md\n');
fprintf('  MATLAB: Use arrayDatastore with combine()\n');
```

## Best Practices

### DICOM Handling
- **Validate Series**: Always check that all slices belong to the same series
- **Orientation**: Standardize to RAS for consistency across datasets
- **Spacing**: Use isotropic spacing (1mm) for rotation-invariant models
- **Metadata**: Preserve original DICOM metadata for traceability

### Volume Processing
- **Quality Checks**: Run `validateVolumeForML()` before dataset creation
- **Memory Management**: Process large datasets in batches
- **Slice Ordering**: Trust DWiM's automatic ordering using `ImagePositionPatient`
- **Interpolation**: Linear interpolation is default; use 'nearest' for labels

### Dataset Preparation
- **Split Ratios**: Standard is 70/15/15 or 80/10/10 for train/val/test
- **Normalization**: Choose based on task (minmax for general, HU for clinical)
- **Batch Size**: Balance memory usage and I/O efficiency (8-16 typical)
- **Validation**: Always run `validateIntegrity()` before training

### ML Integration
- **Data Augmentation**: Apply during training, not in dataset preparation
- **Format Choice**: MAT for MATLAB, HDF5 for Python, NIfTI for compatibility
- **Metadata**: Use JSON manifests to track preprocessing parameters
- **Version Control**: Tag dataset versions with preprocessing configuration

### Performance Optimization
- **Parallel Processing**: Use `parfor` for multiple series
- **Caching**: Cache preprocessed volumes to avoid recomputation
- **Storage**: HDF5 format offers better compression for large datasets
- **Monitoring**: Track memory usage with large 3D volumes

## Troubleshooting

### Common Issues

**Issue: Inconsistent slice spacing**
```matlab
% Solution: Use automatic resampling
[volume, spacing] = dwim.preprocess3d.buildVolumeFromSeries(dicomDir, ...
    'TargetSpacing', 1.0);
```

**Issue: Wrong orientation**
```matlab
% Solution: Specify target orientation
[volume, ~, metadata] = dwim.preprocess3d.buildVolumeFromSeries(dicomDir, ...
    'TargetOrientation', 'RAS');
```

**Issue: Memory errors with large volumes**
```matlab
% Solution: Use smaller batch sizes
builder.setBatchSize(4);  % Reduce from default 8
```

**Issue: Split ratios don't match exactly**
```matlab
% This is expected with small datasets
% Example: 10 volumes with [0.7, 0.15, 0.15] = 7/1/2 split
% Use floor() logic ensures accurate splits
```

## Next Steps

1. **Explore Examples**: Check `examples/` directory for more use cases
2. **Architecture Guide**: Read `ARCHITECTURE.md` for detailed layer descriptions
3. **API Reference**: See function help documentation (`help dwim.ml.DatasetBuilder`)
4. **Custom Preprocessing**: Extend pipeline with custom processing steps
5. **Production Deployment**: Scale to large datasets with batch processing

## Additional Resources

- **Project Repository**: https://github.com/KathiraveluLab/DWiM
- **TCIA Data**: https://www.cancerimagingarchive.net/
- **Orthanc PACS**: https://www.orthanc-server.com/
- **MATLAB Documentation**: https://www.mathworks.com/products/image.html
- **DICOM Standard**: https://www.dicomstandard.org/

---

**Last Updated**: January 19, 2026  
**Version**: 1.0  
**Maintainer**: DWiM Development Team
