
Qu|Nex	

    Home
    Get QuNex
    About
    Documentation
    Forum

QuNex Registration Form

Access QuNex
Note Regarding Dependencies & Licenses

QuNex supports integration of tools and existing software packages such as FSL, Connectome Workbench, HCP Pipelines, PALM, Octave or Matlab, AFNI, R Statistical Environment, FreeSurfer, and AFNI packages. The user agrees to all licence terms of distributed software and is responsible for obtaining the licenses for the relevant QuNex dependencies.

In the case of the QuNex Container, the user confirms to have read and agreed to all the terms provided by each individual software package.

For commercial licensing of the QuNex container please contact Yale Ventures.
Docker Container Deployment

The QuNex container is available on Docker Hub.

The QuNex quick start guide is available within the official QuNex Documentation.
Singularity / Apptainer Image Download

First, consult https://github.com/ULJ-Yale/qunex/tags to get the latest QuNex tag (you need this to replace below with it).

The prebuilt QuNex Singularity / Apptainer (.sif) image container is available at https://jd.mblab.si/qunex/qunex_suite-<tag>.sif, swap tag with the latest released version.

To download the prebuilt Singularity / Apptainer image from the command line (terminal), you can run the following:
wget --show-progress -O qunex_suite-.sif 'https://jd.mblab.si/qunex/qunex_suite-<tag>.sif'

To build the Singularity / Apptainer image yourself, you can run:
singularity build qunex_suite-.sif docker://qunex/qunex_suite:<tag>
Source Code Repository

The QuNex source code is available on QuNex GitHub.

If you need help with any issues, please email jure.demsar@ff.uni-lj.si or post on the QuNex Forum.
