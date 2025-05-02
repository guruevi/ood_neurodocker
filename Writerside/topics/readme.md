# About OOD Neurodocker
OOD Neurodocker is a tool for creating Docker images for OpenOnDemand. 
It was initially designed by the ReproNim repository to create Docker images for neuroimaging software.

However the concept has been very useful to create any Docker image for OpenOnDemand.

# Getting started
Read generate_apps.sh
source generate_apps.sh
Call a function to generate a Docker image for OpenOnDemand

# Making more images
Copy/paste from another app, modify the various variables to your liking
The way it works is that it will rsync in order:
- the template directory
- the appname_template directory
- the appname_gui_template directory if it has both a gui and a terminal option

There are various templates you can include in your neurodocker generate command
They will basically be parsed in order and added to the Dockerfile and/or Singularity container document

This MAY be slightly inefficient at build time but the composability is worth it.

# Documentation:
Using WriterSide.

# TODO:
- Add a cleanup template that minifies the container
- Add RPM builds for common tools
- Compile this documentation to a static page for both GitLab and GitHub