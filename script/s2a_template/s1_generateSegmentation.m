clc
clear
close all

% Sets the paths.
config.path.tpm   = '../../template/tpm/MARS_TPM.nii.gz';
config.path.mni   = '../../template/mni/MNI-ICBM152_3DT1.nii.gz';
config.path.mri   = '../../template/anatomy/';
config.path.patt  = '*.nii.gz';

% Defines the template label.
config.subject    = 'MARS';


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'freesurfer', 1, 1 );


% Creates and output folder, if required.
if ~exist ( config.path.mri, 'dir' ), mkdir ( config.path.mri ); end


fprintf ( 1, 'Loading the template anatomy and the tissue probability map.\n' );

% Loads the MNI template anatomy and the MARS TPM.
mni                   = my_read_mri ( config.path.mni );
tpm                   = my_read_mri ( config.path.tpm );

% Makes sure that the volumes are in mm.
mni                   = ft_convert_units ( mni, 'mm' );
tpm                   = ft_convert_units ( tpm, 'mm' );


fprintf ( 1, 'Transforming the anatomy to match the tissue probability map.\n' );

% Generates a dummy MRI from the TPM.
dummy                 = [];
dummy.dim             = tpm.dim ( 1: 3 );
dummy.anatomy         = tpm.anatomy ( :, :, :, 5 ) + tpm.anatomy ( :, :, :, 2 );
dummy.transform       = tpm.transform;
dummy.unit            = tpm.unit;

% Reslices the MNI anatomy to match the TPM.
cfg                   = [];
cfg.parameter         = 'anatomy';
cfg.interpmethod      = 'linear';
cfg.feedback          = 'no';

mni                   = ft_sourceinterpolate ( cfg, mni, dummy );
mni.inside            = mni.anatomy > 0;

% Extends the MNI anatomy with the TPM dummy anatomy.
mni.anatomy ( ~mni.inside ) = 50 * dummy.anatomy ( ~mni.inside );

% Stores the original transformation.
transform             = [];
transform.unit        = mni.unit;
transform.vox2nat     = mni.transform;


fprintf ( 1, 'Combining the anatomy and the tissue probability map.\n' );

% Converts the data to single precision.
tpm.anatomy           = single ( tpm.anatomy );
mni.anatomy           = single ( mni.anatomy );

% Generates a MRI structure combining the template and the TPM.
mri                   = [];
mri.dim               = mni.dim;
mri.transform         = mni.transform;
mri.coordsys          = 'mni';
mri.unit              = mni.unit;
mri.anatomy           = mni.anatomy;
mri.gray              = tpm.anatomy ( :, :, :, 1 );
mri.white             = tpm.anatomy ( :, :, :, 2 );
mri.csf               = tpm.anatomy ( :, :, :, 3 );
mri.bone              = tpm.anatomy ( :, :, :, 4 );
mri.soft              = tpm.anatomy ( :, :, :, 5 );


fprintf ( 1, 'Generating the transformation matrices to ACPC and Neuromag spaces.\n' );

% Generates a dummy MRI.
dummy                 = [];
dummy.dim             = mri.dim;
dummy.anatomy         = mri.anatomy;
dummy.transform       = mri.transform;
dummy.unit            = mri.unit;
dummy.coordsys        = mri.coordsys;


% Defines the SPM fiducials.
landmark.acpc.ac      = [  61  85 128 ];
landmark.acpc.pc      = [  61  68 128 ];
landmark.acpc.xzpoint = [  61  76 177 ];
landmark.acpc.right   = [ NaN NaN NaN ];

% Calculates the transformation to ACPC coordinates.
cfg                   = [];
cfg.coordsys          = 'acpc';
cfg.fiducial          = landmark.acpc;

dummy                 = ft_volumerealign ( cfg, dummy );
transform.vox2acpc    = dummy.transform;


% Defines the Neuromag landmarks.
landmark.nm.nas       = [  61 140  97 ];
landmark.nm.lpa       = [ 114  76  97 ];
landmark.nm.rpa       = [   8  76  97 ];
landmark.nm.zpoint    = [ NaN NaN NaN ];

% Calculates the transformation to Neuromag coordinates.
cfg                   = [];
cfg.coordsys          = 'neuromag';
cfg.fiducial          = landmark.nm;

dummy                 = ft_volumerealign ( cfg, dummy );
transform.vox2nm      = dummy.transform;


% Defines the transformation from MNI space to native coordinates.
transform.mni2nat     = eye (4);


fprintf ( 1, 'Saving the template-based segmentation file.\n' );

% Prepares the output.
mridata               = [];
mridata.subject       = config.subject;
mridata.landmark      = landmark;
mridata.transform     = transform;
mridata.mri           = mri;

% Saves the output.
save ( '-v6', sprintf ( '%s%s_3DT1', config.path.mri, mridata.subject ), '-struct', 'mridata' )
