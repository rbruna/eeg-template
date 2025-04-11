function headmodel = myom_sourcematrix ( headmodel, grid )

% Based on FiedTrip functions:
% * ft_leadfield_openmeeg by Daniel D.E. Wong, Sarang S. Dalal
%
% Based on the OpenMEEG functions:
% * openmeeg_dsm by Alexandre Gramfort
% * openmeeg_megm by Emmanuel Olivi

global my_silent
my_silent  = ~isempty ( my_silent ) && my_silent;


% Adds OpenMEEG to the path.
ft_hastoolbox ( 'openmeeg', 1, 1 );

% Checks the OpenMEEG installation.
myom_checkom

% Checks the geometrical definition of the head model.
headmodel = myom_check_headmodel ( headmodel );

% Sanitizes the grid.
grid      = my_fixgrid ( grid );


% % Calculates the sources to head matrix.
% headmodel.dsm    = myom_dsm ( headmodel, grid );


% Sets the temporal base name.
basename  = tempname;

% Writes the dipole file.
myom_write_dipoles ( basename, grid )

% Writes the geometry files.
myom_write_geometry ( basename, headmodel )

% Determines the domain where the sources are located.
srctissue = headmodel.tissue { headmodel.source };


% Calculates the dipoles matrix.
if ~my_silent
    status = system ( sprintf ( 'om_assemble -dsm "%s.geom" "%s.cond" "%s.dip" "%s_dsm.mat" "%s"\n', basename, basename, basename, basename, srctissue ) );
else
    [ status, output ] = system ( sprintf ( 'om_assemble -dsm "%s.geom" "%s.cond" "%s.dip" "%s_dsm.mat" "%s"\n', basename, basename, basename, basename, srctissue ) );
end

% Checks for the completion of the execution.
if status ~= 0
    if my_silent, fprintf ( 1, '%s', output ); end
    fprintf ( 2, 'OpenMEEG program ''om_assemble'' exited with error code %i.\n', status );

    % Removes all the temporal files and exits.
    delete ( sprintf ( '%s*', basename ) );
    return
end

% Recovers the calculated dipoles model matrix.
headmodel.dsm = importdata ( sprintf ( '%s_dsm.mat', basename ) );

% Removes all the temporal files.
delete ( sprintf ( '%s*', basename ) );


% Stores the grid with the head model.
headmodel.grid = grid;

% Removes the previous sources to coils matrix, if any.
if isfield ( headmodel, 's2mm' ), headmodel = rmfield ( headmodel, 's2mm' ); end
