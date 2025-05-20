classdef CalciumDeltaFCaculator_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                     matlab.ui.Figure
        SetPlotColorButton           matlab.ui.control.Button
        SetHeightButton              matlab.ui.control.Button
        SetWidthButton               matlab.ui.control.Button
        ExportPlotButton             matlab.ui.control.Button
        SignalTypeDropDown           matlab.ui.control.DropDown
        AllNeuronsDisplayPanel       matlab.ui.container.Panel
        DisplayAllNeuronsButton      matlab.ui.control.Button
        ScalebarSignalLabel          matlab.ui.control.Label
        ScalebarSignalEditField      matlab.ui.control.NumericEditField
        PlotScaleBarTimeCheckBox     matlab.ui.control.CheckBox
        ScalebarTimeLabel            matlab.ui.control.Label
        ScalebarTimeEditField        matlab.ui.control.NumericEditField
        SelectedROILabel             matlab.ui.control.Label
        SelectedROIEditField         matlab.ui.control.EditField
        ROIIntervalLabel             matlab.ui.control.Label
        ROIIntervalEditField         matlab.ui.control.NumericEditField
        ColorMapLabel                matlab.ui.control.Label
        ColorMapEditField            matlab.ui.control.EditField
        NeuronDisplayPanel           matlab.ui.container.Panel
        SelectNeuronLabel            matlab.ui.control.Label
        NeuronDropDown               matlab.ui.control.DropDown
        PreviousNeuronButton         matlab.ui.control.Button
        NextNeuronButton             matlab.ui.control.Button
        ExportAllNeuronsButton       matlab.ui.control.Button
        DeltaFOverFCalculatePanel    matlab.ui.container.Panel
        CalculateZScoreCheckBox      matlab.ui.control.CheckBox
        BaselineMethodDropDownLabel  matlab.ui.control.Label
        BaselineMethodDropDown       matlab.ui.control.DropDown
        PercentileEditFieldLabel     matlab.ui.control.Label
        PercentileEditField          matlab.ui.control.EditField
        BaselineTimeLabel            matlab.ui.control.Label
        BaselineTimeEditField        matlab.ui.control.EditField
        PolynomialOrderLabel         matlab.ui.control.Label
        PolynomialOrderEditField     matlab.ui.control.NumericEditField
        MovingWindowLabel            matlab.ui.control.Label
        MovingWindowEditField        matlab.ui.control.NumericEditField
        MovingPercentileLabel        matlab.ui.control.Label
        MovingPercentileEditField    matlab.ui.control.NumericEditField
        RunAnalysisButton            matlab.ui.control.Button
        SaveResultsButton            matlab.ui.control.Button
        FileOperationsPanel          matlab.ui.container.Panel
        FramerateHzLabel             matlab.ui.control.Label
        FramerateEditField           matlab.ui.control.NumericEditField
        LoadDataButton               matlab.ui.control.Button
        LoadedFileLabel              matlab.ui.control.Label
        UIAxes                       matlab.ui.control.UIAxes
    end

    % Properties that store app data
    properties (Access = public)
        selectedFolder = '' % Selected folder for data
        fluo_data % Loaded fluorescence data (rows=neurons, cols=frames)
        dff_data % Calculated ΔF/F data
        zscore_dff_data % Calculated z-score ΔF/F data
        time_vector % Time vector for plotting
        framerate = 3.6 % Default framerate (Hz)
        calculate_zscore = false % Flag to calculate z-score ΔF/F
        baseline_method = 'Percentile' % Default baseline method
        percentile_value = '10:20' % Default percentile
        baseline_time = 'all' % Default baseline time range
        polynomial_order = 3 % Default polynomial order
        moving_window_sec = 20 % Default moving window size in seconds
        moving_percentile = 20 % Default moving percentile value
        current_neuron_id = 1 % ID of the currently displayed neuron
        display_all = false % Flag to display all neurons
        results % Structure to store analysis results
        display_figure_handles % Handle for the all neurons figure
        scalebar_signal = 1 % Default scalebar signal value
        plot_scale_bar_time = true % Default plot scale bar time
        scalebar_time = 10 % Default scalebar time length
        selected_roi_str = '' % Default selected ROI string
        roi_interval = 1 % Default ROI interval
        color_map = 'turbo' % Default color map
        signal_type = 'Raw Signal' % Current signal type to display
        loaded_file_name = '' % Name of the loaded file
        current_plot_color = [0 0.4470 0.7410] % NEW: Property to store current plot color (default MATLAB blue)
    end

    methods (Access = private)

        % Update plot display
        function UpdatePlot(app)
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');

            if isempty(app.fluo_data)
                title(app.UIAxes, 'No data to plot.');
                xlabel(app.UIAxes, 'Time (s)');
                ylabel(app.UIAxes, 'Signal');
                return;
            end
            
            % Ensure time_vector is up-to-date if framerate changed
            if ~isempty(app.fluo_data) && (length(app.time_vector) ~= size(app.fluo_data,2) || abs(app.time_vector(2) - 1/app.framerate) > 1e-9 ) % Check if recalc needed
                [~, num_frames] = size(app.fluo_data);
                 app.time_vector = (0:num_frames-1) / app.framerate;
            end


            ylabel_str = 'Raw Signal';
            current_data_to_plot = [];

            switch app.signal_type
                case 'Raw Signal'
                    ylabel_str = 'Raw Signal';
                    current_data_to_plot = app.fluo_data;
                case 'ΔF/F'
                    ylabel_str = 'ΔF/F';
                    if isempty(app.dff_data)
                        title(app.UIAxes, 'No ΔF/F data. Please run analysis.');
                        xlabel(app.UIAxes, 'Time (s)');
                        ylabel(app.UIAxes, ylabel_str);
                        return;
                    end
                    current_data_to_plot = app.dff_data;
                case 'z-score ΔF/F'
                    ylabel_str = 'z-score ΔF/F';
                    if isempty(app.zscore_dff_data)
                        title(app.UIAxes, 'No z-score ΔF/F data. Please run analysis or enable z-score calculation.');
                        xlabel(app.UIAxes, 'Time (s)');
                        ylabel(app.UIAxes, ylabel_str);
                        return;
                    end
                    current_data_to_plot = app.zscore_dff_data;
                otherwise
                    title(app.UIAxes, 'Unknown signal type selected.');
                    return;
            end
            
            if isempty(current_data_to_plot) && ~strcmp(app.signal_type, 'Raw Signal') % For dF/F or Z-score if data is missing
                 title(app.UIAxes, sprintf('%s data not available. Run analysis.', app.signal_type));
                 xlabel(app.UIAxes, 'Time (s)');
                 ylabel(app.UIAxes, ylabel_str);
                 return;
            end

            if app.display_all
                num_neurons = size(current_data_to_plot, 1);
                for n = 1:num_neurons
                    plot(app.UIAxes, app.time_vector, current_data_to_plot(n, :), ...
                        'DisplayName', sprintf('Neuron %d', n)); % Uses default color cycling
                end
                title(app.UIAxes, sprintf('%s for All %d Neurons', app.signal_type, num_neurons));
            else
                neuron_id = app.current_neuron_id;
                if neuron_id == 0 || neuron_id > size(current_data_to_plot, 1)
                    title(app.UIAxes, 'Invalid or no neuron selected.');
                    xlabel(app.UIAxes, 'Time (s)');
                    ylabel(app.UIAxes, ylabel_str);
                    return;
                end
                trace = current_data_to_plot(neuron_id, :);
                % MODIFIED: Use app.current_plot_color for single neuron trace
                plot(app.UIAxes, app.time_vector, trace, 'Color', app.current_plot_color, 'LineWidth', 1.5, ...
                    'DisplayName', sprintf('Neuron %d', neuron_id));
                title(app.UIAxes, sprintf('%s for Neuron %d', app.signal_type, neuron_id));
            end
            xlabel(app.UIAxes, 'Time (s)');
            ylabel(app.UIAxes, ylabel_str);
            grid(app.UIAxes, 'on');
            if app.display_all
                legend(app.UIAxes, 'show', 'Location', 'eastoutside');
            end
            hold(app.UIAxes, 'off');
            xlim(app.UIAxes, [app.time_vector(1), app.time_vector(end)]); % Ensure x-axis limits are correct
        end

        % Export plot to external figure
        function ExportPlotButtonPushed(app, event)
            if isempty(app.fluo_data) || app.current_neuron_id == 0
                uialert(app.UIFigure, 'No data or neuron selected to export.', 'Export Error');
                return;
            end

            fig = figure('Name', sprintf('%s - Neuron %d', app.signal_type, app.current_neuron_id));
            ax = axes(fig);
            
            trace = [];
            ylabel_str = app.signal_type;

            switch app.signal_type
                case 'Raw Signal'
                    trace = app.fluo_data(app.current_neuron_id, :);
                case 'ΔF/F'
                    if isempty(app.dff_data)
                        uialert(app.UIFigure, 'ΔF/F data not available for export.', 'Export Error');
                        close(fig); return;
                    end
                    trace = app.dff_data(app.current_neuron_id, :);
                case 'z-score ΔF/F'
                     if isempty(app.zscore_dff_data)
                        uialert(app.UIFigure, 'z-score ΔF/F data not available for export.', 'Export Error');
                        close(fig); return;
                    end
                    trace = app.zscore_dff_data(app.current_neuron_id, :);
                otherwise
                    uialert(app.UIFigure, 'Unknown signal type selected for export.', 'Export Error');
                    close(fig); return;
            end
            
            if isempty(trace)
                 uialert(app.UIFigure, 'Selected trace data is empty.', 'Export Error');
                 close(fig); return;
            end

            % MODIFIED: Use app.current_plot_color for exported single neuron plot
            plot(ax, app.time_vector, trace, 'Color', app.current_plot_color, 'LineWidth', 1.5);
            title(ax, sprintf('%s for Neuron %d', app.signal_type, app.current_neuron_id));
            xlabel(ax, 'Time (s)');
            ylabel(ax, ylabel_str);
            grid(ax, 'on');
            xlim(ax, [app.time_vector(1), app.time_vector(end)]);
        end

        % Set axes width
        function SetWidthButtonPushed(app, event)
            prompt = {'Enter new width for UIAxes (pixels):'};
            dlgtitle = 'Set Axes Width';
            dims = [1 50];
            definput = {num2str(app.UIAxes.Position(3))};
            answer = inputdlg(prompt, dlgtitle, dims, definput);

            if ~isempty(answer)
                new_width = str2double(answer{1});
                if isnan(new_width) || new_width < 100
                    uialert(app.UIFigure, 'Invalid width. Must be a number >= 100.', 'Input Error');
                    return;
                end
                app.UIAxes.Position(3) = new_width;
                uialert(app.UIFigure, sprintf('UIAxes width set to %d pixels.', new_width), ...
                    'Width Updated', 'Icon', 'success');
            end
        end

        % Set axes height
        function SetHeightButtonPushed(app, event)
            prompt = {'Enter new height for UIAxes (pixels):'};
            dlgtitle = 'Set Axes Height';
            dims = [1 50];
            definput = {num2str(app.UIAxes.Position(4))};
            answer = inputdlg(prompt, dlgtitle, dims, definput);

            if ~isempty(answer)
                new_height = str2double(answer{1});
                if isnan(new_height) || new_height < 100
                    uialert(app.UIFigure, 'Invalid height. Must be a number >= 100.', 'Input Error');
                    return;
                end
                app.UIAxes.Position(4) = new_height;
                uialert(app.UIFigure, sprintf('UIAxes height set to %d pixels.', new_height), ...
                    'Height Updated', 'Icon', 'success');
            end
        end
        
        % NEW: Callback for Set Plot Color button
        function SetPlotColorButtonPushed(app, event)
            % Use the current plot color as the default in the color picker
            selected_color = uisetcolor(app.current_plot_color, 'Select Plot Color');

            % uisetcolor returns the input color if the user cancels, 
            % or the new color if the user clicks OK.
            % It returns 0 if the figure is closed without clicking OK/Cancel (e.g., window X button).
            if isequal(size(selected_color), [1 3]) % Check if a valid color was returned (not 0 from closing window)
                if ~isequal(selected_color, app.current_plot_color)
                    figure(app.UIFigure); % Bring the app figure to front
                    app.current_plot_color = selected_color;
                    UpdatePlot(app); % Redraw the plot with the new color
                    uialert(app.UIFigure, 'Plot color updated.', 'Color Updated', 'Icon', 'success');
                % else: color is the same as before (could be cancel, or picked same color)
                % No need for an alert if the color didn't change.
                end
            % else: uisetcolor dialog was closed abruptly, selected_color might be 0. Do nothing.
            end
        end


        % Calculate baseline F0
        function F0 = CalculateBaseline(app, fluo_trace)
            if ~strcmpi(app.baseline_time, 'all')
                try
                    time_range_str = app.baseline_time;
                    if contains(time_range_str, ':') % Format like "1:30" or "10.5:20.0"
                        parts = strsplit(time_range_str, ':');
                        if length(parts) ~= 2
                             error('Invalid time range format. Use "all" or range like "1:30" or "10.5:20.0".');
                        end
                        time_range = [str2double(parts{1}), str2double(parts{2})];
                        if any(isnan(time_range)) || time_range(1) < 0 || time_range(2) < time_range(1)
                             error('Invalid numeric values in time range or end time < start time.');
                        end
                        start_frame = max(1, round(time_range(1) * app.framerate) + 1); % +1 for 1-based indexing
                        end_frame = min(length(fluo_trace), round(time_range(2) * app.framerate));

                    else % Format like "30" (interpreted as 0 to 30s)
                        single_time = str2double(time_range_str);
                        if isnan(single_time) || single_time < 0
                            error('Invalid single time value for baseline. Must be non-negative.');
                        end
                        start_frame = 1;
                        end_frame = min(length(fluo_trace), round(single_time * app.framerate));
                    end
                    if start_frame > end_frame % Handle cases where range is too small or outside data
                        warning('Baseline time range resulted in empty or invalid frame selection. Using full trace for this neuron.');
                        baseline_trace = fluo_trace;
                    else
                        baseline_trace = fluo_trace(start_frame:end_frame);
                    end

                catch ME
                    warning('Invalid time range specified (%s): %s. Using all data for this neuron.', app.baseline_time, ME.message);
                    baseline_trace = fluo_trace;
                end
            else
                baseline_trace = fluo_trace;
            end
            
            if isempty(baseline_trace) % Fallback if selection somehow results in empty
                warning('Baseline trace is empty after time selection. Using full trace for this neuron.');
                baseline_trace = fluo_trace;
            end

            switch app.baseline_method
                case 'Percentile'
                    perc_str = app.percentile_value;
                    if contains(perc_str, ':')
                        range = str2num(perc_str);
                        if length(range) < 2 || any(isnan(range)) || any(range < 0) || any(range > 100)
                            error('Invalid percentile range. Use format "10:20" or single value like "20".');
                        end
                        F0 = mean(prctile(baseline_trace, range));
                    else
                        perc = str2double(perc_str);
                        if isnan(perc) || perc < 0 || perc > 100
                            error('Invalid percentile value. Must be between 0 and 100.');
                        end
                        F0 = prctile(baseline_trace, perc);
                    end
                case 'Polynomial'
                    t = (1:length(fluo_trace))';
                    p = polyfit(t, fluo_trace', app.polynomial_order);
                    F0 = polyval(p, t)';
                case 'Moving Percentile'
                    w_size = round(app.moving_window_sec * app.framerate);
                    if w_size < 1, w_size = 1; end % Ensure window size is at least 1
                    q_value = app.moving_percentile;
                    x_w = floor(w_size/2);
                    F0 = zeros(1, length(fluo_trace)); % Preallocate
                    for i = 1:length(fluo_trace)
                        idx_start = max(1, i - x_w);
                        idx_end = min(length(fluo_trace), i + x_w);
                        F0(i) = prctile(fluo_trace(idx_start:idx_end), q_value);
                    end
                otherwise
                    error('Unknown baseline method.');
            end
            if any(F0 <= 0) % Prevent division by zero or negative F0
                warning('Baseline (F0) calculation resulted in non-positive values. Clamping to a small positive value to avoid errors.');
                F0(F0 <= 0) = 1e-6; % A small positive number
            end
        end

        % Update all neurons plot
        function UpdateAllNeuronsPlot(app)
            if isempty(app.fluo_data) % Check raw data first
                uialert(app.UIFigure, 'No data loaded to display.', 'Display Error');
                return;
            end

            plot_signal_data = [];
            current_signal_type_for_plot = app.signal_type; % Use the app's current signal type

            switch current_signal_type_for_plot
                case 'Raw Signal'
                    plot_signal_data = app.fluo_data;
                case 'ΔF/F'
                    if isempty(app.dff_data)
                        uialert(app.UIFigure, 'ΔF/F data not available. Please run analysis.', 'Display Error');
                        return;
                    end
                    plot_signal_data = app.dff_data;
                case 'z-score ΔF/F'
                    if isempty(app.zscore_dff_data)
                        uialert(app.UIFigure, 'Z-score ΔF/F data not available. Please run analysis with z-score enabled.', 'Display Error');
                        return;
                    end
                    plot_signal_data = app.zscore_dff_data;
                otherwise
                    uialert(app.UIFigure, 'Invalid signal type for "All Neurons Plot".', 'Display Error');
                    return;
            end
            
            if isempty(plot_signal_data)
                 uialert(app.UIFigure, ['No data available for signal type: ' current_signal_type_for_plot], 'Display Error');
                 return;
            end

            if ~isfield(app, 'display_figure_handles') || isempty(app.display_figure_handles) || ~isvalid(app.display_figure_handles)
                app.display_figure_handles = figure('Name', ['All Neurons - ' current_signal_type_for_plot]);
            else
                figure(app.display_figure_handles); % Bring to front
                clf(app.display_figure_handles); % Clear previous content
                app.display_figure_handles.Name = ['All Neurons - ' current_signal_type_for_plot];
            end
            
            % Call external plot_signal function (assuming it exists and is on path)
            % Ensure plot.plot_signal can handle the 'fig' argument correctly
            % and that it uses app.time_vector or recalculates based on framerate.
            try
                plot.plot_signal(plot_signal_data, ...
                    'frame_rate', app.framerate, ...
                    'color_map', app.color_map, ...
                    'signal_type', current_signal_type_for_plot, ...
                    'fig', app.display_figure_handles, ...
                    'scalebar_signal', app.scalebar_signal, ...
                    'plot_scale_bar_time', app.plot_scale_bar_time, ...
                    'scalebar_time', app.scalebar_time, ...
                    'selected_roi_str', app.selected_roi_str, ...
                    'roi_interval', app.roi_interval);
            catch ME_plot_signal
                uialert(app.UIFigure, ['Error calling plot_signal: ' ME_plot_signal.message], 'Plotting Error');
                disp(ME_plot_signal.getReport);
            end
        end
        
        % Callback for FramerateEditField value changed
        function FramerateEditFieldValueChanged(app, event)
            new_framerate = app.FramerateEditField.Value;
            if isnan(new_framerate) || new_framerate <= 0
                uialert(app.UIFigure, 'Framerate must be a positive number.', 'Input Error');
                app.FramerateEditField.Value = app.framerate; % Revert to old value
                return;
            end
            
            app.framerate = new_framerate; % Update the stored framerate
            
            if ~isempty(app.fluo_data)
                % Recalculate time vector
                [~, num_frames] = size(app.fluo_data);
                app.time_vector = (0:num_frames-1) / app.framerate;
                
                % Update the plot
                UpdatePlot(app);
                
                % Update all neurons plot if it's open and valid
                if isfield(app, 'display_figure_handles') && ~isempty(app.display_figure_handles) && isvalid(app.display_figure_handles)
                    if app.display_all % Only if it was meant to be displaying all neurons
                          UpdateAllNeuronsPlot(app); % This will replot with new framerate/time_vector
                    end
                end
            else
            end
        end

        % Callback for Export All Neurons button
        function ExportAllNeuronsButtonPushed(app, event)
            if isempty(app.fluo_data)
                uialert(app.UIFigure, 'No data loaded to export.', 'Export Error');
                return;
            end

            selected_signal_type = app.SignalTypeDropDown.Value;
            data_to_export = [];
            file_suffix_type = '';

            switch selected_signal_type
                case 'Raw Signal'
                    data_to_export = app.fluo_data;
                    file_suffix_type = 'Raw_Signal';
                case 'ΔF/F'
                    if isempty(app.dff_data)
                        uialert(app.UIFigure, 'ΔF/F data not available. Please run analysis first.', 'Export Error');
                        return;
                    end
                    data_to_export = app.dff_data;
                    file_suffix_type = 'DeltaF_F';
                case 'z-score ΔF/F'
                    if isempty(app.zscore_dff_data)
                        uialert(app.UIFigure, 'z-score ΔF/F data not available. Please run analysis with z-score enabled.', 'Export Error');
                        return;
                    end
                    data_to_export = app.zscore_dff_data;
                    file_suffix_type = 'ZScore_DeltaF_F';
                otherwise
                    uialert(app.UIFigure, 'Invalid signal type selected for export.', 'Export Error');
                    return;
            end

            if isempty(data_to_export)
                uialert(app.UIFigure, ['No data found for the selected signal type: ' selected_signal_type], 'Export Error');
                return;
            end

            [~, baseNameWithoutExt, ~] = fileparts(app.loaded_file_name);
            if isempty(baseNameWithoutExt)
                baseNameWithoutExt = 'ExportedData'; % Fallback if loaded_file_name is weird
            end
            exportDir = fullfile(app.selectedFolder, [baseNameWithoutExt '_ExportedPlots']);
            if ~exist(exportDir, 'dir')
                try
                    mkdir(exportDir);
                catch ME_mkdir
                    uialert(app.UIFigure, ['Error creating export directory: ' ME_mkdir.message], 'Directory Error');
                    return;
                end
            end

            num_neurons = size(data_to_export, 1);
            progDlg = uiprogressdlg(app.UIFigure, 'Title', 'Exporting All Neuron Plots', ...
                                    'Message', sprintf('Starting export for %d neurons...', num_neurons), ...
                                    'Cancelable', 'on', 'Indeterminate', 'off');
            cleanupProgDlg = onCleanup(@() delete(progDlg)); % Ensure dialog closes

            % Get UIAxes dimensions for exported figures
            % Ensure UIAxes has valid position data
            if isempty(app.UIAxes.Position) || any(app.UIAxes.Position(3:4) <=0)
                uialert(app.UIFigure, 'UIAxes dimensions are invalid. Cannot set export figure size.', 'Export Error');
                return;
            end
            export_fig_width = app.UIAxes.Position(3);
            export_fig_height = app.UIAxes.Position(4);
            
            if export_fig_width < 50 || export_fig_height < 50 % Minimum sensible size
                warning('UIAxes dimensions are very small. Exported figures might be tiny. Using default 600x400.');
                export_fig_width = 600;
                export_fig_height = 400;
            end

            for n = 1:num_neurons
                if progDlg.CancelRequested
                    uialert(app.UIFigure, 'Export cancelled by user.', 'Export Cancelled');
                    return;
                end
                progDlg.Message = sprintf('Exporting Neuron %d/%d (%s)...', n, num_neurons, selected_signal_type);
                progDlg.Value = n / num_neurons;
                drawnow; % Update dialog

                trace_data = data_to_export(n, :);
                
                fig_export = []; % Initialize for catch block
                try
                    fig_export = figure('Visible', 'off', ...
                                      'Units', 'pixels', ...
                                      'Position', [100, 100, export_fig_width, export_fig_height]); % Use UIAxes dimensions
                    ax_export = axes(fig_export);

                    % MODIFIED: Use app.current_plot_color for all individually exported neuron plots
                    plot(ax_export, app.time_vector, trace_data, 'Color', app.current_plot_color, 'LineWidth', 1); 
                    title(ax_export, sprintf('%s - Neuron %d', selected_signal_type, n), 'Interpreter', 'none');
                    xlabel(ax_export, 'Time (s)');
                    ylabel(ax_export, strrep(selected_signal_type, 'ΔF/F', 'dF/F')); 
                    grid(ax_export, 'on');
                    box(ax_export, 'off'); % Remove top and right borders
                    xlim(ax_export, [app.time_vector(1), app.time_vector(end)]);

                    baseFigName = sprintf('%s_Neuron%d_%s', baseNameWithoutExt, n, file_suffix_type);
                    figFilePath = fullfile(exportDir, [baseFigName '.fig']);
                    pngFilePath = fullfile(exportDir, [baseFigName '.png']);

                    savefig(fig_export, figFilePath);
                    exportgraphics(ax_export, pngFilePath, 'Resolution', 150);

                    close(fig_export);
                catch ME_export_neuron
                    if isvalid(fig_export)
                        close(fig_export);
                    end
                    warning('Error exporting neuron %d: %s', n, ME_export_neuron.message);
                    choice = uiconfirm(app.UIFigure, ...
                        sprintf('Error exporting neuron %d: %s\n\nDo you want to continue with other neurons?', n, ME_export_neuron.message), ...
                        'Export Error', 'Options', {'Continue', 'Cancel All'}, 'DefaultOption', 'Continue');
                    if strcmp(choice, 'Cancel All')
                        uialert(app.UIFigure, 'Export cancelled due to error.', 'Export Cancelled');
                        return;
                    end
                end
            end
            
            progDlg.Value = 1; progDlg.Message = 'Export complete!';
            pause(0.5); % Allow dialog to show complete message
            
            uialert(app.UIFigure, sprintf('All neuron plots exported successfully to:\n%s', exportDir), ...
                    'Export Complete', 'Icon', 'success');
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            assignin('base', 'app', app);
            app.RunAnalysisButton.Enable = 'off';
            app.NeuronDropDown.Enable = 'off';
            app.PreviousNeuronButton.Enable = 'off';
            app.NextNeuronButton.Enable = 'off';
            app.SaveResultsButton.Enable = 'off';
            app.DisplayAllNeuronsButton.Enable = 'off';
            app.NeuronDropDown.Items = {'N/A'};
            app.NeuronDropDown.Value = 'N/A';
            app.SignalTypeDropDown.Items = {'Raw Signal'};
            app.SignalTypeDropDown.Enable = 'off';
            app.ExportAllNeuronsButton.Enable = 'off'; 
            title(app.UIAxes, 'Load Data to Begin');
            app.FramerateEditField.Value = app.framerate;
            app.CalculateZScoreCheckBox.Value = app.calculate_zscore;
            app.PercentileEditField.Value = app.percentile_value;
            app.BaselineTimeEditField.Value = app.baseline_time;
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
            app.LoadedFileLabel.Text = 'No file loaded';
            
            % Initialize visibility of baseline parameter fields
            BaselineMethodDropDownValueChanged(app, []); % Call to set initial visibility
        end

        % Button pushed function: LoadDataButton
        function LoadDataButtonPushed(app, event)
            f_dummy = figure('Position', [-100 -100 0 0],'CloseRequestFcn','','Visible','off'); 
            [fileName, filePath] = uigetfile({'*.mat';'*.xlsx;*.xls'}, 'Select Data File');
            delete(f_dummy);
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'No file selected.', 'File Load');
                return;
            end
            app.selectedFolder = filePath;
            app.loaded_file_name = fileName;
            app.LoadedFileLabel.Text = sprintf('%s', fileName);
            fullPath = fullfile(filePath, fileName);
            [~, ~, ext] = fileparts(fileName);
            
            % Use the current value from the FramerateEditField when loading data
            app.framerate = app.FramerateEditField.Value;
            if isnan(app.framerate) || app.framerate <= 0
                 uialert(app.UIFigure, 'Invalid framerate. Please set a positive value.', 'Framerate Error');
                 app.FramerateEditField.Value = 30; % Reset to a default
                 app.framerate = 30;
                 return; 
            end

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
                        f_dummy_list = figure('Position', [-100 -100 0 0],'CloseRequestFcn','','Visible','off');
                        [indx, tf] = listdlg('PromptString', {'Select fluorescence variable: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', varNames, ...
                            'Name', 'Select Variable', 'OKString', 'Select');
                        delete(f_dummy_list);
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
                        f_dummy_list = figure('Position', [-100 -100 0 0],'CloseRequestFcn','','Visible','off');
                        [indx, tf] = listdlg('PromptString', {'Select sheet: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', sheetNames, ...
                            'Name', 'Select Sheet', 'OKString', 'Select');
                        delete(f_dummy_list);
                        if tf
                            app.fluo_data = readmatrix(fullPath, 'Sheet', sheetNames{indx});
                        else
                            uialert(app.UIFigure, 'No sheet selected.', 'Load Error'); return;
                        end
                    end
                else
                    uialert(app.UIFigure, 'Unsupported file type.', 'Load Error'); return;
                end
                if (~ismatrix(app.fluo_data) || isempty(app.fluo_data) || ~isnumeric(app.fluo_data))
                    uialert(app.UIFigure, 'Selected data is not a valid numeric matrix or is empty.', 'Data Error');
                    app.fluo_data = []; return;
                end
                [num_neurons, num_frames] = size(app.fluo_data);
                app.time_vector = (0:num_frames-1) / app.framerate;
                app.dff_data = [];
                app.zscore_dff_data = [];
                app.results = []; % Clear previous results

                app.RunAnalysisButton.Enable = 'on';
                app.NeuronDropDown.Enable = 'on';
                app.PreviousNeuronButton.Enable = 'on';
                app.NextNeuronButton.Enable = 'on';
                app.DisplayAllNeuronsButton.Enable = 'on';
                app.ExportAllNeuronsButton.Enable = 'on'; 
                
                neuronItems = arrayfun(@(x) sprintf('Neuron %d', x), 1:num_neurons, 'UniformOutput', false);
                 if isempty(neuronItems) 
                    app.NeuronDropDown.Items = {'N/A'};
                    app.NeuronDropDown.Value = 'N/A';
                    app.current_neuron_id = 0;
                 else
                    app.NeuronDropDown.Items = neuronItems;
                    app.NeuronDropDown.Value = neuronItems{1}; % Select first neuron
                    app.current_neuron_id = 1;
                 end

                app.signal_type = 'Raw Signal';
                app.SignalTypeDropDown.Items = {'Raw Signal'}; % Reset available types
                app.SignalTypeDropDown.Value = 'Raw Signal';
                app.SignalTypeDropDown.Enable = 'on';
                app.SaveResultsButton.Enable = 'off'; % Only enable after analysis

                UpdatePlot(app);
                uialert(app.UIFigure, sprintf('Data loaded: %d neurons, %d frames at %.2f Hz.', num_neurons, num_frames, app.framerate), ...
                    'Load Success', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ['Error loading data: ' ME.message], 'Load Error');
                disp(ME.getReport); % For debugging
                app.fluo_data = [];
                app.dff_data = [];
                app.zscore_dff_data = [];
                app.RunAnalysisButton.Enable = 'off';
                app.SignalTypeDropDown.Enable = 'off';
                app.NeuronDropDown.Enable = 'off';
                app.PreviousNeuronButton.Enable = 'off';
                app.NextNeuronButton.Enable = 'off';
                app.DisplayAllNeuronsButton.Enable = 'off';
                app.ExportAllNeuronsButton.Enable = 'off'; 
                app.SaveResultsButton.Enable = 'off';
                app.LoadedFileLabel.Text = 'No file loaded';
                app.NeuronDropDown.Items = {'N/A'};
                app.NeuronDropDown.Value = 'N/A';
                app.current_neuron_id = 0;
                UpdatePlot(app); % Clear plot
            end
        end

        % Button pushed function: RunAnalysisButton
        function RunAnalysisButtonPushed(app, event)
            if isempty(app.fluo_data)
                uialert(app.UIFigure, 'No data loaded to analyze.', 'Analysis Error');
                return;
            end
            app.calculate_zscore = app.CalculateZScoreCheckBox.Value;
            app.baseline_method = app.BaselineMethodDropDown.Value;
            app.percentile_value = app.PercentileEditField.Value;
            app.baseline_time = app.BaselineTimeEditField.Value;
            app.polynomial_order = app.PolynomialOrderEditField.Value;
            app.moving_window_sec = app.MovingWindowEditField.Value;
            app.moving_percentile = app.MovingPercentileEditField.Value;

            try
                if app.framerate <= 0
                    error('Framerate must be positive.');
                end
                if ~strcmpi(app.baseline_time, 'all')
                    % Basic validation for baseline_time format (more in CalculateBaseline)
                    if ~matches(app.baseline_time, digitsPattern | (digitsPattern + ":" + digitsPattern))
                        if ~matches(app.baseline_time, textBoundary + (("0"|"."|[digitsPattern])+".*") + textBoundary) % allow decimals
                            % error('Invalid baseline time format. Use "all", "1:30", "10.5:20", or "30".');
                        end
                    end
                end
                if strcmp(app.baseline_method, 'Percentile')
                    perc_str = app.percentile_value;
                    if contains(perc_str, ':')
                        range = str2num(perc_str); %#ok<ST2NM>
                        if length(range) < 2 || any(isnan(range)) || any(range < 0) || any(range > 100)
                            error('Invalid percentile range. Use format "10:20" or single value like "20".');
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

            progDlg = uiprogressdlg(app.UIFigure, 'Title', 'Computing Signals', ...
                'Message', 'Initializing...', 'Cancelable', 'on', 'Indeterminate', 'off');
            [num_neurons, num_frames] = size(app.fluo_data);
            app.dff_data = zeros(num_neurons, num_frames);
            if app.calculate_zscore
                app.zscore_dff_data = zeros(num_neurons, num_frames);
            else
                app.zscore_dff_data = []; % Clear it if not calculated
            end
            app.results = struct('neuron_id', {}, 'dff_trace', {}, 'zscore_dff_trace', {});
            cleanupObj = onCleanup(@() delete(progDlg)); % Ensure dialog closes

            calculationErrorOccurred = false;
            for n = 1:num_neurons
                if progDlg.CancelRequested
                    uialert(app.UIFigure, 'Analysis cancelled by user.', 'Analysis Cancelled');
                    app.dff_data = []; % Clear partial results
                    app.zscore_dff_data = [];
                    app.results = [];
                    % Reset signal type dropdown if analysis was for dF/F
                    app.SignalTypeDropDown.Items = {'Raw Signal'};
                    app.SignalTypeDropDown.Value = 'Raw Signal';
                    app.signal_type = 'Raw Signal';
                    app.SaveResultsButton.Enable = 'off';
                    UpdatePlot(app);
                    return;
                end
                progDlg.Message = sprintf('Processing Neuron %d/%d', n, num_neurons);
                progDlg.Value = n / num_neurons;
                drawnow; % Update dialog

                fluo_trace = app.fluo_data(n, :);
                app.results(n).neuron_id = n;
                try
                    F0 = CalculateBaseline(app, fluo_trace);
                    dff_trace = (fluo_trace - F0) ./ F0;
                    app.dff_data(n, :) = dff_trace;
                    app.results(n).dff_trace = dff_trace;

                    if app.calculate_zscore
                        if std(dff_trace) == 0 % Avoid division by zero for constant traces
                            app.zscore_dff_data(n, :) = zeros(1, num_frames); 
                        else
                            app.zscore_dff_data(n, :) = (dff_trace - mean(dff_trace)) / std(dff_trace);
                        end
                        app.results(n).zscore_dff_trace = app.zscore_dff_data(n, :);
                    else
                        app.results(n).zscore_dff_trace = [];
                    end
                catch ME_neuron
                    warning('Error computing signals for neuron %d: %s', n, ME_neuron.message);
                    % Mark error and continue, or stop? For now, continue but warn.
                    % Fill with NaNs or zeros for this neuron to indicate failure
                    app.dff_data(n, :) = NaN; 
                    if app.calculate_zscore, app.zscore_dff_data(n, :) = NaN; end
                    app.results(n).dff_trace = NaN(1,num_frames);
                    if app.calculate_zscore, app.results(n).zscore_dff_trace = NaN(1,num_frames); end
                    calculationErrorOccurred = true;
                end
            end
            
            progDlg.Value = 1; progDlg.Message = 'Analysis complete!';
            pause(0.5); % Allow dialog to show complete message

            if calculationErrorOccurred
                uialert(app.UIFigure, 'Analysis completed, but errors occurred for one or more neurons. Check command window for warnings.', ...
                        'Analysis Warning', 'Icon', 'warning');
            else
                uialert(app.UIFigure, 'Analysis complete.', 'Success', 'Icon', 'success');
            end
            

            % Update UI elements related to results
            app.SaveResultsButton.Enable = 'on';
            
            new_signal_types = {'Raw Signal', 'ΔF/F'};
            if app.calculate_zscore && ~isempty(app.zscore_dff_data)
                new_signal_types = [new_signal_types, 'z-score ΔF/F'];
            end
            app.SignalTypeDropDown.Items = new_signal_types;
            
            % Set plot to ΔF/F by default after analysis
            if ismember('ΔF/F', new_signal_types)
                app.SignalTypeDropDown.Value = 'ΔF/F';
                app.signal_type = 'ΔF/F';
            else % Should not happen if dff_data is populated
                app.SignalTypeDropDown.Value = 'Raw Signal';
                app.signal_type = 'Raw Signal';
            end
            
            % Ensure current_neuron_id is valid before updating plot
            if app.current_neuron_id == 0 && num_neurons > 0
                app.current_neuron_id = 1;
                app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            elseif app.current_neuron_id > num_neurons && num_neurons > 0
                 app.current_neuron_id = num_neurons;
                 app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            elseif num_neurons == 0 % No neurons, should not happen here
                app.current_neuron_id = 0;
                app.NeuronDropDown.Value = 'N/A';
            end

            UpdatePlot(app);
        end

        % Value changed function: SignalTypeDropDown
        function SignalTypeDropDownValueChanged(app, event)
            app.signal_type = app.SignalTypeDropDown.Value;
            app.display_all = false; % Reset to single neuron view when type changes
            UpdatePlot(app);
        end

        % Value changed function: NeuronDropDown
        function NeuronDropDownValueChanged(app, event)
            if strcmp(app.NeuronDropDown.Value, 'N/A')
                app.current_neuron_id = 0; % Or some other indicator for no neuron
                UpdatePlot(app); % Update plot to show "no neuron selected" or clear
                return;
            end
            selectedNeuronStr = app.NeuronDropDown.Value;
            app.current_neuron_id = str2double(regexp(selectedNeuronStr, '\d+', 'match', 'once'));
            app.display_all = false; % Ensure single neuron display
            UpdatePlot(app);
        end

        % Button pushed function: PreviousNeuronButton
        function PreviousNeuronButtonPushed(app, event)
            if isempty(app.fluo_data) || app.current_neuron_id <= 1
                return;
            end
            app.current_neuron_id = app.current_neuron_id - 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.display_all = false;
            UpdatePlot(app);
        end

        % Button pushed function: NextNeuronButton
        function NextNeuronButtonPushed(app, event)
            if isempty(app.fluo_data) || app.current_neuron_id >= size(app.fluo_data, 1)
                return;
            end
            app.current_neuron_id = app.current_neuron_id + 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.display_all = false;
            UpdatePlot(app);
        end

        % Button pushed function: DisplayAllNeuronsButton
        function DisplayAllNeuronsButtonPushed(app, event)
            app.scalebar_signal = app.ScalebarSignalEditField.Value;
            app.plot_scale_bar_time = app.PlotScaleBarTimeCheckBox.Value;
            app.scalebar_time = app.ScalebarTimeEditField.Value;
            app.selected_roi_str = app.SelectedROIEditField.Value;
            app.roi_interval = app.ROIIntervalEditField.Value;
            app.color_map = app.ColorMapEditField.Value;
            

            
            UpdateAllNeuronsPlot(app); % This updates the separate figure window
        end

        % Button pushed function: SaveResultsButton
        function SaveResultsButtonPushed(app, event)
            if isempty(app.results) && isempty(app.dff_data) % Check if there are any results to save
                uialert(app.UIFigure, 'No analysis results to save.', 'Save Error');
                return;
            end
            
            defaultFileName = 'analysis_results.mat';
            if ~isempty(app.loaded_file_name)
                [~, name, ~] = fileparts(app.loaded_file_name);
                defaultFileName = [name '_analysis_results.mat'];
            end

            [fileName, filePath] = uiputfile({'*.mat', 'MAT-file (*.mat)'}, 'Save Results', fullfile(app.selectedFolder, defaultFileName));
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'Save cancelled.', 'Save Operation');
                return;
            end
            progressDlg = uiprogressdlg(app.UIFigure,'Title','Saving Data','Message', 'Preparing data for saving...','Indeterminate','on');
            drawnow

            [~, name, ~] = fileparts(fileName); % Use the name part from uiputfile
            matPath = fullfile(filePath, [name '.mat']);
            xlsxPath = fullfile(filePath, [name '.xlsx']); % Excel file with the same base name

            % Prepare data for saving (ensure all relevant app properties are captured)
            saveData.raw_fluorescence = app.fluo_data;
            saveData.deltaF_over_F = app.dff_data;
            if app.calculate_zscore && ~isempty(app.zscore_dff_data)
                saveData.zscore_deltaF_over_F = app.zscore_dff_data;
            end
            saveData.time_vector_seconds = app.time_vector;
            saveData.analysis_parameters = struct(...
                'loaded_file_name', app.loaded_file_name, ...
                'framerate_Hz', app.framerate, ...
                'calculate_zscore', app.calculate_zscore, ...
                'baseline_method', app.baseline_method, ...
                'percentile_value', app.percentile_value, ...
                'baseline_time_setting', app.baseline_time, ...
                'polynomial_order', app.polynomial_order, ...
                'moving_window_seconds', app.moving_window_sec, ...
                'moving_percentile', app.moving_percentile, ...
                'analysis_date', datestr(now) ...
            );
            saveData.detailed_results_per_neuron = app.results; 

            % Parameters for "All Neurons Plot" if any
            saveData.all_neurons_plot_settings = struct(...
                 'scalebar_signal', app.scalebar_signal, ...
                 'plot_scale_bar_time', app.plot_scale_bar_time, ...
                 'scalebar_time', app.scalebar_time, ...
                 'selected_roi_str', app.selected_roi_str, ...
                 'roi_interval', app.roi_interval, ...
                 'color_map', app.color_map ...
            );

            try
                progressDlg.Message = 'Saving .mat file...';
                drawnow;
                save(matPath, 'saveData', '-v7.3'); % Save the whole struct

                progressDlg.Message = 'Saving raw signal to Excel...';
                drawnow;
                if ~isempty(app.fluo_data)
                    writetable(array2table(app.fluo_data), xlsxPath, 'Sheet', 'RawFluorescence', 'WriteMode', 'replacefile');
                end
                
                progressDlg.Message = 'Saving dF/F to Excel...';
                drawnow;
                if ~isempty(app.dff_data)
                     writetable(array2table(app.dff_data), xlsxPath, 'Sheet', 'DeltaFoverF', 'WriteMode', 'inplace');
                end

                if app.calculate_zscore && ~isempty(app.zscore_dff_data)
                    progressDlg.Message = 'Saving z-score dF/F to Excel...';
                    drawnow;
                    writetable(array2table(app.zscore_dff_data), xlsxPath, 'Sheet', 'ZScoreDeltaFoverF', 'WriteMode', 'inplace');
                end
                
                progressDlg.Message = 'Saving parameters to Excel...';
                drawnow;
                % Create a table for parameters
                param_names = fieldnames(saveData.analysis_parameters);
                param_values = struct2cell(saveData.analysis_parameters);
                % Handle non-scalar cell contents for table creation
                for i = 1:length(param_values)
                    if ischar(param_values{i})
                        param_values{i} = {param_values{i}}; % Ensure char is in a cell
                    elseif isnumeric(param_values{i}) && isscalar(param_values{i})
                         param_values{i} = param_values{i}; % Keep as is
                    elseif islogical(param_values{i})
                         param_values{i} = {mat2str(param_values{i})}; % Convert logical to string
                    else % For other types or non-scalars, convert to string representation
                        param_values{i} = {mat2str(param_values{i})};
                    end
                end

                params_table = table(param_values(:), 'RowNames', param_names, 'VariableNames', {'Value'});
                writetable(params_table, xlsxPath, 'Sheet', 'AnalysisParameters', 'WriteRowNames', true, 'WriteMode', 'inplace');

                close(progressDlg);
                uialert(app.UIFigure, sprintf('Results saved to:\n%s\n%s', matPath, xlsxPath), ...
                    'Save Success', 'Icon', 'success');
            catch ME_save
                close(progressDlg);
                uialert(app.UIFigure, ['Error saving results: ' ME_save.message], 'Save Error');
                disp(ME_save.getReport);
            end
        end

        % Value changed function: BaselineMethodDropDown
        function BaselineMethodDropDownValueChanged(app, event)
            app.baseline_method = app.BaselineMethodDropDown.Value;
            isPercentile = strcmp(app.baseline_method, 'Percentile');
            isPolynomial = strcmp(app.baseline_method, 'Polynomial');
            isMovingPercentile = strcmp(app.baseline_method, 'Moving Percentile');

            app.PercentileEditField.Enable = isPercentile;
            app.PercentileEditFieldLabel.Enable = isPercentile;
            app.BaselineTimeEditField.Enable = isPercentile;
            app.BaselineTimeLabel.Enable = isPercentile;

            app.PolynomialOrderEditField.Enable = isPolynomial;
            app.PolynomialOrderLabel.Enable = isPolynomial;

            app.MovingWindowEditField.Enable = isMovingPercentile;
            app.MovingWindowLabel.Enable = isMovingPercentile;
            app.MovingPercentileEditField.Enable = isMovingPercentile;
            app.MovingPercentileLabel.Enable = isMovingPercentile;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 750];
            app.UIFigure.Name = 'Calcium ΔF/F Calculator v2.1';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Signal')
            xlabel(app.UIAxes, 'Time (s)')
            ylabel(app.UIAxes, 'Raw Signal')
            app.UIAxes.XGrid = 'on';
            app.UIAxes.YGrid = 'on';
            app.UIAxes.ZGrid = 'on';
            app.UIAxes.Position = [350 50 800 650];

            % Create FileOperationsPanel
            app.FileOperationsPanel = uipanel(app.UIFigure);
            app.FileOperationsPanel.Title = 'File Operations';
            app.FileOperationsPanel.Position = [20 620 300 100];

            % Create LoadedFileLabel
            app.LoadedFileLabel = uilabel(app.FileOperationsPanel);
            app.LoadedFileLabel.Position = [120 10 170 22];
            app.LoadedFileLabel.Text = 'No file loaded';

            % Create LoadDataButton
            app.LoadDataButton = uibutton(app.FileOperationsPanel, 'push');
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.Position = [10 10 100 22];
            app.LoadDataButton.Text = 'Load Data';

            % Create FramerateEditField
            app.FramerateEditField = uieditfield(app.FileOperationsPanel, 'numeric');
            app.FramerateEditField.ValueDisplayFormat = '%.2f';
            app.FramerateEditField.ValueChangedFcn = createCallbackFcn(app, @FramerateEditFieldValueChanged, true);
            app.FramerateEditField.Position = [110 40 100 22];
            app.FramerateEditField.Value = 3.6;

            % Create FramerateHzLabel
            app.FramerateHzLabel = uilabel(app.FileOperationsPanel);
            app.FramerateHzLabel.HorizontalAlignment = 'right';
            app.FramerateHzLabel.Position = [10 40 90 22];
            app.FramerateHzLabel.Text = 'Framerate (Hz):';

            % Create DeltaFOverFCalculatePanel
            app.DeltaFOverFCalculatePanel = uipanel(app.UIFigure);
            app.DeltaFOverFCalculatePanel.Title = 'ΔF/F Calculate';
            app.DeltaFOverFCalculatePanel.Position = [20 365 300 250];

            % Create SaveResultsButton
            app.SaveResultsButton = uibutton(app.DeltaFOverFCalculatePanel, 'push');
            app.SaveResultsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveResultsButtonPushed, true);
            app.SaveResultsButton.Position = [115 10 100 22];
            app.SaveResultsButton.Text = 'Save Results';

            % Create RunAnalysisButton
            app.RunAnalysisButton = uibutton(app.DeltaFOverFCalculatePanel, 'push');
            app.RunAnalysisButton.ButtonPushedFcn = createCallbackFcn(app, @RunAnalysisButtonPushed, true);
            app.RunAnalysisButton.Position = [10 10 100 22];
            app.RunAnalysisButton.Text = 'Run Analysis';

            % Create MovingPercentileEditField
            app.MovingPercentileEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'numeric');
            app.MovingPercentileEditField.ValueDisplayFormat = '%.1f';
            app.MovingPercentileEditField.Position = [120 38 150 22];
            app.MovingPercentileEditField.Value = 20;

            % Create MovingPercentileLabel
            app.MovingPercentileLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.MovingPercentileLabel.HorizontalAlignment = 'right';
            app.MovingPercentileLabel.Position = [10 38 100 22];
            app.MovingPercentileLabel.Text = 'Moving Percentile:';

            % Create MovingWindowEditField
            app.MovingWindowEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'numeric');
            app.MovingWindowEditField.ValueDisplayFormat = '%.2f';
            app.MovingWindowEditField.Position = [120 66 150 22];
            app.MovingWindowEditField.Value = 20;

            % Create MovingWindowLabel
            app.MovingWindowLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.MovingWindowLabel.HorizontalAlignment = 'right';
            app.MovingWindowLabel.Position = [10 66 100 22];
            app.MovingWindowLabel.Text = 'Window Size (s):';

            % Create PolynomialOrderEditField
            app.PolynomialOrderEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'numeric');
            app.PolynomialOrderEditField.ValueDisplayFormat = '%d';
            app.PolynomialOrderEditField.Position = [120 94 150 22];
            app.PolynomialOrderEditField.Value = 3;

            % Create PolynomialOrderLabel
            app.PolynomialOrderLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.PolynomialOrderLabel.HorizontalAlignment = 'right';
            app.PolynomialOrderLabel.Position = [10 94 100 22];
            app.PolynomialOrderLabel.Text = 'Polynomial Order:';

            % Create BaselineTimeEditField
            app.BaselineTimeEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'text');
            app.BaselineTimeEditField.Placeholder = 'all or 0:30 or 30';
            app.BaselineTimeEditField.Position = [120 122 150 22];
            app.BaselineTimeEditField.Value = 'all';

            % Create BaselineTimeLabel
            app.BaselineTimeLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.BaselineTimeLabel.HorizontalAlignment = 'right';
            app.BaselineTimeLabel.Position = [10 122 100 22];
            app.BaselineTimeLabel.Text = 'Baseline Time(s):';

            % Create PercentileEditField
            app.PercentileEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'text');
            app.PercentileEditField.Placeholder = '10:20 or 20';
            app.PercentileEditField.Position = [120 150 150 22];
            app.PercentileEditField.Value = '10:20';

            % Create PercentileEditFieldLabel
            app.PercentileEditFieldLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.PercentileEditFieldLabel.HorizontalAlignment = 'right';
            app.PercentileEditFieldLabel.Position = [10 150 100 22];
            app.PercentileEditFieldLabel.Text = 'Percentile(s):';

            % Create BaselineMethodDropDown
            app.BaselineMethodDropDown = uidropdown(app.DeltaFOverFCalculatePanel);
            app.BaselineMethodDropDown.Items = {'Percentile', 'Polynomial', 'Moving Percentile'};
            app.BaselineMethodDropDown.ValueChangedFcn = createCallbackFcn(app, @BaselineMethodDropDownValueChanged, true);
            app.BaselineMethodDropDown.Position = [120 178 150 22];
            app.BaselineMethodDropDown.Value = 'Percentile';

            % Create BaselineMethodDropDownLabel
            app.BaselineMethodDropDownLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.BaselineMethodDropDownLabel.HorizontalAlignment = 'right';
            app.BaselineMethodDropDownLabel.Position = [10 178 100 22];
            app.BaselineMethodDropDownLabel.Text = 'Baseline Method:';

            % Create CalculateZScoreCheckBox
            app.CalculateZScoreCheckBox = uicheckbox(app.DeltaFOverFCalculatePanel);
            app.CalculateZScoreCheckBox.Text = 'Calculate z-score ΔF/F';
            app.CalculateZScoreCheckBox.Position = [10 205 180 22];

            % Create NeuronDisplayPanel
            app.NeuronDisplayPanel = uipanel(app.UIFigure);
            app.NeuronDisplayPanel.Title = 'Neuron Display & Export';
            app.NeuronDisplayPanel.Position = [20 220 300 135];

            % Create ExportAllNeuronsButton
            app.ExportAllNeuronsButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.ExportAllNeuronsButton.ButtonPushedFcn = createCallbackFcn(app, @ExportAllNeuronsButtonPushed, true);
            app.ExportAllNeuronsButton.Position = [10 30 180 22];
            app.ExportAllNeuronsButton.Text = 'Export All Neurons';

            % Create NextNeuronButton
            app.NextNeuronButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.NextNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @NextNeuronButtonPushed, true);
            app.NextNeuronButton.Position = [105 60 85 22];
            app.NextNeuronButton.Text = 'Next';

            % Create PreviousNeuronButton
            app.PreviousNeuronButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.PreviousNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousNeuronButtonPushed, true);
            app.PreviousNeuronButton.Position = [10 60 85 22];
            app.PreviousNeuronButton.Text = 'Previous';

            % Create NeuronDropDown
            app.NeuronDropDown = uidropdown(app.NeuronDisplayPanel);
            app.NeuronDropDown.ValueChangedFcn = createCallbackFcn(app, @NeuronDropDownValueChanged, true);
            app.NeuronDropDown.Position = [105 90 170 22];

            % Create SelectNeuronLabel
            app.SelectNeuronLabel = uilabel(app.NeuronDisplayPanel);
            app.SelectNeuronLabel.HorizontalAlignment = 'right';
            app.SelectNeuronLabel.Position = [10 90 85 22];
            app.SelectNeuronLabel.Text = 'Select Neuron:';

            % Create AllNeuronsDisplayPanel
            app.AllNeuronsDisplayPanel = uipanel(app.UIFigure);
            app.AllNeuronsDisplayPanel.Title = 'All Neurons Plot Settings (ΔF/F)';
            app.AllNeuronsDisplayPanel.Position = [20 10 300 200];

            % Create ColorMapEditField
            app.ColorMapEditField = uieditfield(app.AllNeuronsDisplayPanel, 'text');
            app.ColorMapEditField.Placeholder = 'turbo, jet, or #RRGGBB';
            app.ColorMapEditField.Position = [100 5 170 22];
            app.ColorMapEditField.Value = 'turbo';

            % Create ColorMapLabel
            app.ColorMapLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ColorMapLabel.HorizontalAlignment = 'right';
            app.ColorMapLabel.Position = [10 5 80 22];
            app.ColorMapLabel.Text = 'Color Map:';

            % Create ROIIntervalEditField
            app.ROIIntervalEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ROIIntervalEditField.Position = [100 35 170 22];
            app.ROIIntervalEditField.Value = 1;

            % Create ROIIntervalLabel
            app.ROIIntervalLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ROIIntervalLabel.HorizontalAlignment = 'right';
            app.ROIIntervalLabel.Position = [10 35 80 22];
            app.ROIIntervalLabel.Text = 'ROI Interval:';

            % Create SelectedROIEditField
            app.SelectedROIEditField = uieditfield(app.AllNeuronsDisplayPanel, 'text');
            app.SelectedROIEditField.Placeholder = 'e.g., 1:5,7,10:12';
            app.SelectedROIEditField.Position = [100 65 170 22];

            % Create SelectedROILabel
            app.SelectedROILabel = uilabel(app.AllNeuronsDisplayPanel);
            app.SelectedROILabel.HorizontalAlignment = 'right';
            app.SelectedROILabel.Position = [10 65 80 22];
            app.SelectedROILabel.Text = 'Selected ROI:';

            % Create ScalebarTimeEditField
            app.ScalebarTimeEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ScalebarTimeEditField.Position = [220 95 50 22];
            app.ScalebarTimeEditField.Value = 10;

            % Create ScalebarTimeLabel
            app.ScalebarTimeLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ScalebarTimeLabel.HorizontalAlignment = 'right';
            app.ScalebarTimeLabel.Position = [130 95 80 22];
            app.ScalebarTimeLabel.Text = 'Length (s):';

            % Create PlotScaleBarTimeCheckBox
            app.PlotScaleBarTimeCheckBox = uicheckbox(app.AllNeuronsDisplayPanel);
            app.PlotScaleBarTimeCheckBox.Text = 'Plot Time Scalebar';
            app.PlotScaleBarTimeCheckBox.Position = [10 95 140 22];
            app.PlotScaleBarTimeCheckBox.Value = true;

            % Create ScalebarSignalEditField
            app.ScalebarSignalEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ScalebarSignalEditField.Position = [170 125 100 22];
            app.ScalebarSignalEditField.Value = 1;

            % Create ScalebarSignalLabel
            app.ScalebarSignalLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ScalebarSignalLabel.Position = [10 125 130 22];
            app.ScalebarSignalLabel.Text = 'Scalebar Signal Value:';

            % Create DisplayAllNeuronsButton
            app.DisplayAllNeuronsButton = uibutton(app.AllNeuronsDisplayPanel, 'push');
            app.DisplayAllNeuronsButton.ButtonPushedFcn = createCallbackFcn(app, @DisplayAllNeuronsButtonPushed, true);
            app.DisplayAllNeuronsButton.Position = [10 155 200 22];
            app.DisplayAllNeuronsButton.Text = 'Open/Update All Neurons Plot';

            % Create SignalTypeDropDown
            app.SignalTypeDropDown = uidropdown(app.UIFigure);
            app.SignalTypeDropDown.Items = {'Raw Signal'};
            app.SignalTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @SignalTypeDropDownValueChanged, true);
            app.SignalTypeDropDown.Enable = 'off';
            app.SignalTypeDropDown.Position = [360 710 120 22];
            app.SignalTypeDropDown.Value = 'Raw Signal';

            % Create ExportPlotButton
            app.ExportPlotButton = uibutton(app.UIFigure, 'push');
            app.ExportPlotButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPlotButtonPushed, true);
            app.ExportPlotButton.Position = [490 710 100 22];
            app.ExportPlotButton.Text = 'Export This Plot';

            % Create SetWidthButton
            app.SetWidthButton = uibutton(app.UIFigure, 'push');
            app.SetWidthButton.ButtonPushedFcn = createCallbackFcn(app, @SetWidthButtonPushed, true);
            app.SetWidthButton.Position = [600 710 100 22];
            app.SetWidthButton.Text = 'Set Axes Width';

            % Create SetHeightButton
            app.SetHeightButton = uibutton(app.UIFigure, 'push');
            app.SetHeightButton.ButtonPushedFcn = createCallbackFcn(app, @SetHeightButtonPushed, true);
            app.SetHeightButton.Position = [710 710 100 22];
            app.SetHeightButton.Text = 'Set Axes Height';

            % Create SetPlotColorButton
            app.SetPlotColorButton = uibutton(app.UIFigure, 'push');
            app.SetPlotColorButton.ButtonPushedFcn = createCallbackFcn(app, @SetPlotColorButtonPushed, true);
            app.SetPlotColorButton.Position = [820 710 100 22];
            app.SetPlotColorButton.Text = 'Set Plot Color';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = CalciumDeltaFCaculator_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end