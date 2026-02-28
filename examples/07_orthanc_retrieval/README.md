# Orthanc Retrieval Examples

This directory contains examples demonstrating DICOM retrieval from Orthanc PACS.

## Prerequisites

1. **Orthanc Server Running**
   ```bash
   docker run -p 8042:8042 jodogne/orthanc
   ```

2. **DICOM Data Loaded**
   - Upload test DICOM files to Orthanc
   - Or download sample data from TCIA

3. **Configuration**
   - Edit `dwim.config()` with Orthanc credentials
   - Default: http://localhost:8042 (orthanc/orthanc)

## Running Examples

```matlab
% Navigate to examples directory
cd examples/07_orthanc_retrieval

% Run all examples
example_retrieval

% Or run specific sections interactively
```

## Example Overview

### Example 1: Basic Connection Test
- Connect to Orthanc server
- Verify credentials and availability
- List studies

### Example 2: Query Studies with Filters
- Query by modality (CT, MR, PT)
- Filter by date range
- Display query results

### Example 3: Download Single Series
- Download DICOM files from one series
- Save to local directory
- Verify file count

### Example 4: Batch Retrieval
- Download multiple studies matching query
- Track download statistics
- Handle errors gracefully

### Example 5: Retrieve and Process to 3D Volumes
- Download studies
- Automatically build 3D volumes
- Extract volume metadata

### Example 6: Custom Callback Function
- Define callback for each study
- Execute custom processing
- Log progress

### Example 7: Advanced Query with Sorting
- Sort results by date
- Limit result count
- Display formatted results

## Integration with Other Modules

### Complete Workflow
```matlab
% 1. Retrieve from Orthanc
query.Modality = 'CT';
summary = dwim.retrieval.retrieveBatch(query, './data');

% 2. Anonymize (if needed)
% Use Suryansh's anonymization module
for i = 1:numel(summary.studyPaths)
    studyPath = summary.studyPaths{i};
    % anonymize files in studyPath...
end

% 3. Build ML dataset
builder = dwim.ml.DatasetBuilder();
% add volumes...
builder.build();
```

## Troubleshooting

### Connection Failed
- Verify Orthanc is running: `curl http://localhost:8042/system`
- Check credentials in `dwim.config()`
- Verify network access

### No Studies Found
- Upload DICOM files to Orthanc first
- Check query filters are not too restrictive
- Verify Orthanc has data: visit http://localhost:8042/app/explorer.html

### Download Errors
- Check disk space
- Verify write permissions
- Check Orthanc server logs

## See Also

- [Retrieval Module README](../../+dwim/+retrieval/README.md)
- [Orthanc REST API Documentation](https://book.orthanc-server.com/users/rest.html)
- [DWiM Preprocessing Examples](../03_3d_preprocessing/)
