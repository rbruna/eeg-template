function source = myom_sourceanalysis ( cfg, data )
% Based on FiedTrip functions:
% * ft_sourceanalysis by Robert Oostenveld


% Checks that the leadfield is computed and all the data is present.
if ~isfield ( cfg, 'grid' ) || ~isfield ( cfg.grid, 'leadfield' )
    error ( 'This function requires a computed leadfield as input.' );
end

if ~isfield ( cfg.grid, 'pos' )
    warning ( 'Not dipoles position defined.' );
    cfg.grid.pos    = nan ( numel ( cfg.grid.leadfield ), 3 );
end
if ~isfield ( cfg.grid, 'inside' )
    warning ( 'Not ''inside'' dipoles defined. Considering all the dipoles to be inside.' );
    cfg.grid.inside = true ( size ( cfg.grid.pos, 1 ), 1 );
end

if ~isfield ( cfg.grid, 'label' )
    error ( 'The leadfield channel labels are not defined.' );
end

if numel ( cfg.grid.label ) ~= size ( cfg.grid.leadfield { find ( cfg.grid.inside, 1 ) }, 1 )
    error ( 'The number of channels in the leadfield is different from the number of channel labels.' )
end

if numel ( cfg.grid.leadfield ) ~= size ( cfg.grid.pos, 1 )
    error ( 'The number of dipoles in the leadfield is different from the number of source positions.' );
end


% Only works with LCMV and DICS.
if ~ft_datatype ( data, 'timelock' ) && ~ft_datatype ( data, 'freq' )
    error ( 'This function only accepts timelock or time-frequency data as input.' );
end
if isfield ( cfg, 'method' ) && ~ismember ( cfg.method, { 'lcmv' 'dics' } )
    error ( 'This function only works with LCMV and DICS beamformer.' );
end

% Checks that the method is the correct one.
if ft_datatype ( data, 'timelock' )
    if ~isfield ( cfg, 'method' )
        warning ( 'Not method defined. Using LCMV beamformer.' );
    elseif ~strcmp ( cfg.method, 'lcmv' )
        warning ( 'Wrong method selected. Changing it to LCMV beamformer' );
    end
    cfg.method = 'lcmv';
end
if ft_datatype ( data, 'freq' )
    if ~isfield ( cfg, 'method' )
        warning ( 'Not method defined. Using DICS beamformer.' );
    elseif ~strcmp ( cfg.method, 'dics' )
        warning ( 'Wrong method selected. Changing it to DICS beamformer' );
    end
    cfg.method = 'dics';
end

% Checks that the data is complete for LCMV.
if strcmp ( cfg.method, 'lcmv' )
    
    % Checks the covariance matrix.
    if ~isfield ( data, 'cov' )
        error ( 'Not covariance matrix present in the timelock data.' );
    end
    
    if size ( data.cov, 1 ) ~= size ( data.cov, 2 ) && size ( data.cov, 2 ) ~= size ( data.cov, 3 )
        error ( 'Covariance matrix is not square.' )
    end
    
    if ~isfield ( data, 'label' )
        error ( 'The data channel labels are not defined.' );
    end
    
    if numel ( data.label ) ~= size ( data.cov, 2 )
        error ( 'The dimensions of the covariance matrix do not match the number of channels.' );
    end
end

% Checks that the data is complete for DICS.
if strcmp ( cfg.method, 'dics' )
    
    % Gets the indexes of the channels in the cross-spectral matrix.
    
    % Checks the cross spectral density matrix.
    if any ( ~ismember ( data.labelcmb, data.label ) )
        error ( 'Some of the channels in the cross-spectral density matrix are not part of the data.' );
    end
    
    if ~all ( ismember ( data.labelcmb (:), data.label ) )
        warning ( 'Not all the channels are present in the cross-spectral density matrix.' );
    end
    
    channel   = intersect ( data.label, data.labelcmb (:) );
    nchannel  = numel ( channel );
    
    % Constructs the cross spectral density matrix.
    [ ~, idx ] = ismember ( data.labelcmb, channel );
    idx       = sub2ind ( [ nchannel nchannel ], idx ( :, 1 ), idx ( :, 2 ) );

    data.csdm = complex ( nan ( nchannel ) );
    data.csdm ( idx ) = data.crsspctrm;
    data.csdm = data.csdm';
    data.csdm ( idx ) = data.crsspctrm;
    data.csdm ( eye ( nchannel ) == 1 ) = data.powspctrm;
    
    if any ( isnan ( data.csdm ) )
        error ( 'Not all the channel combinations are present.' );
    end
end


% Gets only the channels both in the leadfield and the data.
channel = intersect ( data.label, cfg.grid.label, 'stable' );

if numel ( channel ) ~= numel ( data.label )
    warning ( 'Not all the data channels are present in the leadfield.' );
end
if numel ( channel ) ~= numel ( cfg.grid.label )
    warning ( 'Not all the leadfield channels are present in the data.' );
end

% Sorts the data and leadfield channels.
% It does not sort the channels yet!
if ~isequal ( data.label, channel )
    tmpcfg = [];
    tmpcfg.channel = channel;
    data           = ft_selectdata ( tmpcfg, data );
end
if ~isequal ( cfg.grid.label, channel )
    tmpcfg = [];
    tmpcfg.channel = channel;
    cfg.grid       = ft_selectdata ( tmpcfg, cfg.grid );
end


% Calculates the sources for each trial.
if strcmp ( cfg.method, 'lcmv' )
    extra  = ft_cfg2keyval ( cfg.lcmv );
    source = beamformer_lcmv ( cfg.grid, [], [], [], data.cov, extra {:} );
end
if strcmp ( cfg.method, 'dics' )
    extra  = ft_cfg2keyval ( cfg.dics );
    source = beamformer_dics ( cfg.grid, [], [], [], data.csdm, extra {:} );
end
