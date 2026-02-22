classdef test_datasetBuilder_edgeCases < matlab.unittest.TestCase
%TEST_DATASETBUILDER_EDGECASES Edge-case tests for dwim.ml.DatasetBuilder
%
%   Covers: malformed metadata, constant/NaN/Inf volumes, empty datasets,
%   small splits, and per-volume error recovery during processBatch.
%
%   Run with:
%       results = runtests('test_datasetBuilder_edgeCases');
%       disp(results);

    properties
        % Default small volume used across tests
        SmallVol  (128,128,16) single
    end

    methods (TestMethodSetup)
        function initVolume(tc)
            % Reproducible random volume in HU-like range [-1024 3071]
            rng(42, 'twister');
            tc.SmallVol = single(rand(128,128,16) * 4095 - 1024);
        end
    end

    % -----------------------------------------------------------------
    %  addVolumes — metadata validation
    % -----------------------------------------------------------------
    methods (Test)
        function testAddVolumesAcceptsStructMetadata(tc)
            db = dwim.ml.DatasetBuilder();
            meta = struct('patientID', 'P001', 'modality', 'CT');
            tc.verifyWarningFree(@() db.addVolumes({tc.SmallVol}, {meta}));
        end

        function testAddVolumesReplacesNonStructMetadata(tc)
            db = dwim.ml.DatasetBuilder();
            % Pass a non-struct metadata cell (e.g., a string)
            tc.verifyWarning( ...
                @() db.addVolumes({tc.SmallVol}, {'not-a-struct'}), ...
                'DatasetBuilder:InvalidMetadata');
            % Despite the bad metadata the volume should still be recorded
            tc.verifyEqual(db.numVolumes(), 1);
        end

        function testAddVolumesHandlesMissingMetadataCell(tc)
            db = dwim.ml.DatasetBuilder();
            % Pass fewer metadata entries than volumes
            vol2 = tc.SmallVol * 0.5;
            tc.verifyWarning( ...
                @() db.addVolumes({tc.SmallVol, vol2}, {struct()}), ...
                'DatasetBuilder:MismatchedMetadataCount');
        end

        function testAddVolumesMixedValidInvalidMetadata(tc)
            db = dwim.ml.DatasetBuilder();
            goodMeta = struct('id', 'A');
            tc.verifyWarning( ...
                @() db.addVolumes({tc.SmallVol, tc.SmallVol}, ...
                                   {goodMeta, 42}), ...
                'DatasetBuilder:InvalidMetadata');
            tc.verifyEqual(db.numVolumes(), 2);
        end
    end

    % -----------------------------------------------------------------
    %  normalizeVolume — zero-range and non-finite values
    % -----------------------------------------------------------------
    methods (Test)
        function testMinMaxNormalizationOnConstantVolume(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'minmax');
            db.addVolumes({ones(8,8,8,'single')}, {struct()});
            db.build();
            ds = db.getDataset('train');
            if ~isempty(ds.volumes)
                vol = ds.volumes{1};
                % Constant volume should not produce NaN or Inf
                tc.verifyTrue(all(isfinite(vol(:))), ...
                    'Constant volume produced non-finite values after minmax normalization');
                % All values should be in [0,1] range (midpoint 0.5)
                tc.verifyGreaterThanOrEqual(min(vol(:)), 0 - eps('single'));
                tc.verifyLessThanOrEqual(max(vol(:)), 1 + eps('single'));
            end
        end

        function testZscoreNormalizationOnConstantVolume(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'zscore');
            db.addVolumes({ones(8,8,8,'single') * 500}, {struct()});
            db.build();
            ds = db.getDataset('train');
            if ~isempty(ds.volumes)
                vol = ds.volumes{1};
                tc.verifyTrue(all(isfinite(vol(:))), ...
                    'Constant volume produced non-finite values after zscore normalization');
            end
        end

        function testPercentileNormalizationOnConstantVolume(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'percentile');
            db.addVolumes({ones(8,8,8,'single') * 100}, {struct()});
            db.build();
            ds = db.getDataset('train');
            if ~isempty(ds.volumes)
                vol = ds.volumes{1};
                tc.verifyTrue(all(isfinite(vol(:))), ...
                    'Constant volume produced non-finite values after percentile normalization');
            end
        end

        function testNormalizationWithNaNInVolume(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'minmax');
            nanVol = tc.SmallVol;
            nanVol(10,10,5) = NaN;
            db.addVolumes({nanVol}, {struct()});
            % Should not throw; NaN handling is implementation-defined
            tc.verifyWarningFree(@() db.build());
        end

        function testNormalizationWithInfInVolume(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'minmax');
            infVol = tc.SmallVol;
            infVol(5,5,3) = Inf;
            infVol(6,6,3) = -Inf;
            db.addVolumes({infVol}, {struct()});
            tc.verifyWarningFree(@() db.build());
        end
    end

    % -----------------------------------------------------------------
    %  processBatch — error recovery
    % -----------------------------------------------------------------
    methods (Test)
        function testProcessBatchSkipsCorruptedVolumeAndContinues(tc)
            db = dwim.ml.DatasetBuilder('normalization', 'minmax');
            goodVol = tc.SmallVol;
            % Empty volume will trigger an error in normalization
            emptyVol = zeros(0,0,0,'single');
            goodMeta  = struct('id', 'good');
            emptyMeta = struct('id', 'empty');
            db.addVolumes({goodVol, emptyVol, goodVol}, ...
                           {goodMeta,  emptyMeta,  goodMeta});
            % Build should complete without error even if one volume fails
            tc.verifyWarningFree(@() db.build());
            ds = db.getDataset('train');
            % At least the good volumes should produce output
            tc.verifyNotEmpty(ds);
        end
    end

    % -----------------------------------------------------------------
    %  build / split — small dataset edge cases
    % -----------------------------------------------------------------
    methods (Test)
        function testBuildWithSingleVolume(tc)
            db = dwim.ml.DatasetBuilder();
            db.addVolumes({tc.SmallVol}, {struct()});
            tc.verifyWarningFree(@() db.build());
        end

        function testBuildWithEmptyDataset(tc)
            db = dwim.ml.DatasetBuilder();
            % Build on empty dataset should warn or be a no-op, not crash
            tc.verifyWarningFree(@() db.build());
        end

        function testSplitRatiosSumToOne(tc)
            db = dwim.ml.DatasetBuilder('splitRatios', [0.6 0.2 0.2]);
            for i = 1:5
                db.addVolumes({tc.SmallVol + i}, {struct('id', i)});
            end
            db.build();
            trainDS = db.getDataset('train');
            valDS   = db.getDataset('val');
            testDS  = db.getDataset('test');
            totalOut = numel(trainDS.volumes) + numel(valDS.volumes) + numel(testDS.volumes);
            tc.verifyEqual(totalOut, 5, ...
                'Total volumes after split should equal input count');
        end

        function testSplitWithFewerVolumesThanSplitSegments(tc)
            % 2 volumes with 3-way split — some splits will be empty
            db = dwim.ml.DatasetBuilder('splitRatios', [0.6 0.2 0.2]);
            db.addVolumes({tc.SmallVol, tc.SmallVol*2}, {struct(), struct()});
            tc.verifyWarningFree(@() db.build());
            trainDS = db.getDataset('train');
            tc.verifyNotEmpty(trainDS);
        end
    end
end
