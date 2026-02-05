function [output, metadata] = preprocessPipeline(input, config)
%PREPROCESSPIPELINE Unified preprocessing pipeline for medical imaging
%
%   [output, metadata] = dwim.preprocessPipeline(input, config)
%       Applies configurable preprocessing pipeline to medical images/volumes
%
%   Inputs:
%       input - Input data (filepath, directory path, or array)
%       config - Configuration structure with fields:
%                .inputType - 'filepath', 'dicomdir', 'image', 'volume'
%                .outputType - 'image', 'volume'
%                .steps - Cell array of processing steps
%                .parameters - Structure with step-specific parameters
%                .validation - Validation settings
%                .verbose - Display progress (default: true)
%
%   Outputs:
%       output - Processed image or volume
%       metadata - Structure with processing information
%
%   Processing Steps:
%       'assemble' - Assemble 3D volume from DICOM series
%       'orient' - Correct anatomical orientation
%       'resample' - Resample to isotropic spacing
%       'window' - Apply windowing preset
%       'normalize' - Normalize HU values
%       'validate' - Validate 2D image for ML
%       'validate_volume' - Validate 3D volume for ML
%
%   Example:
%       % DICOM folder to ML-ready volume
%       config = struct();
%       config.inputType = 'dicomdir';
%       config.steps = {'assemble', 'orient', 'resample'};
%       config.parameters.orient.targetOrientation = 'RAS';
%       config.parameters.resample.targetSpacing = 1.0;
%       [volume, metadata] = dwim.preprocessPipeline('dicom_folder/', config);

    arguments
        input
        config (1,1) struct
    end
    
    % Validate config
    if ~isfield(config, 'inputType')
        error('dwim:preprocessPipeline:MissingConfig', 'Config must specify inputType (valid options: ''filepath'', ''dicomdir'', ''image'', ''volume'')');
    end
    
    if ~isfield(config, 'steps')
        config.steps = {};
    end
    
    if ~isfield(config, 'parameters')
        config.parameters = struct();
    end
    
    if ~isfield(config, 'validation')
        config.validation = struct('enabled', true);
    end
    
    if ~isfield(config, 'verbose')
        config.verbose = true;
    end
    
    % Initialize metadata and timing
    pipelineTimer = tic;
    metadata = struct();
    metadata.startTime = datetime('now');
    metadata.config = config;
    metadata.steps = {};

    if config.verbose
        fprintf('DWiM Unified Preprocessing Pipeline\n');
        fprintf('===================================\n');
        fprintf('Input type: %s\n', config.inputType);
        fprintf('Steps: %s\n', strjoin(config.steps, ' → '));
    end

    % Step 1: Input processing
    [data, inputMetadata] = processInput(input, config);
    metadata.input = inputMetadata;
    metadata.steps{end+1} = 'input';

    % Step 2: Apply preprocessing steps
    for i = 1:length(config.steps)
        stepName = config.steps{i};

        if config.verbose
            fprintf('Step %d/%d: %s\n', i, length(config.steps), stepName);
        end

        [data, stepMetadata] = applyProcessingStep(data, stepName, config);
        metadata.(stepName) = stepMetadata;
        metadata.steps{end+1} = stepName;
    end

    % Step 3: Final validation
    if isfield(config, 'validation') && config.validation.enabled
        [isValid, validationResults] = applyValidation(data, config.validation);
        metadata.validation = struct('performed', true, 'isValid', isValid, 'results', validationResults);
    else
        metadata.validation = struct('performed', false);
    end

    % Finalize metadata
    metadata.totalTime = toc(pipelineTimer);
    metadata.endTime = datetime('now');
    metadata.success = true;

    output = data;

    if config.verbose
        fprintf('Pipeline completed in %.2f seconds\n', metadata.totalTime);
        fprintf('===================================\n');
    end
end

