classdef CalciumDeltaFCaculator < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        FileOperationsPanel      matlab.ui.container.Panel
        FramerateHzLabel         matlab.ui.control.Label
        FramerateEditField       matlab.ui.control.NumericEditField
        LoadDataButton           matlab.ui.control.Button
        BaselineParametersPanel  matlab.ui.container.Panel
        BaselineMethodDropDownLabel matlab.ui.control.Label
        BaselineMethodDropDown    matlab.ui.control.DropDown
        PercentileEditFieldLabel matlab.ui.control.Label
        PercentileEditField      matlab.ui.control.EditField
        PolynomialOrderLabel     matlab.ui.control.Label
        PolynomialOrderEditField matlab.ui.control.NumericEditField
        MovingWindowLabel        matlab.ui.control.Label
        MovingWindowEditField    matlab.ui.control.NumericEditField
        MovingPercentileLabel    matlab.ui.control.Label
        MovingPercentileEditField matlab.ui.control.NumericEditField
        RunAnalysisButton        matlab.ui.control.Button
        NeuronDisplayPanel       matlab.ui.container.Panel
        SelectNeuronLabel        matlab.ui.control.Label
        NeuronDropDown           matlab.ui.control.DropDown
        PreviousNeuronButton     matlab.ui.control.Button
        NextNeuronButton         matlab.ui.control.Button
        DisplayAllNeuronsButton  matlab.ui.control.Button
        SaveResultsButton        matlab.ui.control.Button
        AllNeuronsDisplayPanel   matlab.ui.container.Panel
        ScalebarSignalLabel      matlab.ui.control.Label
        ScalebarSignalEditField  matlab.ui.control.NumericEditField
        PlotScaleBarTimeCheckBox matlab.ui.control.CheckBox
        ScalebarTimeLabel        matlab.ui.control.Label
        ScalebarTimeEditField    matlab.ui.control.NumericEditField
        SelectedROILabel         matlab.ui.control.Label
        SelectedROIEditField     matlab.ui.control.EditField
        ROIIntervalLabel         matlab.ui.control.Label
        ROIIntervalEditField     matlab.ui.control.NumericEditField
        ColorMapLabel            matlab.ui.control.Label
        ColorMapEditField        matlab.ui.control.EditField
        UpdateAllNeuronsPlotButton matlab.ui.control.Button
        UIAxes                   matlab.ui.control.UIAxes
    end

    % Properties that store app data
    properties (Access = public)
        fluo_data                % Loaded fluorescence data (rows=neurons, cols=frames)
        dff_data                 % Calculated ΔF/F data
        time_vector              % Time vector for plotting
        framerate = 30           % Default framerate (Hz), updated from UI
        baseline_method = 'Percentile' % Default baseline method
        percentile_value = '10-20' % Default percentile (string for 10-20% average or single value)
        polynomial_order = 3      % Default polynomial order
        moving_window_sec = 20    % Default moving window size in seconds
        moving_percentile = 20    % Default moving percentile value
        current_neuron_id = 1     % ID of the currently displayed neuron
        display_all = false       % Flag to display all neurons
        results                  % Structure to store analysis results
        display_figure_handles   % Handle for the all neurons figure
        scalebar_signal = 1      % Default scalebar signal value
        plot_scale_bar_time = true % Default plot scale bar time
        scalebar_time = 10       % Default scalebar time length
        selected_roi_str = ''    % Default selected ROI string
        roi_interval = 1         % Default ROI interval
        color_map = 'turbo'      % Default color map
    end

    methods (Access = private)

        % Update plot display
        function UpdatePlot(app)
            if isempty(app.dff_data)
                cla(app.UIAxes);
                title(app.UIAxes, 'No ΔF/F data to plot.');
                xlabel(app.UIAxes, 'Time (s)');
                ylabel(app.UIAxes, 'ΔF/F');
                return;
            end
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            if app.display_all
                % Plot all neurons
                num_neurons = size(app.dff_data, 1);
                for n = 1:num_neurons
                    plot(app.UIAxes, app.time_vector, app.dff_data(n, :), ...
                        'DisplayName', sprintf('Neuron %d', n));
                end
                title(app.UIAxes, sprintf('ΔF/F for All %d Neurons', num_neurons));
            else
                % Plot single neuron
                neuron_id = app.current_neuron_id;
                if neuron_id > size(app.dff_data, 1)
                    cla(app.UIAxes);
                    title(app.UIAxes, 'Invalid neuron selected.');
                    return;
                end
                trace = app.dff_data(neuron_id, :);
                plot(app.UIAxes, app.time_vector, trace, 'b-', 'LineWidth', 1.5, ...
                    'DisplayName', sprintf('Neuron %d', neuron_id));
                title(app.UIAxes, sprintf('ΔF/F for Neuron %d', neuron_id));
            end
            xlabel(app.UIAxes, 'Time (s)');
            ylabel(app.UIAxes, 'ΔF/F');
            grid(app.UIAxes, 'on');
            if app.display_all
                legend(app.UIAxes, 'show');
            end
            hold(app.UIAxes, 'off');
        end

        % Calculate baseline F0
        function F0 = CalculateBaseline(app, fluo_trace)
            switch app.baseline_method
                case 'Percentile'
                    % Parse percentile input (e.g., '10-20' or '20')
                    perc_str = app.percentile_value;
                    if contains(perc_str, '-')
                        range = str2double(split(perc_str, '-'));
                        if length(range) ~= 2 || any(isnan(range)) || any(range < 0) || any(range > 100)
                            error('Invalid percentile range. Use format "10-20" or single value like "20".');
                        end
                        F0 = mean(prctile(fluo_trace, range));
                    else
                        perc = str2double(perc_str);
                        if isnan(perc) || perc < 0 || perc > 100
                            error('Invalid percentile value. Must be between 0 and 100.');
                        end
                        F0 = prctile(fluo_trace, perc);
                    end
                case 'Polynomial'
                    % Polynomial fitting
                    t = (1:length(fluo_trace))';
                    p = polyfit(t, fluo_trace', app.polynomial_order);
                    F0 = polyval(p, t)';
                case 'Moving Percentile'
                    % Moving percentile
                    w_size = round(app.moving_window_sec * app.framerate);
                    q_value = app.moving_percentile;
                    x_w = floor(w_size/2);
                    F0 = arrayfun(@(x) prctile(fluo_trace(max(1,x-x_w):min(length(fluo_trace),x+x_w)), q_value), ...
                        1:length(fluo_trace));
                otherwise
                    error('Unknown baseline method.');
            end
        end

        % Update all neurons plot
        function UpdateAllNeuronsPlot(app)
            if isempty(app.dff_data)
                uialert(app.UIFigure, 'No ΔF/F data to display.', 'Display Error');
                return;
            end
            % Check if figure handle exists and is valid
            if ~isfield(app, 'display_figure_handles') || isempty(app.display_figure_handles) || ~isvalid(app.display_figure_handles)
                app.display_figure_handles = figure('Name', 'All Neurons ΔF/F');
            end
            % Plot all neurons using plot_signal with parameters
            plot.plot_signal(app.dff_data, ...
                'frame_rate', app.framerate, ...
                'color_map', app.color_map, ...
                'signal_type', 'ΔF/F', ...
                'fig', app.display_figure_handles, ...
                'scalebar_signal', app.scalebar_signal, ...
                'plot_scale_bar_time', app.plot_scale_bar_time, ...
                'scalebar_time', app.scalebar_time, ...
                'selected_roi_str', app.selected_roi_str, ...
                'roi_interval', app.roi_interval);
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Startup function
        function startupFcn(app)
            assignin('base', 'app', app);
            app.RunAnalysisButton.Enable = 'off';
            app.NeuronDropDown.Enable = 'off';
            app.PreviousNeuronButton.Enable = 'off';
            app.NextNeuronButton.Enable = 'off';
            app.SaveResultsButton.Enable = 'off';
            app.DisplayAllNeuronsButton.Enable = 'off';
            app.UpdateAllNeuronsPlotButton.Enable = 'off';
            app.NeuronDropDown.Items = {'N/A'};
            app.NeuronDropDown.Value = 'N/A';
            title(app.UIAxes, 'Load Data to Begin');
            app.FramerateEditField.Value = app.framerate;
            app.PercentileEditField.Value = app.percentile_value;
            app.PolynomialOrderEditField.Value = app.polynomial_order;
            app.MovingWindowEditField.Value = app.moving_window_sec;
            app.MovingPercentileEditField.Value = app.moving_percentile;
            app.BaselineMethodDropDown.Value = app.baseline_method;
            app.ScalebarSignalEditField.Value = app.scalebar_signal;
            app.PlotScaleBarTimeCheckBox.Value = app.plot_scale_bar_time;
            app.ScalebarTimeEditField.Value = app.scalebar_time;
            app.SelectedROIEditField.Value = app.selected_roi_str;
            app.ROIIntervalEditField.Value = app.roi_interval;
            app.ColorMapEditField.Value = app.color_map;
        end

        % Load data button pushed
        function LoadDataButtonPushed(app, event)
            [fileName, filePath] = uigetfile({'*.mat';'*.xlsx;*.xls'}, 'Select Data File');
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'No file selected.', 'File Load');
                return;
            end
            fullPath = fullfile(filePath, fileName);
            [~, ~, ext] = fileparts(fileName);
            app.framerate = app.FramerateEditField.Value;
            try
                if strcmpi(ext, '.mat')
                    dataLoaded = load(fullPath);
                    varNames = fieldnames(dataLoaded);
                    if isempty(varNames)
                        uialert(app.UIFigure, 'MAT file is empty.', 'Load Error'); return;
                    end
                    if length(varNames) == 1
                        app.fluo_data = dataLoaded.(varNames{1});
                    else
                        [indx, tf] = listdlg('PromptString', {'Select fluorescence variable: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', varNames, ...
                            'Name', 'Select Variable', 'OKString', 'Select');
                        if tf
                            app.fluo_data = dataLoaded.(varNames{indx});
                        else
                            uialert(app.UIFigure, 'No variable selected.', 'Load Error'); return;
                        end
                    end
                elseif any(strcmpi(ext, {'.xlsx', '.xls'}))
                    sheetNames = sheetnames(fullPath);
                    if isempty(sheetNames)
                        uialert(app.UIFigure, 'Excel file has no sheets.', 'Load Error'); return;
                    end
                    if length(sheetNames) == 1
                        app.fluo_data = readmatrix(fullPath, 'Sheet', sheetNames{1});
                    else
                        [indx, tf] = listdlg('PromptString', {'Select sheet: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', sheetNames, ...
                            'Name', 'Select Sheet', 'OKString', 'Select');
                        if tf
                            app.fluo_data = readmatrix(fullPath, 'Sheet', sheetNames{indx});
                        else
                            uialert(app.UIFigure, 'No sheet selected.', 'Load Error'); return;
                        end
                    end
                else
                    uialert(app.UIFigure, 'Unsupported file type.', 'Load Error'); return;
                end
                if ~ismatrix(app.fluo_data) || isempty(app.fluo_data) || ~isnumeric(app.fluo_data)
                    uialert(app.UIFigure, 'Selected data is not a valid numeric matrix or is empty.', 'Data Error');
                    app.fluo_data = []; return;
                end
                [num_neurons, num_frames] = size(app.fluo_data);
                app.time_vector = (0:num_frames-1) / app.framerate;
                app.dff_data = [];
                app.RunAnalysisButton.Enable = 'on';
                app.NeuronDropDown.Enable = 'off';
                app.PreviousNeuronButton.Enable = 'off';
                app.NextNeuronButton.Enable = 'off';
                app.SaveResultsButton.Enable = 'off';
                app.DisplayAllNeuronsButton.Enable = 'off';
                app.UpdateAllNeuronsPlotButton.Enable = 'off';
                app.NeuronDropDown.Items = {'N/A'};
                app.NeuronDropDown.Value = 'N/A';
                cla(app.UIAxes);
                title(app.UIAxes, 'Data Loaded. Press "Run Analysis".');
                xlabel(app.UIAxes, 'Time (s)');
                ylabel(app.UIAxes, 'ΔF/F');
                grid(app.UIAxes, 'on');
                uialert(app.UIFigure, sprintf('Data loaded: %d neurons, %d frames.', num_neurons, num_frames), ...
                    'Load Success', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ['Error loading data: ' ME.message], 'Load Error');
                app.fluo_data = [];
                app.dff_data = [];
                app.RunAnalysisButton.Enable = 'off';
            end
        end

        % Run analysis button pushed
        function RunAnalysisButtonPushed(app, event)
            if isempty(app.fluo_data)
                uialert(app.UIFigure, 'No data loaded to analyze.', 'Analysis Error');
                return;
            end
            app.baseline_method = app.BaselineMethodDropDown.Value;
            app.percentile_value = app.PercentileEditField.Value;
            app.polynomial_order = app.PolynomialOrderEditField.Value;
            app.moving_window_sec = app.MovingWindowEditField.Value;
            app.moving_percentile = app.MovingPercentileEditField.Value;

            % Validate parameters
            try
                if app.framerate <= 0
                    error('Framerate must be positive.');
                end
                if strcmp(app.baseline_method, 'Percentile')
                    perc_str = app.percentile_value;
                    if contains(perc_str, '-')
                        range = str2double(split(perc_str, '-'));
                        if length(range) ~= 2 || any(isnan(range)) || any(range < 0) || any(range > 100)
                            error('Invalid percentile range. Use format "10-20" or single value like "20".');
                        end
                    else
                        perc = str2double(perc_str);
                        if isnan(perc) || perc < 0 || perc > 100
                            error('Invalid percentile value. Must be between 0 and 100.');
                        end
                    end
                elseif strcmp(app.baseline_method, 'Polynomial')
                    if app.polynomial_order < 1 || mod(app.polynomial_order, 1) ~= 0
                        error('Polynomial order must be a positive integer.');
                    end
                elseif strcmp(app.baseline_method, 'Moving Percentile')
                    if app.moving_window_sec <= 0
                        error('Moving window size must be positive.');
                    end
                    if app.moving_percentile < 0 || app.moving_percentile > 100
                        error('Moving percentile must be between 0 and 100.');
                    end
                end
            catch ME
                uialert(app.UIFigure, ['Parameter error: ' ME.message], 'Parameter Error');
                return;
            end

            % Compute ΔF/F
            progDlg = uiprogressdlg(app.UIFigure, 'Title', 'Computing ΔF/F', ...
                'Message', 'Initializing...', 'Cancelable', 'on');
            [num_neurons, num_frames] = size(app.fluo_data);
            app.dff_data = zeros(num_neurons, num_frames);
            app.results = struct('neuron_id', {}, 'dff_trace', {});
            cleanupObj = onCleanup(@() delete(progDlg));
            for n = 1:num_neurons
                if progDlg.CancelRequested
                    uialert(app.UIFigure, 'Analysis cancelled by user.', 'Analysis Cancelled');
                    app.dff_data = [];
                    app.results = [];
                    return;
                end
                progDlg.Message = sprintf('Processing Neuron %d/%d', n, num_neurons);
                progDlg.Value = n / num_neurons;
                fluo_trace = app.fluo_data(n, :);
                try
                    F0 = CalculateBaseline(app, fluo_trace);
                    app.dff_data(n, :) = (fluo_trace - F0) ./ F0;
                    app.results(n).neuron_id = n;
                    app.results(n).dff_trace = app.dff_data(n, :);
                catch ME
                    uialert(app.UIFigure, sprintf('Error computing ΔF/F for neuron %d: %s', n, ME.message), ...
                        'Computation Error');
                    app.dff_data = [];
                    app.results = [];
                    return;
                end
            end

            % Update UI
            neuronItems = arrayfun(@(x) sprintf('Neuron %d', x), 1:num_neurons, 'UniformOutput', false);
            if isempty(neuronItems)
                neuronItems = {'N/A'};
            end
            app.NeuronDropDown.Items = neuronItems;
            app.NeuronDropDown.Value = neuronItems{1};
            app.current_neuron_id = 1;
            app.NeuronDropDown.Enable = 'on';
            app.PreviousNeuronButton.Enable = 'on';
            app.NextNeuronButton.Enable = 'on';
            app.SaveResultsButton.Enable = 'on';
            app.DisplayAllNeuronsButton.Enable = 'on';
            app.UpdateAllNeuronsPlotButton.Enable = 'on';
            UpdatePlot(app);
        end

        % Neuron dropdown value changed
        function NeuronDropDownValueChanged(app, event)
            if strcmp(app.NeuronDropDown.Value, 'N/A') || isempty(app.dff_data)
                app.current_neuron_id = 0;
                UpdatePlot(app);
                return;
            end
            selectedNeuronStr = app.NeuronDropDown.Value;
            app.current_neuron_id = str2double(regexp(selectedNeuronStr, '\d+', 'match', 'once'));
            app.display_all = false; % Ensure single neuron view
            UpdatePlot(app);
        end

        % Previous neuron button pushed
        function PreviousNeuronButtonPushed(app, event)
            if isempty(app.dff_data) || app.current_neuron_id <= 1
                return;
            end
            app.current_neuron_id = app.current_neuron_id - 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.display_all = false;
            UpdatePlot(app);
        end

        % Next neuron button pushed
        function NextNeuronButtonPushed(app, event)
            if isempty(app.dff_data) || app.current_neuron_id >= size(app.dff_data, 1)
                return;
            end
            app.current_neuron_id = app.current_neuron_id + 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.display_all = false;
            UpdatePlot(app);
        end

        % Display all neurons button pushed
        function DisplayAllNeuronsButtonPushed(app, event)
            if isempty(app.dff_data)
                uialert(app.UIFigure, 'No ΔF/F data to display.', 'Display Error');
                return;
            end
            app.display_all = true;
            UpdatePlot(app);
        end

        % Update all neurons plot button pushed
        function UpdateAllNeuronsPlotButtonPushed(app, event)
            app.scalebar_signal = app.ScalebarSignalEditField.Value;
            app.plot_scale_bar_time = app.PlotScaleBarTimeCheckBox.Value;
            app.scalebar_time = app.ScalebarTimeEditField.Value;
            app.selected_roi_str = app.SelectedROIEditField.Value;
            app.roi_interval = app.ROIIntervalEditField.Value;
            app.color_map = app.ColorMapEditField.Value;
            UpdateAllNeuronsPlot(app);
        end

        % Save results button pushed
        function SaveResultsButtonPushed(app, event)
            if isempty(app.dff_data) || isempty(app.results)
                uialert(app.UIFigure, 'No results to save.', 'Save Error');
                return;
            end
            [fileName, filePath] = uiputfile({'*.mat', 'MAT-file (*.mat)'}, 'Save ΔF/F Results');
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'Save cancelled.', 'Save Operation');
                return;
            end
            [~, name, ~] = fileparts(fileName);
            matPath = fullfile(filePath, [name '.mat']);
            xlsxPath = fullfile(filePath, [name '.xlsx']);
            raw_sig = app.fluo_data;
            dff_sig = app.dff_data;
            time_vector = app.time_vector;
            framerate = app.framerate;
            baseline_method = app.baseline_method;
            percentile_value = app.percentile_value;
            polynomial_order = app.polynomial_order;
            moving_window_sec = app.moving_window_sec;
            moving_percentile = app.moving_percentile;
            scalebar_signal = app.scalebar_signal;
            plot_scale_bar_time = app.plot_scale_bar_time;
            scalebar_time = app.scalebar_time;
            selected_roi_str = app.selected_roi_str;
            roi_interval = app.roi_interval;
            color_map = app.color_map;
            analysis_date = datestr(now);
            try
                % Save .mat file
                save(matPath, 'raw_sig', 'dff_sig', 'time_vector', 'framerate', ...
                    'baseline_method', 'percentile_value', 'polynomial_order', ...
                    'moving_window_sec', 'moving_percentile', 'scalebar_signal', ...
                    'plot_scale_bar_time', 'scalebar_time', 'selected_roi_str', ...
                    'roi_interval', 'color_map', 'analysis_date', '-v7.3');
                % Save .xlsx file
                writematrix(dff_sig, xlsxPath, 'Sheet', 'dff_sig');
                writematrix(raw_sig, xlsxPath, 'Sheet', 'raw_sig');
                uialert(app.UIFigure, sprintf('Results saved to:\n%s\n%s', matPath, xlsxPath), ...
                    'Save Success', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ['Error saving results: ' ME.message], 'Save Error');
            end
        end

        % Baseline method dropdown value changed
        function BaselineMethodDropDownValueChanged(app, event)
            app.baseline_method = app.BaselineMethodDropDown.Value;
            % Enable/disable relevant parameter fields
            app.PercentileEditField.Enable = strcmp(app.baseline_method, 'Percentile');
            app.PolynomialOrderEditField.Enable = strcmp(app.baseline_method, 'Polynomial');
            app.MovingWindowEditField.Enable = strcmp(app.baseline_method, 'Moving Percentile');
            app.MovingPercentileEditField.Enable = strcmp(app.baseline_method, 'Moving Percentile');
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UI components
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 700];
            app.UIFigure.Name = 'Calcium ΔF/F Calculator';

            % File Operations Panel
            app.FileOperationsPanel = uipanel(app.UIFigure);
            app.FileOperationsPanel.Title = 'File Operations';
            app.FileOperationsPanel.Position = [20 580 300 100];
            app.FramerateHzLabel = uilabel(app.FileOperationsPanel);
            app.FramerateHzLabel.HorizontalAlignment = 'right';
            app.FramerateHzLabel.Position = [10 40 90 22];
            app.FramerateHzLabel.Text = 'Framerate (Hz):';
            app.FramerateEditField = uieditfield(app.FileOperationsPanel, 'numeric');
            app.FramerateEditField.ValueDisplayFormat = '%.2f';
            app.FramerateEditField.Position = [110 40 100 22];
            app.FramerateEditField.Value = app.framerate;
            app.LoadDataButton = uibutton(app.FileOperationsPanel, 'push');
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.Position = [10 10 100 22];
            app.LoadDataButton.Text = 'Load Data';

            % Baseline Parameters Panel
            app.BaselineParametersPanel = uipanel(app.UIFigure);
            app.BaselineParametersPanel.Title = 'Baseline Parameters';
            app.BaselineParametersPanel.Position = [20 310 300 260];
            app.BaselineMethodDropDownLabel = uilabel(app.BaselineParametersPanel);
            app.BaselineMethodDropDownLabel.HorizontalAlignment = 'right';
            app.BaselineMethodDropDownLabel.Position = [10 210 100 22];
            app.BaselineMethodDropDownLabel.Text = 'Baseline Method:';
            app.BaselineMethodDropDown = uidropdown(app.BaselineParametersPanel);
            app.BaselineMethodDropDown.Items = {'Percentile', 'Polynomial', 'Moving Percentile'};
            app.BaselineMethodDropDown.ValueChangedFcn = createCallbackFcn(app, @BaselineMethodDropDownValueChanged, true);
            app.BaselineMethodDropDown.Position = [120 210 150 22];
            app.BaselineMethodDropDown.Value = app.baseline_method;
            app.PercentileEditFieldLabel = uilabel(app.BaselineParametersPanel);
            app.PercentileEditFieldLabel.HorizontalAlignment = 'right';
            app.PercentileEditFieldLabel.Position = [10 180 100 22];
            app.PercentileEditFieldLabel.Text = 'Percentile (e.g., 10-20):';
            app.PercentileEditField = uieditfield(app.BaselineParametersPanel, 'text');
            app.PercentileEditField.Position = [120 180 150 22];
            app.PercentileEditField.Value = app.percentile_value;
            app.PolynomialOrderLabel = uilabel(app.BaselineParametersPanel);
            app.PolynomialOrderLabel.HorizontalAlignment = 'right';
            app.PolynomialOrderLabel.Position = [10 150 100 22];
            app.PolynomialOrderLabel.Text = 'Polynomial Order:';
            app.PolynomialOrderEditField = uieditfield(app.BaselineParametersPanel, 'numeric');
            app.PolynomialOrderEditField.ValueDisplayFormat = '%d';
            app.PolynomialOrderEditField.Position = [120 150 150 22];
            app.PolynomialOrderEditField.Value = app.polynomial_order;
            app.PolynomialOrderEditField.Enable = 'off';
            app.MovingWindowLabel = uilabel(app.BaselineParametersPanel);
            app.MovingWindowLabel.HorizontalAlignment = 'right';
            app.MovingWindowLabel.Position = [10 120 100 22];
            app.MovingWindowLabel.Text = 'Window Size (s):';
            app.MovingWindowEditField = uieditfield(app.BaselineParametersPanel, 'numeric');
            app.MovingWindowEditField.ValueDisplayFormat = '%.2f';
            app.MovingWindowEditField.Position = [120 120 150 22];
            app.MovingWindowEditField.Value = app.moving_window_sec;
            app.MovingWindowEditField.Enable = 'off';
            app.MovingPercentileLabel = uilabel(app.BaselineParametersPanel);
            app.MovingPercentileLabel.HorizontalAlignment = 'right';
            app.MovingPercentileLabel.Position = [10 90 100 22];
            app.MovingPercentileLabel.Text = 'Percentile:';
            app.MovingPercentileEditField = uieditfield(app.BaselineParametersPanel, 'numeric');
            app.MovingPercentileEditField.ValueDisplayFormat = '%.2f';
            app.MovingPercentileEditField.Position = [120 90 150 22];
            app.MovingPercentileEditField.Value = app.moving_percentile;
            app.MovingPercentileEditField.Enable = 'off';
            app.RunAnalysisButton = uibutton(app.BaselineParametersPanel, 'push');
            app.RunAnalysisButton.ButtonPushedFcn = createCallbackFcn(app, @RunAnalysisButtonPushed, true);
            app.RunAnalysisButton.Position = [10 10 100 22];
            app.RunAnalysisButton.Text = 'Run Analysis';

            % Neuron Display Panel
            app.NeuronDisplayPanel = uipanel(app.UIFigure);
            app.NeuronDisplayPanel.Title = 'Neuron Display';
            app.NeuronDisplayPanel.Position = [20 180 300 120];
            app.SelectNeuronLabel = uilabel(app.NeuronDisplayPanel);
            app.SelectNeuronLabel.HorizontalAlignment = 'right';
            app.SelectNeuronLabel.Position = [10 70 85 22];
            app.SelectNeuronLabel.Text = 'Select Neuron:';
            app.NeuronDropDown = uidropdown(app.NeuronDisplayPanel);
            app.NeuronDropDown.ValueChangedFcn = createCallbackFcn(app, @NeuronDropDownValueChanged, true);
            app.NeuronDropDown.Position = [105 70 170 22];
            app.PreviousNeuronButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.PreviousNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousNeuronButtonPushed, true);
            app.PreviousNeuronButton.Position = [10 40 85 22];
            app.PreviousNeuronButton.Text = 'Previous';
            app.NextNeuronButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.NextNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @NextNeuronButtonPushed, true);
            app.NextNeuronButton.Position = [105 40 85 22];
            app.NextNeuronButton.Text = 'Next';
            app.DisplayAllNeuronsButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.DisplayAllNeuronsButton.ButtonPushedFcn = createCallbackFcn(app, @DisplayAllNeuronsButtonPushed, true);
            app.DisplayAllNeuronsButton.Text = 'Display All Neurons';
            app.DisplayAllNeuronsButton.Position = [10 10 150 22];
            app.SaveResultsButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.SaveResultsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveResultsButtonPushed, true);
            app.SaveResultsButton.Position = [170 10 100 22];
            app.SaveResultsButton.Text = 'Save Results';

            % All Neurons Display Panel
            app.AllNeuronsDisplayPanel = uipanel(app.UIFigure);
            app.AllNeuronsDisplayPanel.Title = 'All Neurons Display';
            app.AllNeuronsDisplayPanel.Position = [20 50 300 120];
            app.ScalebarSignalLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ScalebarSignalLabel.HorizontalAlignment = 'right';
            app.ScalebarSignalLabel.Position = [10 90 80 22];
            app.ScalebarSignalLabel.Text = 'Scalebar Signal:';
            app.ScalebarSignalEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ScalebarSignalEditField.Position = [100 90 170 22];
            app.ScalebarSignalEditField.Value = app.scalebar_signal;
            app.PlotScaleBarTimeCheckBox = uicheckbox(app.AllNeuronsDisplayPanel);
            app.PlotScaleBarTimeCheckBox.Text = 'Plot Time Scalebar';
            app.PlotScaleBarTimeCheckBox.Position = [10 70 120 22];
            app.PlotScaleBarTimeCheckBox.Value = app.plot_scale_bar_time;
            app.ScalebarTimeLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ScalebarTimeLabel.HorizontalAlignment = 'right';
            app.ScalebarTimeLabel.Position = [130 70 80 22];
            app.ScalebarTimeLabel.Text = 'Scalebar Time:';
            app.ScalebarTimeEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ScalebarTimeEditField.Position = [220 70 50 22];
            app.ScalebarTimeEditField.Value = app.scalebar_time;
            app.SelectedROILabel = uilabel(app.AllNeuronsDisplayPanel);
            app.SelectedROILabel.HorizontalAlignment = 'right';
            app.SelectedROILabel.Position = [10 50 80 22];
            app.SelectedROILabel.Text = 'Selected ROI:';
            app.SelectedROIEditField = uieditfield(app.AllNeuronsDisplayPanel, 'text');
            app.SelectedROIEditField.Position = [100 50 170 22];
            app.SelectedROIEditField.Value = app.selected_roi_str;
            app.ROIIntervalLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ROIIntervalLabel.HorizontalAlignment = 'right';
            app.ROIIntervalLabel.Position = [10 30 80 22];
            app.ROIIntervalLabel.Text = 'ROI Interval:';
            app.ROIIntervalEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ROIIntervalEditField.Position = [100 30 170 22];
            app.ROIIntervalEditField.Value = app.roi_interval;
            app.ColorMapLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ColorMapLabel.HorizontalAlignment = 'right';
            app.ColorMapLabel.Position = [10 10 80 22];
            app.ColorMapLabel.Text = 'Color Map:';
            app.ColorMapEditField = uieditfield(app.AllNeuronsDisplayPanel, 'text');
            app.ColorMapEditField.Position = [100 10 170 22];
            app.ColorMapEditField.Value = app.color_map;
            app.UpdateAllNeuronsPlotButton = uibutton(app.AllNeuronsDisplayPanel, 'push');
            app.UpdateAllNeuronsPlotButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateAllNeuronsPlotButtonPushed, true);
            app.UpdateAllNeuronsPlotButton.Position = [10 90 150 22];
            app.UpdateAllNeuronsPlotButton.Text = 'Update Plot';

            % UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'ΔF/F Signal')
            xlabel(app.UIAxes, 'Time (s)')
            ylabel(app.UIAxes, 'ΔF/F')
            app.UIAxes.Position = [350 50 800 600];
            grid(app.UIAxes, 'on');

            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)
        function app = CalciumDeltaFCaculator
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
            if isfield(app, 'display_figure_handles') && isvalid(app.display_figure_handles)
                delete(app.display_figure_handles);
            end
        end
    end
end