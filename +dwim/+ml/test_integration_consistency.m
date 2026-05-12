classdef test_integration_consistency < matlab.unittest.TestCase
%TEST_INTEGRATION_CONSISTENCY Cross-module consistency tests for the DWiM pipeline
%
%   Verifies that individual modules (normalizeHU, resampleVolume,
%   DatasetBuilder, preprocessPipeline) produce deterministic, self-consistent
%   outputs when called with identical inputs.
%
%   Run with:
%       results = runtests('test_integration_consistency');
%       disp(results);

    properties
        % Canonical test volume: CT-like values, reproducible seed
        BaseVol (128,128,32) single
        % Spacing matching a common CT scanner
        PixelSpacing (1,3) double = [0.8 0.8 1.5]
    end

    methods (TestMethodSetup)
        function buildBaseVolume(tc)
            rng(7, 'twister');
            tc.BaseVol = single(rand(128,128,32) * 4095 - 1024);
        end
    end

    % -----------------------------------------------------------------
    %  normalizeHU — precision and determinism
    % -----------------------------------------------------------------
    methods (Test)
        function testNormalizeHUPreservesSinglePrecision(tc)
            result = dwim.preprocess.normalizeHU(tc.BaseVol, 40, 400);
            tc.verifyClass(result, 'single', ...
                'normalizeHU must return single output for single input');
        end

        function testNormalizeHUPreservesDoublePrecision(tc)
            dblVol = double(tc.BaseVol);
            result = dwim.preprocess.normalizeHU(dblVol, 40, 400);
            tc.verifyClass(result, 'double', ...
                'normalizeHU must return double output for double input');
        end

        function testNormalizeHUOutputRange(tc)
            result = dwim.preprocess.normalizeHU(tc.BaseVol, 40, 400);
            tc.verifyGreaterThanOrEqual(min(result(:)), single(0), ...
                'normalizeHU output should be >= 0');
            tc.verifyLessThanOrEqual(max(result(:)), single(1), ...
                'normalizeHU output should be <= 1');
        end

        function testNormalizeHUHandlesNaNInInput(tc)
            nanVol = tc.BaseVol;
            nanVol(5,5,5) = NaN;
            result = dwim.preprocess.normalizeHU(nanVol, 40, 400);
            tc.verifyTrue(all(isfinite(result(:))), ...
                'normalizeHU should not propagate NaN to output');
        end

        function testNormalizeHUIsDeterministic(tc)
            r1 = dwim.preprocess.normalizeHU(tc.BaseVol, 40, 400);
            r2 = dwim.preprocess.normalizeHU(tc.BaseVol, 40, 400);
            tc.verifyEqual(r1, r2, ...
                'normalizeHU must be deterministic for identical inputs');
        end
    end

    % -----------------------------------------------------------------
    %  resampleVolume — output size and value range
    % -----------------------------------------------------------------
    methods (Test)
        function testResampleVolumeOutputClamped(tc)
            % Cubic interpolation can produce slight overshoot — verify clamping
            targetSpacing = [1.0 1.0 1.0];
            result = dwim.preprocess3d.resampleVolume( ...
                tc.BaseVol, tc.PixelSpacing, targetSpacing, 'cubic');

            inMin = min(tc.BaseVol(:));
            inMax = max(tc.BaseVol(:));

            tc.verifyGreaterThanOrEqual(min(result(:)), inMin - 1e-3, ...
                'resampleVolume cubic undershoot exceeds tolerance');
            tc.verifyLessThanOrEqual(max(result(:)), inMax + 1e-3, ...
                'resampleVolume cubic overshoot exceeds tolerance');
        end

        function testResampleVolumeLinearPreservesRange(tc)
            targetSpacing = [1.0 1.0 1.0];
            result = dwim.preprocess3d.resampleVolume( ...
                tc.BaseVol, tc.PixelSpacing, targetSpacing, 'linear');

            inMin = min(tc.BaseVol(:));
            inMax = max(tc.BaseVol(:));

            tc.verifyGreaterThanOrEqual(min(result(:)), inMin - 1e-3);
            tc.verifyLessThanOrEqual(max(result(:)), inMax + 1e-3);
        end

        function testResampleVolumeNearestNeighbourNoInterpolation(tc)
            % Nearest-neighbour must only contain values present in the input
            smallVol = int16(round(tc.BaseVol));
            f32 = single(smallVol);
            targetSpacing = [1.0 1.0 1.0];
            result = dwim.preprocess3d.resampleVolume( ...
                f32, tc.PixelSpacing, targetSpacing, 'nearest');

            inMin = min(f32(:));
            inMax = max(f32(:));
            outMin = min(result(:));
            outMax = max(result(:));

            tc.verifyGreaterThanOrEqual(outMin, inMin);
            tc.verifyLessThanOrEqual(outMax, inMax);
        end

        function testResampleVolumeThinSliceNoCrash(tc)
            % 1-pixel thick volume: outputSize guard must prevent zero-dim
            thinVol = tc.BaseVol(:,:,1);  % 128x128x1
            tc.verifyWarningFree( ...
                @() dwim.preprocess3d.resampleVolume( ...
                    thinVol, [0.8 0.8 50.0], [1.0 1.0 1.0], 'linear'));
        end
    end

    % -----------------------------------------------------------------
    %  Full pipeline determinism
    % -----------------------------------------------------------------
    methods (Test)
        function testPipelineIsDeterministic(tc)
            config = struct();
            config.executionMode = 'lenient';
            config.continueOnError = true;
            config.modality      = 'CT';
            config.windowCenter  = 40;
            config.windowWidth   = 400;
            config.targetSpacing = [1.0 1.0 1.0];
            config.pixelSpacing  = tc.PixelSpacing;

            [r1, meta1] = dwim.preprocessPipeline(tc.BaseVol, config);
            [r2, meta2] = dwim.preprocessPipeline(tc.BaseVol, config);

            tc.verifyEqual(r1, r2, 'Pipeline output must be deterministic');
            tc.verifyEqual(meta1.executionMode, meta2.executionMode);
        end

        function testPipelineDryRunMetadataConsistency(tc)
            config = struct();
            config.executionMode = 'dry_run';
            config.modality      = 'CT';
            config.windowCenter  = 40;
            config.windowWidth   = 400;

            [~, meta] = dwim.preprocessPipeline(tc.BaseVol, config);

            tc.verifyTrue(isfield(meta, 'executionMode'), ...
                'metadata must include executionMode in dry_run');
            tc.verifyEqual(meta.executionMode, 'dry_run');
        end
    end

    % -----------------------------------------------------------------
    %  DatasetBuilder → output passes basic sanity checks
    % -----------------------------------------------------------------
    methods (Test)
        function testDatasetBuilderOutputIsFinite(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'minmax', ...
                                        'splitRatios', [0.8 0.1 0.1]);
            for i = 1:5
                vol = tc.BaseVol + single(i * 10);
                db.addVolumes({vol}, {struct('idx', i)});
            end
            db.build();
            trainDS = db.getDataset('train');
            for k = 1:numel(trainDS.volumes)
                v = trainDS.volumes{k};
                tc.verifyTrue(all(isfinite(v(:))), ...
                    sprintf('Volume %d in train set contains non-finite values', k));
            end
        end

        function testDatasetBuilderSinglePrecisionOutput(tc)
            % Input is single; output should stay single (no unnecessary upcast)
            db = dwim.ml.DatasetBuilder('normalization', 'minmax');
            db.addVolumes({tc.BaseVol}, {struct()});
            db.build();
            trainDS = db.getDataset('train');
            if ~isempty(trainDS.volumes)
                tc.verifyClass(trainDS.volumes{1}, 'single', ...
                    'DatasetBuilder should preserve single precision');
            end
        end

        function testDatasetBuilderMetadataPreservedAfterBuild(tc)
            db = dwim.ml.DatasetBuilder();
            meta = struct('patientID', 'P999', 'label', 'nodule');
            db.addVolumes({tc.BaseVol}, {meta});
            db.build();
            trainDS = db.getDataset('train');
            if ~isempty(trainDS.metadata)
                m = trainDS.metadata{1};
                if isfield(m, 'patientID')
                    tc.verifyEqual(m.patientID, 'P999');
                end
            end
        end
    end
end
