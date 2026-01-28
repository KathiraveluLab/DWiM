% EXAMPLE: Dataset Validation and Integrity Checks
%
% This example demonstrates comprehensive dataset validation
% for ML workflows using DWiM's DatasetValidator class.
%
% Author: DWiM Team
% Date: 2026-01-26

%% Setup
clear; clc;

fprintf('========================================\n');
fprintf('DATASET VALIDATION EXAMPLE\n');
fprintf('========================================\n\n');

%% Step 1: Create a sample dataset (or use existing one)

datasetPath = 'output/sample_dataset';

% Option A: Use existing dataset
% datasetPath = 'path/to/your/dataset';

% Option B: Create a quick test dataset
if ~exist(datasetPath, 'dir')
    fprintf('Creating sample dataset for validation demo...\n\n');
    
    % Create sample volumes
    vol1 = rand(64, 64, 32);
    vol2 = rand(64, 64, 32);
    vol3 = rand(64, 64, 32);
    vol4 = rand(64, 64, 32);
    vol5 = rand(64, 64, 32);
    
    volumes = {vol1, vol2, vol3, vol4, vol5};
    
    % Create metadata with labels
    metadata = {
        struct('patientID', 'P001', 'label', 0);
        struct('patientID', 'P002', 'label', 1);
        struct('patientID', 'P003', 'label', 0);
        struct('patientID', 'P004', 'label', 1);
        struct('patientID', 'P005', 'label', 0);
    };
    
    % Build dataset
    builder = dwim.ml.DatasetBuilder(datasetPath);
    builder.setSplitRatios([0.6, 0.2, 0.2]);
    builder.setTargetSize([64, 64, 32]);
    builder.setNormalization('minmax');
    builder.setFormat('mat');
    builder.setBatchSize(2);
    builder.addVolumes(volumes, metadata);
    builder.build();
    
    fprintf('Sample dataset created at: %s\n\n', datasetPath);
end

%% Step 2: Initialize Validator

fprintf('Initializing validator...\n');
validator = dwim.ml.DatasetValidator(datasetPath);
fprintf('  Dataset path: %s\n', validator.DatasetPath);
fprintf('  Format: %s\n\n', validator.Format);

%% Step 3: Run Individual Validation Checks

% File integrity
fprintf('=== Running File Integrity Check ===\n');
fileResult = validator.checkFileIntegrity();
if fileResult.passed
    fprintf('✓ All files exist and are readable\n\n');
else
    fprintf('✗ Issues found:\n');
    for i = 1:length(fileResult.missingFiles)
        fprintf('  - Missing: %s\n', fileResult.missingFiles{i});
    end
    for i = 1:length(fileResult.corruptedFiles)
        fprintf('  - Corrupted: %s\n', fileResult.corruptedFiles{i});
    end
    fprintf('\n');
end

% Shape consistency
fprintf('=== Running Shape Consistency Check ===\n');
shapeResult = validator.checkShapeConsistency();
if shapeResult.passed
    fprintf('✓ All volumes have consistent shapes\n\n');
else
    fprintf('✗ Shape inconsistencies found:\n');
    for i = 1:length(shapeResult.inconsistencies)
        fprintf('  - %s\n', shapeResult.inconsistencies{i});
    end
    fprintf('\n');
end

% Label distribution
fprintf('=== Analyzing Label Distribution ===\n');
labelResult = validator.analyzeLabelDistribution();
splits = fieldnames(labelResult.distribution);
for i = 1:length(splits)
    splitName = splits{i};
    dist = labelResult.distribution.(splitName);
    fprintf('  %s split:\n', splitName);
    for j = 1:length(dist.labels)
        fprintf('    Label %d: %d samples\n', dist.labels(j), dist.counts(j));
    end
end
if ~isempty(labelResult.warnings)
    fprintf('  ⚠ Warnings:\n');
    for i = 1:length(labelResult.warnings)
        fprintf('    - %s\n', labelResult.warnings{i});
    end
end
fprintf('\n');

% Data quality
fprintf('=== Running Data Quality Check ===\n');
qualityResult = validator.checkDataQuality();
if qualityResult.passed
    fprintf('✓ No NaN or Inf values detected\n\n');
else
    fprintf('✗ Data quality issues:\n');
    for i = 1:length(qualityResult.issues)
        fprintf('  - %s\n', qualityResult.issues{i});
    end
    fprintf('\n');
end

% Normalization verification
fprintf('=== Verifying Normalization ===\n');
normResult = validator.verifyNormalization();
splits = fieldnames(normResult.ranges);
for i = 1:length(splits)
    splitName = splits{i};
    range = normResult.ranges.(splitName);
    fprintf('  %s: [%.3f, %.3f]\n', splitName, range(1), range(2));
end
if ~isempty(normResult.warnings)
    fprintf('  ⚠ Warnings:\n');
    for i = 1:length(normResult.warnings)
        fprintf('    - %s\n', normResult.warnings{i});
    end
end
fprintf('\n');

% Disk usage estimation
fprintf('=== Estimating Disk Usage ===\n');
memResult = validator.estimateDiskUsage();
% Results printed by method

% Cross-split contamination
fprintf('\n=== Checking Cross-Split Contamination ===\n');
contaminationResult = validator.checkCrossSplitContamination();
if contaminationResult.passed
    fprintf('✓ No patient overlap detected across splits\n\n');
else
    fprintf('✗ Contamination detected:\n');
    for i = 1:length(contaminationResult.duplicates)
        fprintf('  - %s\n', contaminationResult.duplicates{i});
    end
    fprintf('\n');
end

%% Step 4: Run All Checks at Once

fprintf('========================================\n');
fprintf('RUNNING COMPREHENSIVE VALIDATION\n');
fprintf('========================================\n\n');

allResults = validator.runAllChecks();

%% Step 5: Generate Detailed Report

reportPath = fullfile(datasetPath, 'validation_report.txt');
validator.generateReport(reportPath);

fprintf('\n========================================\n');
fprintf('VALIDATION SUMMARY\n');
fprintf('========================================\n\n');

% Count passed/failed/warning checks
checkNames = fieldnames(allResults);
passedCount = 0;
failedCount = 0;
warningCount = 0;

for i = 1:length(checkNames)
    checkName = checkNames{i};
    result = allResults.(checkName);
    
    if isstruct(result) && isfield(result, 'passed')
        isFailed = ~result.passed;
        hasWarnings = isfield(result, 'warnings') && ~isempty(result.warnings);

        if isFailed
            failedCount = failedCount + 1;
            fprintf('✗ %s (FAILED)\n', strrep(checkName, '_', ' '));
        elseif hasWarnings
            warningCount = warningCount + 1;
            fprintf('⚠ %s (WARNING)\n', strrep(checkName, '_', ' '));
        else
            passedCount = passedCount + 1;
            fprintf('✓ %s (PASSED)\n', strrep(checkName, '_', ' '));
        end
    end
end

fprintf('\nTotal checks with status: %d\n', passedCount + failedCount + warningCount);
fprintf('  Passed: %d\n', passedCount);
fprintf('  Failed: %d\n', failedCount);
fprintf('  Warnings: %d\n', warningCount);

if failedCount == 0 && warningCount == 0
    fprintf('\n✓ Dataset is ready for ML training!\n');
else
    fprintf('\n⚠ Dataset has issues that should be addressed.\n');
    fprintf('  See report: %s\n', reportPath);
end

fprintf('\n========================================\n');
fprintf('EXAMPLE COMPLETE\n');
fprintf('========================================\n');
