# DWiM Retrieval Module

Automated DICOM retrieval from Orthanc PACS using REST API.

## Overview

The retrieval module provides comprehensive tools for querying and downloading DICOM studies from Orthanc:

- **OrthancClient** - Object-oriented REST API wrapper
- **queryOrthanc** - Advanced study search with filtering
- **retrieveBatch** - Batch download orchestrator with preprocessing integration

## Quick Start

### Basic Connection Test
```matlab
% Create client and test connection
client = dwim.retrieval.OrthancClient('Verbose', true);
info = client.getSystemInfo();

% List all studies
studies = client.listStudies();
```

### Query Studies
```matlab
% Query CT studies from 2025
query.Modality = 'CT';
query.StudyDate = '20250101-20251231';
results = dwim.retrieval.queryOrthanc(query);

% Display results
disp(results);
```

### Download Studies
```matlab
% Download matching studies
query.Modality = 'CT';
query.Limit = 10;
summary = dwim.retrieval.retrieveBatch(query, './downloads', ...
    'Verbose', true);

fprintf('Downloaded %d studies\n', summary.studiesDownloaded);
```

### Download and Process
```matlab
% Download and build 3D volumes automatically
summary = dwim.retrieval.retrieveBatch(query, './output', ...
    'ProcessVolumes', true, ...
    'Verbose', true);

% Access processed volumes
for i = 1:numel(summary.volumes)
    vol = summary.volumes{i};
    fprintf('Volume %d: %dx%dx%d\n', i, ...
        size(vol.volume,1), size(vol.volume,2), size(vol.volume,3));
end
```

## OrthancClient API

### Constructor
```matlab
client = dwim.retrieval.OrthancClient(Name, Value)
```

**Name-Value Arguments:**
- `BaseURL` - Orthanc server URL (default: from config)
- `User` - Username (default: from config)
- `Password` - Password (default: from config)
- `Verbose` - Display output (default: false)
- `Timeout` - Request timeout in seconds (default: 30)

### Methods

#### List Resources
```matlab
patients = client.listPatients();
studies = client.listStudies();
series = client.listSeries();
```

#### Get Metadata
```matlab
patient = client.getPatient(patientID);
study = client.getStudy(studyID);
series = client.getSeries(seriesID);
instance = client.getInstance(instanceID);
```

#### Advanced Search
```matlab
query.Modality = 'CT';
query.PatientName = 'Smith*';
results = client.findStudies(query);
```

#### Download
```matlab
% Download series as individual DICOM files
seriesPath = client.downloadSeries(seriesID, outputDir);

% Download series as ZIP archive
zipPath = client.downloadSeriesAsZip(seriesID, 'series.zip');
```

## Query Filters

### queryOrthanc Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `PatientID` | Patient identifier | `'PAT001'` |
| `PatientName` | Patient name (wildcards) | `'Smith*'` |
| `Modality` | Imaging modality | `'CT'`, `'MR'`, `'PT'` |
| `StudyDate` | Study date or range | `'20250115'`, `'20250101-20251231'` |
| `StudyDescription` | Study description | `'Chest CT'` |
| `Limit` | Maximum results | `10` |
| `SortBy` | Sort field | `'StudyDate'`, `'PatientName'` |
| `SortOrder` | Sort direction | `'ascend'`, `'descend'` |

### Example Queries

```matlab
% Recent CT head scans
query.Modality = 'CT';
query.StudyDescription = '*Head*';
query.Limit = 5;
query.SortBy = 'StudyDate';
results = dwim.retrieval.queryOrthanc(query);

% Specific patient studies
query.PatientID = 'PAT001';
results = dwim.retrieval.queryOrthanc(query);

% Date range query
query.StudyDate = '20250101-20250131';
results = dwim.retrieval.queryOrthanc(query);
```

## Batch Retrieval

### retrieveBatch Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ProcessVolumes` | logical | false | Build 3D volumes after download |
| `AnonymizeBeforeSave` | logical | false | Anonymize files (requires anonymize module) |
| `Parallel` | logical | true | Use parallel download |
| `MaxStudies` | double | inf | Maximum studies to retrieve |
| `Verbose` | logical | true | Display progress |
| `OnStudyComplete` | function_handle | [] | Callback after each study |

### Example Workflows

#### Basic Download
```matlab
query.Modality = 'CT';
summary = dwim.retrieval.retrieveBatch(query, './ct_data');
```

#### Download with Processing
```matlab
query.Modality = 'CT';
summary = dwim.retrieval.retrieveBatch(query, './processed', ...
    'ProcessVolumes', true, ...
    'MaxStudies', 20);
```

#### Custom Callback
```matlab
callback = @(path, meta) fprintf('Downloaded: %s\n', meta.PatientID{1});
summary = dwim.retrieval.retrieveBatch(query, './data', ...
    'OnStudyComplete', callback);
```

## Integration with Existing Modules

### Complete Pipeline
```matlab
% 1. Retrieve from Orthanc
query.Modality = 'CT';
summary = dwim.retrieval.retrieveBatch(query, './raw_data');

% 2. Build 3D volumes (if not done in retrieveBatch)
for i = 1:numel(summary.studyPaths)
    studyPath = summary.studyPaths{i};
    [volume, spacing] = dwim.preprocess3d.buildVolumeFromSeries(studyPath);
    % Save or process volume...
end

% 3. Build ML dataset
builder = dwim.ml.DatasetBuilder('outputDir', './ml_dataset');
% Add volumes to builder...
builder.build();
```

## Error Handling

The retrieval module includes robust error handling:

```matlab
try
    summary = dwim.retrieval.retrieveBatch(query, './output');
    
    % Check for partial failures
    if ~isempty(summary.errors)
        fprintf('Warnings during retrieval:\n');
        for i = 1:numel(summary.errors)
            fprintf('  %s\n', summary.errors{i});
        end
    end
catch ME
    fprintf('Retrieval failed: %s\n', ME.message);
end
```

## Performance Tips

1. **Use parallel download** for large batches (default enabled)
2. **Limit results** for faster queries: `'MaxStudies', 50`
3. **Process volumes later** if you need raw DICOMs first
4. **Use ZIP download** for single series: `downloadSeriesAsZip()`

## Requirements

- MATLAB R2025a or later
- Orthanc server with REST API enabled
- Network access to Orthanc
- Sufficient disk space for downloads

## Configuration

Orthanc connection settings are read from `dwim.config()`:

```matlab
config = dwim.config();
config.Orthanc.BaseURL = 'http://localhost:8042';
config.Orthanc.User = 'orthanc';
config.Orthanc.Password = 'orthanc';
```

## See Also

- `dwim.preprocess3d.buildVolumeFromSeries` - Build 3D volumes
- `dwim.ml.DatasetBuilder` - Create ML datasets
- `dwim.preprocessPipeline` - Unified preprocessing
