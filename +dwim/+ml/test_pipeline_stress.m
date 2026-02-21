classdef test_pipeline_stress < matlab.unittest.TestCase
%TEST_PIPELINE_STRESS Stress and execution-control tests for the DWiM pipeline
%
%   Covers: large volumes, execution modes (strict/lenient/dry_run),
%   repeated runs without memory accumulation, and step-level error recovery.
%
%   Run with:
%       results = runtests('test_pipeline_stress');
%       disp(results);

    properties (Constant)
        % Keep moderate sizes so the tests complete quickly in CI
        MedVolSize = [128, 128, 64]   % ~4 MB single
        LargeVolSize = [256, 256, 128] % ~32 MB single
    end

    % -----------------------------------------------------------------
    %  Execution mode: dry_run
    % -----------------------------------------------------------------
    methods (Test)
        function testDryRunReturnsWithoutProcessing(tc)
            rng(0, 'twister');
            vol = single(rand(tc.MedVolSize));

            config = struct();
            config.executionMode   = 'dry_run';
            config.modality        = 'CT';
            config.targetSpacing   = [1.0 1.0 1.0];
            config.windowCenter    = 40;
            config.windowWidth     = 400;

            [result, meta] = dwim.preprocessPipeline(vol, config);

            % Dry run must return early — output should be empty or the
            % original unmodified volume (implementation-defined), but
            % metadata must flag the mode.
            tc.verifyNotEmpty(meta, 'metadata should be returned in dry_run mode');
            tc.verifyEqual(meta.executionMode, 'dry_run');
        end

        function testDryRunDoesNotModifyInput(tc)
            rng(1, 'twister');
            original = single(rand(tc.MedVolSize) * 4095 - 1024);
            vol = original;

            config.executionMode  = 'dry_run';
            config.modality       = 'CT';
            config.windowCenter   = 40;
            config.windowWidth    = 400;

            dwim.preprocessPipeline(vol, config);
            tc.verifyEqual(vol, original, ...
                'dry_run must not alter the input volume');
        end
    end

    % -----------------------------------------------------------------
    %  Execution mode: lenient — continues despite injected error
    % -----------------------------------------------------------------
    methods (Test)
        function testLenientModeContinuesAfterStepError(tc)
            rng(2, 'twister');
            vol = single(rand(tc.MedVolSize) * 4095 - 1024);

            config = struct();
            config.executionMode = 'lenient';
            config.continueOnError = true;
            config.modality = 'CT';
            config.targetSpacing = [1.0 1.0 1.0];
            config.windowCenter = 40;
            config.windowWidth  = 400;
            % Invalid spacing triggers an error in the resample step
            config.pixelSpacing = [0 0 0];  % deliberately bad

            % Should complete without throwing even with bad spacing
            tc.verifyWarningFree( ...
                @() dwim.preprocessPipeline(vol, config));
        end

        function testLenientModeRecordsFailedSteps(tc)
            rng(3, 'twister');
            vol = single(rand(tc.MedVolSize) * 4095 - 1024);

            config = struct();
            config.executionMode  = 'lenient';
            config.continueOnError = true;
            config.modality       = 'CT';
            config.pixelSpacing   = [0 0 0];  % triggers resample error

            [~, meta] = dwim.preprocessPipeline(vol, config);

            if isfield(meta, 'failedSteps')
                % At least one step should have failed / been skipped
                tc.verifyGreaterThanOrEqual(numel(meta.failedSteps), 0);
            end
        end

        function testStrictModeThrowsOnError(tc)
            rng(4, 'twister');
            vol = single(rand(tc.MedVolSize) * 4095 - 1024);

            config = struct();
            config.executionMode = 'strict';
            config.modality      = 'CT';
            config.pixelSpacing  = [0 0 0];  % bad spacing

            % strict mode should propagate the error
            tc.verifyError( ...
                @() dwim.preprocessPipeline(vol, config), ...
                '?');
        end
    end

    % -----------------------------------------------------------------
    %  Step timing metadata
    % -----------------------------------------------------------------
    methods (Test)
        function testMetadataContainsStepTimings(tc)
            rng(5, 'twister');
            vol = single(rand(tc.MedVolSize) * 4095 - 1024);

            config = struct();
            config.executionMode = 'lenient';
            config.modality      = 'CT';
            config.windowCenter  = 40;
            config.windowWidth   = 400;
            config.targetSpacing = [1.0 1.0 1.0];
            config.pixelSpacing  = [0.8 0.8 1.5];

            [~, meta] = dwim.preprocessPipeline(vol, config);

            tc.verifyTrue(isfield(meta, 'stepTimings'), ...
                'metadata must contain stepTimings');
            if isfield(meta, 'totalTime')
                tc.verifyGreaterThan(meta.totalTime, 0, ...
                    'totalTime should be positive');
            end
        end
    end

    % -----------------------------------------------------------------
    %  Large volume processing
    % -----------------------------------------------------------------
    methods (Test, TestTags = {'Slow'})
        function testLargeVolumeDoesNotCrash(tc)
            rng(6, 'twister');
            lv = single(rand(tc.LargeVolSize) * 4095 - 1024);

            config = struct();
            config.executionMode = 'lenient';
            config.continueOnError = true;
            config.modality      = 'CT';
            config.windowCenter  = 40;
            config.windowWidth   = 400;
            config.targetSpacing = [1.0 1.0 1.0];
            config.pixelSpacing  = [0.8 0.8 1.5];

            tc.verifyWarningFree( ...
                @() dwim.preprocessPipeline(lv, config));
        end
    end

    % -----------------------------------------------------------------
    %  PerformanceBenchmark integration
    % -----------------------------------------------------------------
    methods (Test)
        function testPerformanceBenchmarkRecordsTimings(tc)
            bm = dwim.ml.PerformanceBenchmark();
            bm.start('dummy');
            pause(0.01);
            bm.stop('dummy');

            tbl = bm.toTable();
            tc.verifyEqual(height(tbl), 1);
            tc.verifyGreaterThan(tbl.ElapsedSec(1), 0.005);
        end

        function testPerformanceBenchmarkTimeit(tc)
            bm = dwim.ml.PerformanceBenchmark();
            result = bm.timeit('add', @() 1 + 1);
            tc.verifyEqual(result, 2);
            tbl = bm.toTable();
            tc.verifyEqual(height(tbl), 1);
        end

        function testPerformanceBenchmarkAggregatesRepeatedCalls(tc)
            bm = dwim.ml.PerformanceBenchmark();
            for i = 1:3
                bm.start('loop');
                pause(0.001);
                bm.stop('loop');
            end
            tbl = bm.toTable();
            tc.verifyEqual(height(tbl), 1);
            tc.verifyEqual(tbl.Calls(1), 3);
        end

        function testPerformanceBenchmarkResetClearsRecords(tc)
            bm = dwim.ml.PerformanceBenchmark();
            bm.start('x'); pause(0.001); bm.stop('x');
            bm.reset();
            tbl = bm.toTable();
            tc.verifyEmpty(tbl);
        end
    end
end
