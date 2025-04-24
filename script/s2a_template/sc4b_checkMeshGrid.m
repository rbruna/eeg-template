clc
clear
close all

% Sets the path.
config.path.head = '../../template/headmodel/';
config.path.figs = '../../figs-template/headmodel/';
config.path.patt = '*.mat';

% Shows the MRI or not.
config.showmri   = true;

% Selects which versions of the figure to save.
config.savefig   = false;
config.savegif   = true;


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
files = dir ( sprintf ( '%s%s', config.path.head, config.path.patt ) );

% Goes through all the files.
for file = 1: numel ( files )
    
    % Pre-loads the data.
    headdata      = load ( sprintf ( '%s%s', config.path.head, files ( file ).name ), 'subject' );
    
    
    fprintf ( 1, 'Working with subject %s.\n', headdata.subject );
    
    % Loads the MRI data and extracts the masks.
    headdata      = load ( sprintf ( '%s%s', config.path.head, files ( file ).name ), 'subject', 'mri', 'mesh', 'grid' );
    
    % If BEM checks the surfaces.
    if numel ( headdata.mesh.bnd ) == 3
        
        % Generates a temporal name prefix.
        tmpprefix     = tempname;
        
        % Re-orients the mesh according to OpenMEEG definition.
        mesh          = myom_check_headmodel ( headdata.mesh );
        
        % Checks the triangle files and the geometry file.
        % Will find intersections and self-intersections.
        om_save_tri ( sprintf ( '%s_brain.tri', tmpprefix ), mesh.bnd (1).pos, mesh.bnd (1).tri );
        om_save_tri ( sprintf ( '%s_skull.tri', tmpprefix ), mesh.bnd (2).pos, mesh.bnd (2).tri );
        om_save_tri ( sprintf ( '%s_scalp.tri', tmpprefix ), mesh.bnd (3).pos, mesh.bnd (3).tri );
        om_write_geom ( sprintf ( '%s_geom.geom', tmpprefix ), { 'brain.tri', 'skull.tri', 'scalp.tri' } );
        
%         system ( sprintf ( 'om_mesh_info -i "%s_brain.tri"', tmpprefix ) );
%         system ( sprintf ( 'om_mesh_info -i "%s_skull.tri"', tmpprefix ) );
%         system ( sprintf ( 'om_mesh_info -i "%s_scalp.tri"', tmpprefix ) );
        system ( sprintf ( 'om_check_geom -g "%s_geom.geom"', tmpprefix ) );
        
        % Deletes the files.
        delete ( sprintf ( '%s_*', tmpprefix ) );
        
        % Checks that the meshes are closed.
        % A closed mesh has an Euler characteristic of 2.
        fprintf ( 1, 'Subject %s.\n', headdata.subject );
        fprintf ( 1, 'The Euler characteristic of the first mesh is %i.\n',  mesheuler ( headdata.mesh.bnd (1).tri ) );
        fprintf ( 1, 'The Euler characteristic of the second mesh is %i.\n', mesheuler ( headdata.mesh.bnd (2).tri ) );
        fprintf ( 1, 'The Euler characteristic of the third mesh is %i.\n',  mesheuler ( headdata.mesh.bnd (3).tri ) );
        fprintf ( 1, '\n' );
    end
    
    
    % Converts the meshes and the grid to millimeters.
    grid          = headdata.grid;
    grid          = ft_convert_units ( grid, 'mm' );
    mesh          = headdata.mesh;
    mesh          = ft_convert_units ( mesh, 'mm' );
    
    
    % Plots the MRI, if requested.
    if config.showmri
        
        % Creates a dummy MRI containing only the anatomy.
        mri           = [];
        mri.dim       = headdata.mri.dim;
        mri.anatomy   = headdata.mri.anatomy;
        mri.transform = headdata.mri.transform;
        mri.unit      = headdata.mri.unit;
        mri           = ft_convert_units ( mri, 'mm' );
        
        ft_determine_coordsys ( mri, 'interactive', 'no' );
    end
    
    % Gets the original position of the dipoles.
    dipoleu  = grid.inside & grid.posori ( :, 3 ) >= 0;
    dipoled  = grid.inside & grid.posori ( :, 3 ) <  0;
    dipoler  = grid.inside & grid.posori ( :, 1 ) >= 0 & dipoleu;
    dipolel  = grid.inside & grid.posori ( :, 1 ) <  0 & dipoleu;
    
    % Plots the grid.
    ft_plot_mesh  ( grid.pos ( dipoled, : ), 'vertexcolor', [ 0 0 1 ] );
    ft_plot_mesh  ( grid.pos ( dipoleu & dipolel, : ), 'vertexcolor', [ 1 0 0 ] );
    ft_plot_mesh  ( grid.pos ( dipoleu & dipoler, : ), 'vertexcolor', [ 0 1 0 ] );
    
    % Plots the meshes.
    for mindex = 1: numel ( mesh.tissue )
        switch mesh.tissue { mindex }
            case 'brain', meshcolor = 'brain';
            case 'skull', meshcolor = [ 1 1 1 ] - eps;
            case 'scalp', meshcolor = 'skin';
            otherwise,    meshcolor = [ 1 1 1 ] - eps;
        end
        
        ft_plot_mesh  ( mesh.bnd ( mindex ), 'facecolor', meshcolor, 'edgecolor', 'none', 'facealpha', .5 );
    end
    
    % Lights the scene.
    set ( gcf, 'Name', headdata.subject );
    delete ( findall ( gcf, 'Type', 'light' ) )
    view ( [   90,   0 ] ), camlight
    view ( [ -150,   0 ] ), camlight
    lighting gouraud
    rotate3d
    
    clc
    fprintf ( 1, 'Blue:  Bottom.\n' );
    fprintf ( 1, 'Red:   Top left.\n' );
    fprintf ( 1, 'Green: Top right.\n' );
    
    
    % Saves the figure.
    print ( '-dpng', sprintf ( '%s%s.png', config.path.figs, headdata.subject ) )
    if config.savefig
        savefig ( sprintf ( '%s%s.fig', config.path.figs, headdata.subject ) )
    end
    if config.savegif
        my_savegif ( sprintf ( '%s%s.gif', config.path.figs, headdata.subject ) )
    end
    close all
    clc
    
    pause (2)
end
