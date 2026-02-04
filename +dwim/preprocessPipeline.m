function [output, metadata] = preprocessPipeline(input, config)
%PREPROCESSPIPELINE Unified preprocessing pipeline for DICOM to ML workflows
%
%   [output, metadata] = preprocessPipeline(input, config)
%       Executes a configurable preprocessing pipeline
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
        config struct
    end
    
    % Validate config
    if ~isfield(config, 'inputType')
        error('dwim:preprocessPipeline:MissingConfig', 'Config must specify inputType');
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
    
    % Initialize metadata
    metadata = struct();
    metadata.timestamp = datetime('now');
    metadata.config = config;
    metadata.steps = struct();
    
    if config.verbose
        fprintf('DWiM Unified Preprocessing Pipeline\n');
        fprintf('===================================\n');
        fprintf('Input type: %s\n', config.inputType);
        fprintf('Steps: %s\n', strjoin(config.steps, ' → '));
        fprintf('===================================\n');
    end
    
    % Start timing
    totalStart = tic;
    
    % Load input data
    data = loadInput(input, config);
    metadata.input = struct();
    metadata.input.type = config.inputType;
    metadata.input.size = size(data);
    
    % Execute pipeline steps
    for i = 1:length(config.steps)
        step = config.steps{i};
        
        if config.verbose
            fprintf('\nStep %d/%d: %s\n', i, length(config.steps), step);
            fprintf('-----------------------------------\n');
        end
        
        stepStart = tic;
        
        % Get step parameters
        if isfield(config.parameters, step)
            stepParams = config.parameters.(step);
        else
            stepParams = struct();
        end
        
        % Execute step
        [data, stepMeta] = executeStep(step, data, stepParams, config.verbose);
        
        % Store step metadata
        metadata.steps.(step) = stepMeta;
        metadata.steps.(step).executionTime = toc(stepStart);
        
        if config.verbose
            fprintf('Step completed in %.2f seconds\n', metadata.steps.(step).executionTime);
        end
    end
    
    % Final validation if enabled
    if config.validation.enabled
        if config.verbose
            fprintf('\nFinal Validation\n');
            fprintf('-----------------------------------\n');
        end
        
        if ndims(data) == 3
            [isValid, validReport] = dwim.preprocess3d.validateVolumeForML(data, ...
                'Verbose', config.verbose);
        else
            [isValid, validReport] = dwim.preprocess.validateImageForML(data, ...
                'Verbose', config.verbose);
        end
        
        metadata.validation.performed = true;
        metadata.validation.isValid = isValid;
        metadata.validation.results = validReport;
    else
        metadata.validation.performed = false;
    end
    
    % Calculate total time
    metadata.totalTime = toc(totalStart);
    
    % Set output
    output = data;
    
    if config.verbose
        fprintf('===================================\n');
        fprintf('Pipeline completed in %.2f seconds\n', metadata.totalTime);
        fprintf('Output size: ');
        fprintf('[%d', size(output, 1));
        for d = 2:ndims(output)
            fprintf(' %d', size(output, d));
        end
        fprintf(']\n');
        fprintf('===================================\n');
    end
end

function data = loadInput(input, config)
%LOADINPUT Load input data based on input type
    
    switch config.inputType
        case 'filepath'
            % Single DICOM file
            if config.verbose
                fprintf('Loading DICOM file: %s\n', input);
            end
            data = dicomread(input);
            
        case 'dicomdir'
            % DICOM directory - will be assembled in 'assemble' step
            if config.verbose
                fprintf('DICOM directory: %s\n', input);
            end
            data = input;  % Pass path to assemble step
            
        case 'image'
            % Pre-loaded 2D image
            if config.verbose
                fprintf('Using pre-loaded image\n');
            end
            data = input;
            
        case 'volume'
            % Pre-loaded 3D volume
            if config.verbose
                fprintf('Using pre-loaded volume\n');
            end
            data = input;
            
        otherwise
            error('dwim:preprocessPipeline:InvalidInputType', ...
                  'Unknown input type: %s', config.inputType);
    end
end

