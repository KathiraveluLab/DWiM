# ML Dataset Builder Example

This example demonstrates how to use the DWiM ML Dataset Builder to create structured machine learning datasets from DICOM volumes.

## Overview

The ML Dataset Builder provides a complete solution for converting preprocessed DICOM volumes into datasets ready for PyTorch, TensorFlow, or MATLAB Deep Learning frameworks.

## Features

- **Automated Data Splitting**: Configurable train/validation/test ratios
- **Volume Preprocessing**: Automatic resizing and resampling to target dimensions
- **Intensity Normalization**: Multiple methods (min-max, z-score, HU-based, percentile)
- **Batch Processing**: Efficient handling of large datasets
- **Metadata Tracking**: Complete preservation of DICOM metadata
- **Integrity Validation**: Automated checks for dataset consistency
- **Multiple Export Formats**: MAT, NIfTI, HDF5

## Quick Start

```matlab
% Initialize builder
builder = dwim.ml.DatasetBuilder('output/dataset', ...
    'DatasetName', 'MyDataset', ...
    'TargetSize', [256, 256, 128], ...
    'Normalization', 'minmax');

% Add volumes
builder.addVolumes(volumePaths, labels, metadata);

% Set split ratios
builder.setSplitRatios([0.7, 0.15, 0.15]); % 70% train, 15% val, 15% test

% Build dataset
builder.build();
```

## Complete Example

Run the complete example:

```matlab
run('example_dicom_to_dataset.m')
```

This example:
1. Connects to Orthanc PACS
2. Downloads CT series
3. Preprocesses volumes
4. Builds ML dataset with train/val/test splits
5. Validates dataset integrity
6. Shows how to load data in PyTorch/TensorFlow/MATLAB

## Dataset Structure

The builder creates the following structure:

```
dataset/
├── train/              # Training samples (default 70%)
│   ├── batch_001.mat
│   ├── batch_002.mat
│   └── ...
├── val/                # Validation samples (default 15%)
│   └── batch_001.mat
├── test/               # Test samples (default 15%)
│   └── batch_001.mat
└── manifest.json       # Dataset metadata and configuration
```

## Configuration Options

### Dataset Builder Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `DatasetName` | Name of the dataset | Auto-generated |
| `TargetSize` | Target volume dimensions [H, W, D] | `[256, 256, 128]` |
| `TargetSpacing` | Target voxel spacing [x, y, z] mm | `[1, 1, 1]` |
| `Normalization` | Normalization method | `'minmax'` |
| `Range` | Output range for normalization | `[0, 1]` |
| `Format` | Output format: 'mat', 'nifti', 'hdf5' | `'mat'` |
| `BatchSize` | Volumes per batch file | `10` |
| `Seed` | Random seed for reproducibility | `42` |

### Normalization Methods

- **minmax**: Scales to specified range [min, max]
- **zscore**: Zero mean, unit variance
- **hu**: Hounsfield Unit clipping and normalization
- **percentile**: Clips to 1st/99th percentile

## Usage in ML Frameworks

### PyTorch

```python
import scipy.io
import torch

# Load batch
data = scipy.io.loadmat('dataset/train/batch_001.mat')
volumes = torch.from_numpy(data['volumes'])
labels = data['labels']

# Create DataLoader
dataset = TensorDataset(volumes, labels)
loader = DataLoader(dataset, batch_size=4, shuffle=True)
```

### TensorFlow

```python
import scipy.io
import tensorflow as tf

# Load batch
data = scipy.io.loadmat('dataset/train/batch_001.mat')
volumes = tf.convert_to_tensor(data['volumes'])
labels = data['labels']

# Create dataset
dataset = tf.data.Dataset.from_tensor_slices((volumes, labels))
dataset = dataset.batch(4).shuffle(100)
```

### MATLAB Deep Learning

```matlab
% Load batch
batch = load('dataset/train/batch_001.mat');
volumes = batch.volumes;
labels = categorical(batch.labels);

% Create datastore
ds = arrayDatastore(volumes);
```

## Validation

The builder automatically validates:

- All expected files exist
- Volume dimensions are consistent
- No missing samples
- Metadata alignment
- Batch file integrity

Run validation manually:

```matlab
[isValid, report] = builder.validateIntegrity();
fprintf('%s\n', report);
```

## Advanced Usage

### Custom Split Ratios

```matlab
% 80% train, 10% val, 10% test
builder.setSplitRatios([0.8, 0.1, 0.1]);
```

### Adding Volumes Incrementally

```matlab
% Add first batch
builder.addVolumes(volumePaths1, labels1);

% Add more later
builder.addVolumes(volumePaths2, labels2);

% Build when ready
builder.build();
```

### Multiple Export Formats

```matlab
% Export as NIfTI
builder = dwim.ml.DatasetBuilder('output/nifti_dataset', ...
    'Format', 'nifti');
    
% Export as HDF5
builder = dwim.ml.DatasetBuilder('output/hdf5_dataset', ...
    'Format', 'hdf5');
```

## Manifest File

The `manifest.json` file contains complete dataset metadata:

```json
{
  "dataset": {
    "name": "MyDataset",
    "version": "1.0",
    "created": "2026-01-17 10:30:00",
    "total_samples": 100
  },
  "splits": {
    "train": {"samples": 70, "path": "train"},
    "val": {"samples": 15, "path": "val"},
    "test": {"samples": 15, "path": "test"}
  },
  "preprocessing": {
    "target_size": [256, 256, 128],
    "target_spacing": [1, 1, 1],
    "normalization": "minmax",
    "normalization_range": [0, 1]
  },
  "format": {
    "type": "mat",
    "batch_size": 10
  }
}
```

## Requirements

- MATLAB R2025a or later
- Medical Imaging Toolbox
- Image Processing Toolbox
- Orthanc PACS server (for DICOM acquisition)

## Troubleshooting

### Volume dimensions mismatch

Ensure all input volumes have compatible dimensions or let the builder resize them:

```matlab
builder = dwim.ml.DatasetBuilder(..., 'TargetSize', [256, 256, 128]);
```

### Memory issues with large datasets

Reduce batch size to save smaller files:

```matlab
builder = dwim.ml.DatasetBuilder(..., 'BatchSize', 5);
```

### Validation failures

Check the validation report for specific issues:

```matlab
[isValid, report] = builder.validateIntegrity();
fprintf('%s\n', report);
```

## See Also

- [Complete End-to-End Example](../05_end_to_end_complete/)
- [Quick Start Guide](../QUICK_START_GUIDE.m)
- [Main Documentation](../../README.md)
