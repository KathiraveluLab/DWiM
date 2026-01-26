# Dataset Validation Example

This example demonstrates comprehensive validation and integrity checks for ML datasets using DWiM's `DatasetValidator` class.

## Overview

Before training machine learning models, it's critical to validate your dataset for:
- File integrity and readability
- Shape consistency across samples
- Label distribution and class balance
- Data quality (NaN, Inf, outliers)
- Proper normalization
- Cross-split contamination (data leakage)

## Quick Start

```matlab
% Run the example
run('example_dataset_validation.m')
```

## What Gets Validated

### 1. File Integrity
- All expected files exist
- Files are readable and not corrupted
- Directory structure is correct

### 2. Shape Consistency
- All volumes have the same dimensions
- Shapes match expected target size
- No dimension mismatches

### 3. Label Distribution
- Class balance across splits
- Number of samples per label
- Severe imbalance warnings (>10:1 ratio)

### 4. Data Quality
- No NaN (Not a Number) values
- No Inf (Infinity) values
- Sample-based quality checks

### 5. Normalization Verification
- Values within expected range
- Consistent normalization across splits
- Method-specific checks (minmax, zscore, etc.)

### 6. Memory Footprint
- Disk space usage per split
- Total dataset size
- Memory requirements estimation

### 7. Cross-Split Contamination
- No patient overlap between train/val/test
- Prevents data leakage
- Ensures model generalization

## Using the Validator

### Initialize

```matlab
validator = dwim.ml.DatasetValidator('path/to/dataset');
```

### Run Individual Checks

```matlab
% File integrity
fileResult = validator.checkFileIntegrity();

% Shape consistency
shapeResult = validator.checkShapeConsistency();

% Label distribution
labelResult = validator.analyzeLabelDistribution();

% Data quality
qualityResult = validator.checkDataQuality();

% Normalization
normResult = validator.verifyNormalization();

% Memory footprint
memResult = validator.estimateMemoryFootprint();

% Contamination check
contaminationResult = validator.checkCrossSplitContamination();
```

### Run All Checks

```matlab
allResults = validator.runAllChecks();
```

### Generate Report

```matlab
validator.generateReport('validation_report.txt');
```

## Validation Report Example

```
========================================
DATASET VALIDATION REPORT
========================================

Dataset: output/ml_dataset
Generated: 26-Jan-2026 10:30:45

--- FILE INTEGRITY ---
passed: true
missingFiles: {}
corruptedFiles: {}

--- SHAPE CONSISTENCY ---
passed: true
shapes:
  train: [128 128 64]
  val: [128 128 64]
  test: [128 128 64]

--- LABEL DISTRIBUTION ---
passed: true
distribution:
  train:
    labels: [0 1]
    counts: [35 35]
  val:
    labels: [0 1]
    counts: [8 7]

--- DATA QUALITY ---
passed: true
statistics:
  train:
    samples_checked: 5
    nan_count: 0
    inf_count: 0

--- NORMALIZATION ---
passed: true
ranges:
  train: [0.000 1.000]
  val: [0.001 0.999]

--- MEMORY FOOTPRINT ---
totalSize_GB: 2.45
splitSizes_GB:
  train: 1.72
  val: 0.37
  test: 0.36

--- CONTAMINATION ---
passed: true
duplicates: {}

========================================
```

## Common Issues and Solutions

### Issue: Shape Inconsistency
**Problem**: Volumes have different dimensions  
**Solution**: Ensure all volumes use same `TargetSize` during dataset building

### Issue: Class Imbalance
**Problem**: Severe imbalance ratio (>10:1)  
**Solution**: Apply class weighting or data augmentation during training

### Issue: NaN/Inf Values
**Problem**: Invalid values in data  
**Solution**: Check preprocessing pipeline, fix normalization

### Issue: Cross-Split Contamination
**Problem**: Same patients in train and test  
**Solution**: Rebuild dataset with proper patient-level splitting

### Issue: Normalization Out of Range
**Problem**: Values outside expected range  
**Solution**: Verify normalization method and parameters

## Integration with Training

```matlab
% Before training
validator = dwim.ml.DatasetValidator('dataset_path');
report = validator.runAllChecks();

if all(structfun(@(x) x.passed, report))
    fprintf('Dataset validated - starting training...\n');
    % Start training
else
    fprintf('Validation failed - fix issues first\n');
    validator.generateReport('issues.txt');
end
```

## Best Practices

1. **Always validate before training** - Catch issues early
2. **Check after any dataset modifications** - Re-validate if you change preprocessing
3. **Save validation reports** - Track dataset quality over time
4. **Monitor class balance** - Address imbalance before training
5. **Verify no contamination** - Critical for fair model evaluation

## API Reference

### DatasetValidator

**Constructor:**
```matlab
validator = dwim.ml.DatasetValidator(datasetPath)
```

**Methods:**
- `runAllChecks()` - Run all validation checks
- `checkFileIntegrity()` - Verify file existence and readability
- `checkShapeConsistency()` - Check volume dimension consistency
- `analyzeLabelDistribution()` - Analyze class balance
- `checkDataQuality()` - Check for NaN/Inf/outliers
- `verifyNormalization()` - Verify normalization consistency
- `estimateMemoryFootprint()` - Estimate memory requirements
- `checkCrossSplitContamination()` - Detect data leakage
- `generateReport(path)` - Generate detailed validation report

**Properties:**
- `DatasetPath` - Path to dataset root
- `ManifestPath` - Path to manifest.json
- `Manifest` - Loaded manifest data
- `ValidationResults` - All validation results
- `Format` - Dataset format (mat/nifti/hdf5)

## Related Examples

- `04_ml_dataset_builder/` - Creating ML datasets
- `05_end_to_end_complete/` - Complete pipeline with validation
- `QUICK_START_GUIDE.m` - Quick reference for validation

## Additional Resources

- Dataset best practices: `docs/DICOM_TO_ML_WORKFLOW.md`
- ML preparation guide: `examples/04_ml_dataset_builder/README.md`
- Architecture overview: `ARCHITECTURE.md`
