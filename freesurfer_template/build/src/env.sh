#!/bin/bash -p
#
# SetUpFreeSurfer.sh
#
# This is an edited SetUpFreeSurfer.sh file, variables can come from the SINGULARITYENV setup
# export FREESURFER_HOME=/usr/local/freesurfer/7.4.1

# SUBJECTS_DIR is set by the runner
# FUNCTIONALS_DIR is set by the runner

# If you do intend to use the functional tools, then add these lines to your matlab/startup.m file:
#    fsfasthome = getenv('FSFAST_HOME');
#    fsfasttoolbox = sprintf('%s/toolbox',fsfasthome);
#    path(path,fsfasttoolbox);
#
# An FSL installation (required for TRACULA):
#    export FSL_DIR /usr/local/fsl

# Enable or disable MNI tools (enabled by default)
#export NO_MINC=1

# Enable or disable fsfast (enabled by default)
#export NO_FSFAST=1

# Call configuration script:
source $FREESURFER_HOME/FreeSurferEnv.sh
source $FREESURFER_HOME/SetUpFreeSurfer.sh
