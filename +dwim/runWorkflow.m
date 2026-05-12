function result = runWorkflow(studyID, config)
%RUNWORKFLOW Unified workflow orchestration for DWiM
%
%   result = dwim.runWorkflow(studyID)
%   result = dwim.runWorkflow(studyID, config)
%
%   Executes the full DICOM pipeline for a given study:
%       1. Retrieval   - Download DICOM series from Orthanc
%       2. Anonymize   - Remove PHI (if config.doAnonymize)
%       3. Metadata    - Export metadata (if config.exportMetadata)
%       4. PNG         - Convert to PNG (if config.exportPNG)
%       5. Volume      - Build 3D ML volume (if config.buildVolume)
%
%   Inputs:
%       studyID - Orthanc study ID string
%       config  - (optional) Config struct from dwim.defaultConfig()
%
%   Output:
%       result.study        - Downloaded study path
%       result.metadata     - Extracted metadata struct (or [])
%       result.pngPaths     - PNG file paths (or [])
%       result.volume       - 3D volume array (or [])
%
%   Example:
%       result = dwim.runWorkflow('2b08116a-f739e7be-20b50985');
%
%       config = dwim.defaultConfig();
%       config.exportPNG = true;
%       result = dwim.runWorkflow('2b08116a-f739e7be-20b50985', config);

    arguments
        studyID (1,1) string
        config  (1,1) struct = dwim.defaultConfig()
    end

    fprintf('[DWiM] Starting workflow for study: %s\n', studyID);

    % Initialize result
    result = struct( ...
        'studyID',  studyID, ...
        'study',    [], ...
        'metadata', [], ...
        'pngPaths', [], ...
        'volume',   [] ...
    );

    % Step 1: Retrieval
    fprintf('[DWiM] Step 1/5: Retrieving DICOM series...\n');
    client = dwim.retrieval.OrthancClient('Verbose', false);
    studyPath = fullfile(config.outputDir, studyID);
    studyInfo = client.getStudy(studyID);
    seriesList = studyInfo.Series;

    for i = 1:numel(seriesList)
        seriesDir = fullfile(studyPath, sprintf('series_%02d', i));
        client.downloadSeries(string(seriesList{i}), seriesDir, 'CreateSubdir', false);
    end
    result.study = studyPath;
    fprintf('[DWiM] Retrieval complete: %s\n', studyPath);

    % Step 2: Anonymization
    if config.doAnonymize
        fprintf('[DWiM] Step 2/5: Anonymizing...\n');
        if exist('dwim.anonymize', 'file')
            result.study = dwim.anonymize(result.study);
            fprintf('[DWiM] Anonymization complete\n');
        else
            fprintf('[DWiM] Anonymization skipped (module not available)\n');
        end
    else
        fprintf('[DWiM] Step 2/5: Anonymization skipped (disabled)\n');
    end

    % Step 3: Metadata export
    if config.exportMetadata
        fprintf('[DWiM] Step 3/5: Exporting metadata...\n');
        dcmFiles = dir(fullfile(studyPath, '**', '*.dcm'));
        if ~isempty(dcmFiles)
            firstFile = fullfile(dcmFiles(1).folder, dcmFiles(1).name);
            result.metadata = dwim.extractMetadata(firstFile);
            fprintf('[DWiM] Metadata export complete\n');
        else
            fprintf('[DWiM] Metadata export skipped (no DICOM files found)\n');
        end
    else
        fprintf('[DWiM] Step 3/5: Metadata export skipped (disabled)\n');
    end

    % Step 4: PNG conversion
    if config.exportPNG
        fprintf('[DWiM] Step 4/5: Converting to PNG...\n');
        if exist('dwim.convertToPNG', 'file')
            result.pngPaths = dwim.convertToPNG(result.study);
            fprintf('[DWiM] PNG conversion complete\n');
        else
            fprintf('[DWiM] PNG conversion skipped (module not available)\n');
        end
    else
        fprintf('[DWiM] Step 4/5: PNG conversion skipped (disabled)\n');
    end

    % Step 5: Volume construction
    if config.buildVolume
        fprintf('[DWiM] Step 5/5: Building 3D volume...\n');
        seriesDirs = dir(fullfile(studyPath, 'series_*'));
        seriesDirs = seriesDirs([seriesDirs.isdir]);
        if ~isempty(seriesDirs)
            seriesPath = fullfile(studyPath, seriesDirs(1).name);
            [result.volume, ~, ~] = dwim.preprocess3d.buildVolumeFromSeries( ...
                seriesPath, 'Verbose', false);
            fprintf('[DWiM] Volume construction complete: [%s]\n', ...
                num2str(size(result.volume)));
        else
            fprintf('[DWiM] Volume construction skipped (no series found)\n');
        end
    else
        fprintf('[DWiM] Step 5/5: Volume construction skipped (disabled)\n');
    end

    fprintf('[DWiM] Workflow completed successfully\n');
end