function [data, metadata] = processInput(input, config)
%PROCESSINPUT Handle different input types

    metadata = struct('originalType', class(input), 'originalSize', size(input));

    switch config.inputType
        case 'filepath'
            % Single file path
            if isfile(input)
                data = loadImageFromFile(input);
                metadata.filePath = input;
            else
                error('dwim:preprocessPipeline:FileNotFound', 'File not found: %s', input);
            end

        case 'dicomdir'
            % DICOM directory - delegate to buildVolumeFromSeries
            if isfolder(input)
                [data, spacing, buildMetadata] = dwim.preprocess3d.buildVolumeFromSeries(input, ...
                    'Verbose', false);
                metadata.dicomDir = input;
                metadata.spacing = spacing;
                metadata.buildMetadata = buildMetadata;

                % Validation: Check for empty volume
                if isempty(data) || prod(size(data)) == 0
                    error('dwim:preprocessPipeline:EmptyVolume', ...
                          'No valid DICOM data found in directory: %s', input);
                end

                % Validation: Check modality is CT
                if isfield(buildMetadata, 'modality') && ~strcmpi(buildMetadata.modality, 'CT')
                    error('dwim:preprocessPipeline:NonCTModality', ...
                          'Input DICOM series is not CT modality: %s', buildMetadata.modality);
                end
            else
                error('dwim:preprocessPipeline:DirNotFound', 'Directory not found: %s', input);
            end

        case 'image'
            % Already loaded image array
            data = input;
            metadata.inputType = 'array';

        case 'volume'
            % Already loaded volume array
            data = input;
            metadata.inputType = 'array';

        otherwise
            error('dwim:preprocessPipeline:UnknownInputType', ...
                  'Unknown input type: %s', config.inputType);
    end

    metadata.processedType = class(data);
    metadata.processedSize = size(data);
end

function [output, metadata] = applyProcessingStep(data, stepName, config)
%APPLYPROCESSINGSTEP Apply individual processing step

    metadata = struct('step', stepName, 'startTime', datetime('now'));

    % Get step parameters
    if isfield(config, 'parameters') && isfield(config.parameters, stepName)
        params = config.parameters.(stepName);
    else
        params = struct();
    end

    switch stepName
        case 'validate'
            [output, stepResults] = dwim.preprocess.validateImageForML(data);
            metadata.results = stepResults;

        case 'window'
            if isfield(params, 'preset')
                output = dwim.preprocess.applyWindowPreset(data, params.preset);
                metadata.applied = true;
                metadata.preset = params.preset;
            else
                output = data; % No windowing applied
                metadata.applied = false;
            end

        case 'normalize'
            % Apply HU normalization (works on both 2D and 3D)
            output = dwim.preprocess.normalizeHU(data, -600, 1500); % Default lung window
            metadata.applied = true;
            metadata.windowCenter = -600;
            metadata.windowWidth = 1500;

        case 'assemble'
            % For 3D assembly - this might be redundant if input is already dicomdir
            if ndims(data) == 3
                output = data; % Already assembled
                metadata.skipped = true;
            else
                error('dwim:preprocessPipeline:AssemblyNotSupported', ...
                      'Assembly step requires 3D input or dicomdir');
            end

        case 'orient'
            if ndims(data) == 3
                [output, transform] = dwim.preprocess3d.correctOrientation(data, ...
                    'TargetOrientation', params.targetOrientation, 'Verbose', false);
                metadata.transform = transform;
                metadata.targetOrientation = params.targetOrientation;
            else
                output = data;
                metadata.skipped = true;
            end

        case 'resample'
            if ndims(data) == 3
                [output, resampleMeta] = dwim.preprocess3d.resampleVolume(data, ...
                    'TargetSpacing', params.targetSpacing, 'Verbose', false);
                metadata.resampleMetadata = resampleMeta;
                metadata.targetSpacing = params.targetSpacing;
            else
                output = data;
                metadata.skipped = true;
            end

        case 'validate_volume'
            if ndims(data) == 3
                [isValid, results] = dwim.preprocess3d.validateVolumeForML(data);
                output = data; % Validation doesn't change data
                metadata.isValid = isValid;
                metadata.results = results;
            else
                output = data;
                metadata.skipped = true;
            end

        otherwise
            warning('dwim:preprocessPipeline:UnknownStep', ...
                    'Unknown processing step: %s', stepName);
            output = data;
            metadata.skipped = true;
    end

    metadata.endTime = datetime('now');
    metadata.duration = seconds(metadata.endTime - metadata.startTime);
end

function [isValid, results] = applyValidation(data, validationConfig)
%APPLYVALIDATION Apply final validation

    if ndims(data) == 3
        [isValid, results] = dwim.preprocess3d.validateVolumeForML(data, ...
            'Verbose', false);
    else
        [isValid, results] = dwim.preprocess.validateImageForML(data);
    end
end

function image = loadImageFromFile(filepath)
%LOADIMAGEFROMFILE Load image from file path
    % This is a placeholder - implement based on file type
    if contains(filepath, '.dcm') || contains(filepath, '.dicom')
        image = dicomread(filepath);
    elseif contains(filepath, '.png') || contains(filepath, '.jpg')
        image = imread(filepath);
    else
        error('dwim:preprocessPipeline:UnsupportedFileType', ...
              'Unsupported file type: %s', filepath);
    end
end
