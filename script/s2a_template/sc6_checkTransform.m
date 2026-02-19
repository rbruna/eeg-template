clc
clear
close all

% Sets the path.
config.path.sens     = '../../template/sens/';
config.path.figs     = '../../figs-template/transform_/';
config.path.patt     = '*.mat';

% Selects which versions of the figure to save.
config.savefig       = false;
config.savegif       = true;


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'iso2mesh', 1, 1 );
ft_hastoolbox ( 'openmeeg', 1, 1 );


% Generates the output folder, if needed.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end

% Gets the files list.
files = dir ( sprintf ( '%s%s', config.path.sens, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Clears the command window.
    clc
    
    % Loads the MRI data and extracts the masks.
    sensdata      = load ( sprintf ( '%s%s', config.path.sens, files ( findex ).name ) );
    

    % Loads the MRI-based headmodel and grid.
    headdata      = load ( sensdata.mriinfo.mrifile, 'mesh', 'grid', 'headmodel' );
    
    % The sources are oriented with the axis of the MRI coordinate system.
    headdata.grid.ori  = eye (3);
    
    % Transforms the headmodel and the grid to MEG coordinates.
    headdata.mesh      = ft_convert_units ( headdata.mesh,      sensdata.mriinfo.unit );
    headdata.headmodel = ft_convert_units ( headdata.headmodel, sensdata.mriinfo.unit );
    headdata.grid      = ft_convert_units ( headdata.grid,      sensdata.mriinfo.unit );
    
    headdata.mesh      = ft_transform_geometry ( sensdata.mriinfo.transform, headdata.mesh );
    headdata.headmodel = ft_transform_geometry ( sensdata.mriinfo.transform, headdata.headmodel );
    headdata.grid      = ft_transform_geometry ( sensdata.mriinfo.transform, headdata.grid );
    
    % Transforms the head model and source model to SI units (meters).
    headdata.mesh      = ft_convert_units ( headdata.mesh,      'm' );
    headdata.headmodel = ft_convert_units ( headdata.headmodel, 'm' );
    headdata.grid      = ft_convert_units ( headdata.grid,      'm' );
    

    % If BEM checks the surfaces.
    if numel ( headdata.mesh.bnd ) == 3
        
        % Generates a temporal name prefix.
        tmpprefix = tempname;
        
        % Checks the triangle files and the geometry file.
        % Will find intersections and self-intersections.
        om_save_tri ( sprintf ( '%s_brain.tri', tmpprefix ), headdata.mesh.bnd (1).pos, headdata.mesh.bnd (1).tri );
        om_save_tri ( sprintf ( '%s_skull.tri', tmpprefix ), headdata.mesh.bnd (2).pos, headdata.mesh.bnd (2).tri );
        om_save_tri ( sprintf ( '%s_scalp.tri', tmpprefix ), headdata.mesh.bnd (3).pos, headdata.mesh.bnd (3).tri );
        om_write_geom ( sprintf ( '%s_geom.geom', tmpprefix ), { sprintf( '%s_brain.tri', tmpprefix ), sprintf( '%s_skull.tri', tmpprefix ), sprintf( '%s_scalp.tri', tmpprefix ) } );
        
%         system ( sprintf ( 'om_mesh_info -i "%s_brain.tri"', tmpprefix ) );
%         system ( sprintf ( 'om_mesh_info -i "%s_skull.tri"', tmpprefix ) );
%         system ( sprintf ( 'om_mesh_info -i "%s_scalp.tri"', tmpprefix ) );
        system ( sprintf ( 'om_check_geom -g "%s_geom.geom"', tmpprefix ) );
        
        % Deletes the files.
        delete ( sprintf ( '%s_*', tmpprefix ) );
        
        % Checks that the meshes are closed.
        % A closed mesh has an Euler characteristic of 2.
        fprintf ( 1, 'Subject %s.\n', sensdata.subject );
        fprintf ( 1, 'The Euler characteristic of the first mesh is %i.\n',  mesheuler ( headdata.mesh.bnd (1).tri ) );
        fprintf ( 1, 'The Euler characteristic of the second mesh is %i.\n', mesheuler ( headdata.mesh.bnd (2).tri ) );
        fprintf ( 1, 'The Euler characteristic of the third mesh is %i.\n',  mesheuler ( headdata.mesh.bnd (3).tri ) );
    end
    
    
    % Gets the mesh(es), the head shape and the source model.
    grid          = headdata.grid;
    mesh          = headdata.mesh;
    
    % Gets the original posiiton of the dipoles.
    dipoleu  = grid.inside & grid.posori ( :, 3 ) >= 0;
    dipoled  = grid.inside & grid.posori ( :, 3 ) <  0;
    dipoler  = grid.inside & grid.posori ( :, 1 ) >= 0 & dipoleu;
    dipolel  = grid.inside & grid.posori ( :, 1 ) <  0 & dipoleu;
    
    % Plots the grid.
    ft_plot_mesh  ( grid.pos ( dipoled, : ), 'VertexColor', [ 0.0000 0.4470 0.7410 ], 'VertexSize', 5 );
    ft_plot_mesh  ( grid.pos ( dipolel, : ), 'VertexColor', [ 0.4660 0.6740 0.1880 ], 'VertexSize', 5 );
    ft_plot_mesh  ( grid.pos ( dipoler, : ), 'VertexColor', [ 0.3010 0.7450 0.9330 ], 'VertexSize', 5 );
    % ft_plot_mesh  ( grid.pos ( grid.inside, : ), 'VertexColor', [ 0 0 0 ], 'VertexSize', 1 );
    
    % Plots the meshes.
    for mindex = 1: numel ( mesh.tissue )
        switch mesh.tissue { mindex }
            case 'brain', meshcolor = 'brain';
            case 'skull', meshcolor = [ 1 1 1 ] - eps;
            case 'scalp', meshcolor = 'skin';
            otherwise,    meshcolor = [ 1 1 1 ] - eps;
        end
        
        ft_plot_mesh  ( mesh.bnd ( mindex ), 'facecolor', meshcolor, 'edgecolor', 'none', 'facealpha', .2 );
    end
    hold on
    
    
    % Plots the sensors.
    if isfield ( sensdata, 'grad' ) && ~isempty ( sensdata.grad )
        plot3 ( sensdata.grad.chanpos ( :, 1 ), sensdata.grad.chanpos ( :, 2 ), sensdata.grad.chanpos ( :, 3 ), '+r' )
    end
    if isfield ( sensdata, 'elec' ) && ~isempty ( sensdata.elec )
        plot3 ( sensdata.elec.chanpos ( :, 1 ), sensdata.elec.chanpos ( :, 2 ), sensdata.elec.chanpos ( :, 3 ), '*r' )
    end
    if isfield ( sensdata, 'sens' ) && ~isempty ( sensdata.sens )
        plot3 ( sensdata.sens.chanpos ( :, 1 ), sensdata.sens.chanpos ( :, 2 ), sensdata.sens.chanpos ( :, 3 ), 'or' )
    end
    
    % Lights the scene.
    set ( gcf, 'Name', sensdata.subject );
    view ( [   90,   0 ] ), camlight
    view ( [ -150,   0 ] ), camlight
    material dull
    lighting gouraud
    drawnow
    
    fprintf ( 1, 'Blue:  Bottom.\n' );
    fprintf ( 1, 'Green: Top left.\n' );
    fprintf ( 1, 'Cyan:  Top right.\n' );
    
    % Saves the figure.
    print ( '-dpng', sprintf ( '%s%s.png', config.path.figs, sensdata.subject ) )
    
    if config.savefig
        savefig ( sprintf ( '%s%s.fig', config.path.figs, sensdata.subject ) )
    end
    if config.savegif
        my_savegif ( sprintf ( '%s%s.gif', config.path.figs, sensdata.subject ) )
    end
    
    close all
    clc
end