function [data, stepMeta] = executeStep(step, data, params, verbose)
%EXECUTESTEP Execute a single pipeline step
    
    stepMeta = struct();
    stepMeta.step = step;
    stepMeta.params = params;
    
    switch step
        case 'assemble'
            % Assemble 3D volume from DICOM series
            assembleParams = {};
            if isfield(params, 'sortBy')
                assembleParams = [assembleParams, {'SortBy', params.sortBy}];
            end
            assembleParams = [assembleParams, {'Verbose', verbose}];
            
            [data, assembleMeta] = dwim.preprocess3d.assembleVolume(data, assembleParams{:});
            stepMeta.assemblyInfo = assembleMeta;
            
        case 'orient'
            % Correct orientation
            targetOrientation = 'RAS';
            if isfield(params, 'targetOrientation')
                targetOrientation = params.targetOrientation;
            end
            
            % Get DICOM info if available
            if ischar(data) || isstring(data)
                % data is still a path, load first slice for orientation
                files = dir(fullfile(data, '*.dcm'));
                if isempty(files)
                    files = dir(fullfile(data, '*'));
                    files = files(~[files.isdir]);
                end
                if ~isempty(files)
                    dicomInfo = dicominfo(fullfile(files(1).folder, files(1).name));
                else
                    error('dwim:preprocessPipeline:NoFiles', 'No files found for orientation');
                end
            else
                % Assume volume is already assembled, skip orientation for now
                % In production, metadata should be passed through pipeline
                if verbose
                    fprintf('Skipping orientation correction (metadata not available)\n');
                end
                stepMeta.skipped = true;
                return;
            end
            
            [data, transformMatrix] = dwim.preprocess3d.correctOrientation(data, dicomInfo, ...
                'TargetOrientation', targetOrientation, 'Verbose', verbose);
            stepMeta.transformMatrix = transformMatrix;
            stepMeta.targetOrientation = targetOrientation;
            
        case 'resample'
            % Resample volume
            resampleParams = {};
            if isfield(params, 'targetSpacing')
                resampleParams = [resampleParams, {'TargetSpacing', params.targetSpacing}];
            end
            if isfield(params, 'voxelSpacing')
                resampleParams = [resampleParams, {'VoxelSpacing', params.voxelSpacing}];
            end
            resampleParams = [resampleParams, {'Verbose', verbose}];
            
            [data, resampleMeta] = dwim.preprocess3d.resampleVolume(data, resampleParams{:});
            stepMeta.resampleInfo = resampleMeta;
            
        case 'window'
            % Apply windowing
            if isfield(params, 'preset')
                data = dwim.preprocess.applyWindowPreset(data, params.preset);
                stepMeta.preset = params.preset;
            elseif isfield(params, 'center') && isfield(params, 'width')
                data = dwim.preprocess.normalizeHU(data, params.center, params.width);
                stepMeta.center = params.center;
                stepMeta.width = params.width;
            else
                error('dwim:preprocessPipeline:InvalidWindowParams', ...
                      'Window step requires either preset or center/width');
            end
            
        case 'normalize'
            % Normalize HU values
            center = 0;
            width = 4000;
            if isfield(params, 'windowCenter')
                center = params.windowCenter;
            end
            if isfield(params, 'windowWidth')
                width = params.windowWidth;
            end
            
            data = dwim.preprocess.normalizeHU(data, center, width);
            stepMeta.center = center;
            stepMeta.width = width;
            
        case 'validate'
            % Validate 2D image
            [isValid, report] = dwim.preprocess.validateImageForML(data, 'Verbose', verbose);
            if ~isValid
                warning('dwim:preprocessPipeline:ValidationFailed', ...
                        'Image validation failed: %s', report.failureReason);
            end
            stepMeta.validationReport = report;
            stepMeta.isValid = isValid;
            
        case 'validate_volume'
            % Validate 3D volume
            validateParams = {};
            if isfield(params, 'MinSlices')
                validateParams = [validateParams, {'MinSlices', params.MinSlices}];
            end
            validateParams = [validateParams, {'Verbose', verbose}];
            
            [isValid, report] = dwim.preprocess3d.validateVolumeForML(data, validateParams{:});
            if ~isValid
                warning('dwim:preprocessPipeline:ValidationFailed', ...
                        'Volume validation failed: %s', report.failureReason);
            end
            stepMeta.validationReport = report;
            stepMeta.isValid = isValid;
            
        otherwise
            error('dwim:preprocessPipeline:UnknownStep', ...
                  'Unknown pipeline step: %s', step);
    end
end
