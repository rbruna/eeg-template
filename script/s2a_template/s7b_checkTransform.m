clc
clear
close all

% Sets the path.
config.path.lead     = '../../template/leadfield/';
config.path.figs     = '../../figs-template/transform/';
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
files = dir ( sprintf ( '%s%s', config.path.lead, config.path.patt ) );

% Goes through all the files.
for file = 1: numel ( files )
    
    % Clears the command window.
    clc
    
    % Loads the MRI data and extracts the masks.
    leaddata      = load ( sprintf ( '%s%s', config.path.lead, files ( file ).name ) );
    
    % If BEM checks the surfaces.
    if numel ( leaddata.mesh.bnd ) == 3
        
        % Generates a temporal name prefix.
        tmpprefix = tempname;
        
        % Checks the triangle files and the geometry file.
        % Will find intersections and self-intersections.
        om_save_tri ( sprintf ( '%s_brain.tri', tmpprefix ), leaddata.mesh.bnd (1).pos, leaddata.mesh.bnd (1).tri );
        om_save_tri ( sprintf ( '%s_skull.tri', tmpprefix ), leaddata.mesh.bnd (2).pos, leaddata.mesh.bnd (2).tri );
        om_save_tri ( sprintf ( '%s_scalp.tri', tmpprefix ), leaddata.mesh.bnd (3).pos, leaddata.mesh.bnd (3).tri );
        om_write_geom ( sprintf ( '%s_geom.geom', tmpprefix ), { sprintf( '%s_brain.tri', tmpprefix ), sprintf( '%s_skull.tri', tmpprefix ), sprintf( '%s_scalp.tri', tmpprefix ) } );
        
%         system ( sprintf ( 'om_mesh_info -i "%s_brain.tri"', tmpprefix ) );
%         system ( sprintf ( 'om_mesh_info -i "%s_skull.tri"', tmpprefix ) );
%         system ( sprintf ( 'om_mesh_info -i "%s_scalp.tri"', tmpprefix ) );
        system ( sprintf ( 'om_check_geom -g "%s_geom.geom"', tmpprefix ) );
        
        % Deletes the files.
        delete ( sprintf ( '%s_*', tmpprefix ) );
        
        % Checks that the meshes are closed.
        % A closed mesh has an Euler characteristic of 2.
        fprintf ( 1, 'Subject %s.\n', leaddata.subject );
        fprintf ( 1, 'The Euler characteristic of the first mesh is %i.\n',  mesheuler ( leaddata.mesh.bnd (1).tri ) );
        fprintf ( 1, 'The Euler characteristic of the second mesh is %i.\n', mesheuler ( leaddata.mesh.bnd (2).tri ) );
        fprintf ( 1, 'The Euler characteristic of the third mesh is %i.\n',  mesheuler ( leaddata.mesh.bnd (3).tri ) );
    end
    
    
    % Gets the mesh(es), the head shape and the source model.
    grid          = leaddata.grid;
    mesh          = leaddata.mesh;
    
    % Gets the original posiiton of the dipoles.
    dipoleu  = grid.inside & grid.posori ( :, 3 ) >= 0;
    dipoled  = grid.inside & grid.posori ( :, 3 ) <  0;
    dipoler  = grid.inside & grid.posori ( :, 1 ) >= 0 & dipoleu;
    dipolel  = grid.inside & grid.posori ( :, 1 ) <  0 & dipoleu;
    
    % Plots the grid.
%     ft_plot_mesh  ( grid.pos ( dipoled, : ), 'VertexColor', [ 0 0 0 ] );
%     ft_plot_mesh  ( grid.pos ( dipolel, : ), 'VertexColor', [ 1 0 0 ] );
%     ft_plot_mesh  ( grid.pos ( dipoler, : ), 'VertexColor', [ 0 1 0 ] );
    ft_plot_mesh  ( grid.pos ( grid.inside, : ), 'VertexColor', [ 0 0 0 ], 'VertexSize', 1 );
    
    % Plots the meshes.
    for mindex = 1: numel ( mesh.tissue )
        switch mesh.tissue { mindex }
            case 'brain', meshcolor = 'brain';
            case 'skull', meshcolor = [ 1 1 1 ] - eps;
            case 'scalp', meshcolor = 'skin';
            otherwise,    meshcolor = 'white';
        end
        
        ft_plot_mesh  ( mesh.bnd ( mindex ), 'facecolor', meshcolor, 'edgecolor', 'none', 'facealpha', .2 );
    end
    hold on
    
    
    % Plots the sensors.
    if isfield ( leaddata, 'grad' ) && ~isempty ( leaddata.grad )
        plot3 ( leaddata.grad.chanpos ( :, 1 ), leaddata.grad.chanpos ( :, 2 ), leaddata.grad.chanpos ( :, 3 ), '+r' )
    end
    if isfield ( leaddata, 'elec' ) && ~isempty ( leaddata.elec )
        plot3 ( leaddata.elec.chanpos ( :, 1 ), leaddata.elec.chanpos ( :, 2 ), leaddata.elec.chanpos ( :, 3 ), '*r' )
    end
    if isfield ( leaddata, 'sens' ) && ~isempty ( leaddata.sens )
        plot3 ( leaddata.sens.chanpos ( :, 1 ), leaddata.sens.chanpos ( :, 2 ), leaddata.sens.chanpos ( :, 3 ), 'or' )
    end
    
    % Lights the scene.
    set ( gcf, 'Name', leaddata.subject );
    view ( [   90,   0 ] ), camlight
    view ( [ -150,   0 ] ), camlight
    material dull
    lighting gouraud
    drawnow
    
    fprintf ( 1, 'Black: Bottom.\n' );
    fprintf ( 1, 'Red:   Top left.\n' );
    fprintf ( 1, 'Green: Top right.\n' );
    
    % Saves the figure.
    print ( '-dpng', sprintf ( '%s%s.png', config.path.figs, leaddata.subject ) )
    
    if config.savefig
        savefig ( sprintf ( '%s%s.fig', config.path.figs, leaddata.subject ) )
    end
    if config.savegif
        my_savegif ( sprintf ( '%s%s.gif', config.path.figs, leaddata.subject ) )
    end
    
    close all
    clc
end
